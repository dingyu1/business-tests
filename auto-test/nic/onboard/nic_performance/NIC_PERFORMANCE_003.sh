#!/bin/bash

#用例名称：NIC_PERFORMANCE_003                 
#用例功能：大文件传输测试  
#作者：fwx654472                            
#完成时间：2019-1-22                        
#前置条件：                                 
#   1.单板启动正常
#   2.所有网口各模块加载正常              
#测试步骤：                                 
#   1、 SUT端构建一个2048M的文件，计算md5值。
#       dd if=/dev/zero of=testfile bs=1M count=2048
#       md5sum testfile
#   2、 SUT端通过网口1把文件scp传输到Server端：
#       scp  testfile root@[server ip]:/root/testfile1
#   3、  SUT端通过网口2把Server端文件scp传输回SUT端：
#       scp root@[server ip]: /root/testfile1 ./testfile2
#   4、 SUT端通过网口3把文件scp传输到Server端：
#       scp testfile2 root@[server ip]:/root/testfile3
#   5、 SUT端通过网口4把Server端文件scp传输回SUT端：
#       scp root@[server ip]: /root/testfile3 ./testfile4
#   6、 计算testfile4的md5值与testfile的md5只进行比较，有结果A)
#   7、 重复以上操作3次
#测试结果：
#   A) md5值相等。
#######################################################################
#加载公共函数,具体看环境对应的位置修改

. ../../../../utils/error_code.inc
. ../../../../utils/test_case_common.inc
. ../../../../utils/env_parameter.inc
. ../../../../utils/sys_info.sh
. ../../../../utils/sh-test-lib     

#. ./error_code.inc
#. ./test_case_common.inc
#. ./env_parameter.inc

#获取脚本名称作为测试用例名称
test_name=$(basename $0 | sed -e 's/\.sh//')
#创建log目录
TMPDIR=./logs/temp
mkdir -p ${TMPDIR}
#存放脚本处理中间状态/值等
TMPDIR=${TMPDIR}/${test_name}.tmp
#存放每个测试步骤的执行结果
RESULT_FILE=${TMPDIR}/${test_name}.result

#自定义变量区域（可选）
#var_name1="xxxx"
#var_name2="xxxx"
test_result="pass"

debug=false

client_ip_10=$env_sut_on_board_fiber_0
client_ip_20=$env_sut_on_board_TP_20
client_ip_30=$env_sut_on_board_TP_30
client_ip_40=$env_sut_external_network_card_40
#client_ip_50=$env_sut_external_network_card_50

server_ip_10=$env_tc_on_board_fiber_0
server_ip_20=$env_tc_on_board_TP_20
server_ip_30=$env_tc_on_board_TP_30
server_ip_40=$env_tc_external_network_card_40
#server_ip_50=env_tc_external_network_card_50

password=$env_tc_passwd

if [ $debug = true ];then
	#sut 本端，tc对端
	client_ip_10=192.168.1.3
	client_ip_20=192.168.10.3
	client_ip_30=192.168.20.3
	client_ip_40=192.168.30.3
	#client_ip_50=192.168.50.11
	
	server_ip_10=192.168.1.6
	server_ip_20=192.168.10.6
	server_ip_30=192.168.20.6
	server_ip_40=192.168.30.6
	#server_ip_50=192.168.50.12
	
	password=root
fi


#SCP="sshpass -p $password scp -o StrictHostKeyChecking=no -o ConnectTimeout=5"
#SSH="sshpass -p $password ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5"
SSH="timeout 1000 sshpass -p root ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
SCP="timeout 1000 sshpass -p root scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

