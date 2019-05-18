#!/bin/bash
#*****************************************************************************************
# *用例名称：onboard_Performance2_018
# *用例功能：板载enp125s0f1光口小包（10G）
# *作者：wwx573515
# *完成时间：2019-05-17
# *前置条件：
#   1、两台物理机host1和host2，分别用作TAS端和SUT端
#   2、两台物理机板载enp125sf1光口连接同个交换机
#   3、修改两台物理机的MTU为1500: ifconfig ethx mtu 1500
#   4、两台物理机网口绑中断
#      for((i=0;i<=（中断号数-1）;i++));do echo $i> /proc/irq/`expr 第一个中断号 + $i`/smp_affinity_list; done
# *测试步骤：
#   1、 Server端：netserver
#       SUT端：taskset -c 24 netperf -H <Server IP> -t UDP_STREAM –l 30 -- -m pkt_length –M pkt_length
#       SUT端：taskset -c 25 netperf -H <Server IP> -t UDP_STREAM –l 30 -- -m pkt_length –M pkt_length     
#   2、 查看网卡统计没有丢包和错包
#       测试结果数据在正常范围内
# *测试结果：
#  没有丢包和错包，测试结果数据在正常范围内
#*****************************************************************************************

#加载公共函数
. ../../../../utils/error_code.inc
. ../../../../utils/test_case_common.inc
. ../../../../utils/sys_info.sh
. ../../../../utils/sh-test-lib
. ../../../../utils/env_parameter.inc


#获取脚本名称作为测试用例名称
test_name=$(basename $0 | sed -e 's/\.sh//')
#创建log目录
TMPDIR=./logs/temp
mkdir -p ${TMPDIR}
#存放脚本处理中间状态/值等
TMPFILE=${TMPDIR}/${test_name}.tmp
#存放每个测试步骤的执行结果
RESULT_FILE=${TMPDIR}/${test_name}.result
#自定义变量区域（可选）
#var_name1="xxxx"
#var_name2="xxxx"
test_result="pass"
SSH="timeout 1000 sshpass -p root ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
SCP="timeout 1000 sshpass -p root scp  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
 
