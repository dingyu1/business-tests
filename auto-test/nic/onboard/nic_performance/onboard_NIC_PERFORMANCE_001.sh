#!/bin/bash

#*****************************************************************************************
# *测试内容：长时间收发包测试
# *用例名称：NIC_PERFORMANCE_001
# *用例作者：lwx588815
# *完成时间：2019-1-22
# *前置条件：
#  1、已安装os,两块单板直连
#  2、系统启动后网络正常
# *测试步骤：
#  1、获取到server段IP地址
#     Server端：IP
#     SUT端：ping -c 10 -s time ip
#     修改SUT和Server网卡MTU为9000：ifconfig ethX mtu 9000
#  2、使用ping通过改变发包大小观察是否有丢包和错包的现象
# *测试结果：
#     无丢包，无错包
#*****************************************************************************************

#加载公共函数,具体看环境对应的位置修改
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
test_result="pass"


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
#安装环境
    sshpass -h
    if [ $? -eq 0 ];
    then
         PRINT_LOG "INFO" "The sshpass package has been installed"
    else
         fn_install_pkg "sshpass" 2
    fi
    network=`ip route | sed -r -n 's/.*dev (\w+).*src ([^ ]*) .*/\1 \2/p'|egrep -v "vir|br|vnet|lo" | awk '{print $1}'`
    ip_board1="$env_tc_on_board_fiber_10 $env_tc_on_board_TP_20 $env_tc_on_board_TP_30 $env_tc_external_network_card_40 $env_tc_external_network_card_50"
    ip_board="$env_tc_on_board_fiber_0"
}


#测试执行
function test_case()
{
#数组存放包大小
    ARR1="0 256 512 777 1024 2048 3478 6800 8972 8973 9000"
    ARR2="8972 9000 10000 20000 50000 60000 65507"

#使用ping命令查看是否有丢包
    for i in $ARR1
    do
       for k in $ip_board1
        do
        ping -c 10 -s $i $k 2>&1 | tee result.txt
        str=`cat result.txt|grep loss|awk -F ',' '{print $3}'|awk '{print $1}'|sed 's/%//g'`
        if [ $str -eq 0 ];then
             PRINT_LOG "INFO" "mtu_is_1500_not_loss_situation"
             fn_writeResultFile "${RESULT_FILE}" "$i _test_ping_name_is_not_loss" "pass"
        else
             PRINT_LOG "FATAL" "mtu is 1500 have packet loss situation"
             fn_writeResultFile "${RESULT_FILE}" "$i_ test_ping_name_ is_loss" "fail"

        fi
        done
    done
#修改SUT和Server网卡MTU为9000
     for net in $network
     do
        ip link set $net mtu 9000
        sleep 2
        timeout 1000 sshpass -p root ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ip_board ip link set $net mtu 9000
     sleep 5
     done
#ping 命令查看是否丢包
     for j in $ARR2
     do
        for h in $ip_board1
        do
         ping -c 10 -s $j $h 2>&1 | tee run.log
         str=`cat run.log | grep "loss"|awk -F ',' '{print $3}' |awk '{print $1}'|sed 's/%//g'`
         if [ $str -eq 0 ];then
             PRINT_LOG "INFO" "mtu_is_9000_not_loss_situation"
             fn_writeResultFile "${RESULT_FILE}" "$j test_ping_is_not_loss" "pass"
         else
             PRINT_LOG "FATAL" "mtu_is_9000_have_loss_situation"
             fn_writeResultFile "${RESULT_FILE}" "mtu_9000_test_ping_is_loss" "fail"
         fi
         check_result ${RESULT_FILE}
        done
    done
}

#恢复环境
function clean_env()
{
    rm -rf run.log
    rm -rf result.txt

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