#************************************************************#
# Name        : file_transport_test                        #
# Description : 文件传输测试                                #
# Parameters  : 无
# return      : 无                                      #
#************************************************************#
function file_transport_test(){
    
    dd if=/dev/zero of=/root/testfile bs=1M count=2048
	ls /root/testfile
    md5_testfile=`md5sum /root/testfile |awk '{print $1}'`  
    PRINT_LOG "INFO" "md5_testfile<$md5_testfile>"
    
    $SCP /root/testfile root@${server_ip_10}:/root/testfile1 
    if [ $? -eq 0 ]
    then
        PRINT_LOG "INFO" "$SCP /root/testfile root@${server_ip_10}:/root/testfile1 "
        fn_writeResultFile "${RESULT_FILE}" "copy_file_${server_ip_10}" "pass"
    else
		PRINT_LOG "INFO" "$SCP /root/testfile root@${server_ip_10}:/root/testfile1 "
        fn_writeResultFile "${RESULT_FILE}" "copy_file_${server_ip_10}" "fail"
		ip a
		$SSH root@${server_ip_10} ls /root/testfile1 
		ping $server_ip_10 -c 3
		return 1
    fi
    
    $SCP root@${server_ip_20}:/root/testfile1 /root/testfile2 
    if [ $? -eq 0 ]
    then
        PRINT_LOG "INFO" "$SCP root@${server_ip_20}:/root/testfile1 /root/testfile2"
        fn_writeResultFile "${RESULT_FILE}" "copy_file_${server_ip_20}" "pass"
    else
        PRINT_LOG "INFO" "$SCP root@${server_ip_20}:/root/testfile1 /root/testfile2"
        fn_writeResultFile "${RESULT_FILE}" "copy_file_${server_ip_20}" "fail"
		ls /root/testfile2
		ping $server_ip_20 -c 3
		return 1
    fi
    
    $SCP /root/testfile2 root@${server_ip_30}:/root/testfile3 
    if [ $? -eq 0 ]
    then
        PRINT_LOG "INFO" "$SCP /root/testfile2 root@${server_ip_30}:/root/testfile3"
        fn_writeResultFile "${RESULT_FILE}" "copy_file_${server_ip_30}" "pass"
    else
        PRINT_LOG "INFO" "$SCP /root/testfile2 root@${server_ip_30}:/root/testfile3"
        fn_writeResultFile "${RESULT_FILE}" "copy_file_${server_ip_30}" "fail"
		$SSH root@${server_ip_30} ls /root/testfile3 
		ping $server_ip_30 -c 3
		return 1
    fi
    
    $SCP root@${server_ip_40}:/root/testfile3 /root/testfile4 
    if [ $? -eq 0 ]
    then
        PRINT_LOG "INFO" "$SCP root@${server_ip_40}:/root/testfile3 /root/testfile4"
        fn_writeResultFile "${RESULT_FILE}" "copy file ${server_ip_40}" "pass"
    else
        PRINT_LOG "INFO" "$SCP root@${server_ip_40}:/root/testfile3 /root/testfile4"
        fn_writeResultFile "${RESULT_FILE}" "copy file ${server_ip_40}" "fail"
		ls /root/testfile4
		ping $server_ip_40 -c 3
		return 1
    fi
    
    md5_testfile4=`md5sum /root/testfile4 |awk '{print $1}'`
    PRINT_LOG "INFO" "md5_testfile4<$md5_testfile4>"    
    if [ "${md5_testfile}" = "${md5_testfile4}" ]
    then
        PRINT_LOG "INFO" "md5_testfile=${md5_testfile}-----md5_testfile4=${md5_testfile4} "
        fn_writeResultFile "${RESULT_FILE}" "md5value" "pass"
    else
        PRINT_LOG "FATAL" "md5_testfile=${md5_testfile}-----md5_testfile4=${md5_testfile4} ,two value is not equal please check it . "
        fn_writeResultFile "${RESULT_FILE}" "md5value" "fail"
    fi
}

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
    sshpass -h || fn_install_pkg "sshpass" 10
    #自定义测试预置条件检查实现部分：比如工具安装，检查多机互联情况，执行用户身份 
      #需要安装工具，使用公共函数install_deps，用法：install_deps "${pkgs}"
      #需要日志打印，使用公共函数PRINT_LOG，用法：PRINT_LOG "INFO|WARN|FATAL" "xxx"
}

#测试执行
function test_case()
{
    #测试步骤实现部分

    for ((i=1;i<=3;i++))
    do
        file_transport_test
		[ $? -eq 0 ] || return 1
    done

    #检查结果文件，根据测试选项结果，有一项为fail则修改test_result值为fail，
    check_result ${RESULT_FILE}
}

#恢复环境
function clean_env()
{
    #清除临时文件
    FUNC_CLEAN_TMP_FILE
    #自定义环境恢复实现部分,工具安装不建议恢复
      #需要日志打印，使用公共函数PRINT_LOG，用法：PRINT_LOG "INFO|WARN|FATAL" "xxx"  
    rm -f /root/testfile*
    #$SSH root@$server_ip_10 "rm -f /root/testfile*"
	$SSH root@$env_tc_on_board_fiber_0 "rm -f /root/testfile*"
}

function main()
{
    init_env || test_result="fail"
    if [ ${test_result} = 'pass' ]
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