#预置条件
function init_env()
{
    #检查结果文件是否存在，创建结果文件：
    fn_checkResultFile ${RESULT_FILE}
    #root用户执行
    if [ `whoami` != 'root' ]
    then
       PRINT_LOG "WARN" " You must be root user "
       return 1
    fi
    #install
    ip="$env_tc_on_board_fiber_10"
    fn_install_pkg "gcc make tar wget sshpass net-tools" 2
    ip_board=$env_tc_on_board_fiber_0
    network=`ip route|grep "$env_sut_on_board_fiber_10"|awk '{print $3}'`  
#本端绑中断
    firstinterruput=`cat /proc/interrupts| awk '{print $1,$NF}'|grep -i  $network |head -1|awk -F ':' '{print $1}'`
    interruputnum=`cat /proc/interrupts| awk '{print $1,$NF}'|grep -i $network |wc -l`
    interruputnum=$[interruputnum-1]
    echo $interruputnum
    for((i=0;i<=$interruputnum;i++));do echo ${i}> /proc/irq/`expr $firstinterruput + $i`/smp_affinity_list; done
#对端绑中断
    tc_firstinterruput=`$SSH root@$ip_board cat /proc/interrupts| awk '{print $1,$NF}'|grep -i  $network |head -1|awk -F ':' '{print $1}'`    
    cat << EOF > bond_interruput.sh
#!/bin/bash
tc_firstinterruput=$tc_firstinterruput
for((i=0;i<=$interruputnum;i++));do echo \$i> /proc/irq/\`expr \$tc_firstinterruput + \$i\`/smp_affinity_list; done
EOF
    $SCP ./bond_interruput.sh root@$ip_board:/root/
    $SSH root@$ip_board "chmod 777 bond_interruput.sh"
    $SSH root@$ip_board "./bond_interruput.sh"   
    
    ip link set $network mtu 1500
    systemctl disable firewalld.service
    systemctl stop firewalld.service

    wget ${ci_http_addr}/test_dependents/netperf.tar.gz
    tar -zxvf netperf.tar.gz &&  cd netperf && ./configure -build=alpha
    make && make install && cd -
    
    $SSH root@$ip_board "yum install -y gcc make tar wget sshpass net-tools"
    $SSH root@$ip_board "systemctl disable firewalld.service && systemctl stop firewalld.service"
    $SSH root@$ip_board "ip link set $network mtu 1500" 
    $SSH root@$ip_board "wget ${ci_http_addr}/test_dependents/netperf.tar.gz"
    $SSH root@$ip_board "tar -zxvf netperf.tar.gz "
    $SSH root@$ip_board "cd netperf && ./configure -build=alpha && make && make install && cd - "
    $SSH root@$ip_board "netserver &"    
#测试执行
function test_case()
{
#免密执行
   ifconfig $network 2>&1 |tee csq.txt
   Errors=`cat csq.txt |grep "TX errors"|head -1|awk '{print $3}'`
   Dropped=`cat csq.txt |grep "TX errors"|head -1|awk '{print $5}'`

   cpuid="24 25"
   for i in $cpuid
   do 
         taskset -c $i netperf -H $ip -t UDP_STREAM -l 30 -- -m 10240 2>&1 | tee ${i}_result.txt  &
   done
         sleep 40
         Throughput_24=`tail -n 3 24_result.txt | awk '{print $6}'|head -1`
         Throughput_25=`tail -n 3 25_result.txt | awk '{print $6}'|head -1` 
         t=8000
         max=`echo "$Throughput_24+$Throughput_25 > $t"|bc`
         echo $max
         if [ $max -eq 1 ];then
            PRINT_LOG "INFO" "speed_check_ok"
            fn_writeResultFile "${RESULT_FILE}" "speed_check" "pass"
         else
            PRINT_LOG "FATAL" "$speed_check_fail"
            fn_writeResultFile "${RESULT_FILE}" "speed_check" "fail"
         fi
   
   
   
         ifconfig $network 2>&1 |tee csh.txt
         errors=`cat csh.txt |grep "TX errors" |awk '{print $3}'|head -1`
         if [ $errors -eq $Errors ];then
            PRINT_LOG "INFO" "Tx_errors_check_ok"
            fn_writeResultFile "${RESULT_FILE}" "Tx_errors_check" "pass"
         else
            PRINT_LOG "FATAL" "Tx_errors_check_fail"
            fn_writeResultFile "${RESULT_FILE}" "Tx_errors_check" "fail"
         fi

         drop=`cat csh.txt | grep "TX errors" |awk '{print $5}'|head -1`
         if [ $drop -eq $Dropped ];then
            PRINT_LOG "INFO" "Tx_dropped_check_ok"
            fn_writeResultFile "${RESULT_FILE}" "Tx_dropped_check" "pass"
         else
            PRINT_LOG "FATAL" "have-dropped"
            fn_writeResultFile "${RESULT_FILE}" "Tx_dropped_check" "fail"
         fi
   check_result ${RESULT_FILE}
}
#恢复环境
function clean_env()
{
     $SSH root@$ip_board "rm -rf netperf.tar.gz"
     $SSH root@$ip_board ps -ef | grep -i netserver |awk '{print $2}'|awk 'NR == 1'|tee pro_id.txt
     pro_id=`cat pro_id.txt`
     $SSH root@$ip_board "kill -9 $pro_id"
     rm -rf csh.txt csq.txt result.txt netperf.tar.gzs pro_id.txt
}

function main()
{
        init_env || test_result="fail"
        if [ ${test_result} = "pass" ]
        then
                test_case || test_result="fail"
        fi
        clean_env || test_result="fail"
        [ "${test_result}" = "pass" ] || return 1
}

main $@
ret=$?
#LAVA平台上报结果接口，勿修改
lava-test-case "$test_name" --result ${test_result}
exit ${ret}




