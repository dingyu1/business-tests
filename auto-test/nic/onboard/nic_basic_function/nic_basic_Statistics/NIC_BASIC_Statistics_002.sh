#!/bin/bash
set -x
#*****************************************************************************************
#用例名称：NIC_BASIC_Statistics_002
#用例功能：查询网卡收发包方面的统计信息
#作者：lwx652446
#完成时间：2019-1-30
#前置条件
#    1.单板启动正常
#    2.所有GE网口各模块加载正常
#测试步骤
#    1.执行ethtool -S ethx
#测试结果
#    正确显示网口统计信息，重点关注需要关注的字段有：rx_dropped、rx_missed_errors、rx_over_errors、rx_fifo_errors、rx_no_dma_resources字段

#*****************************************************************************************



#加载公共函数,具体看环境对应的位置修改
. ../../../../../utils/error_code.inc
. ../../../../../utils/test_case_common.inc
. ../../../../../utils/sys_info.sh
. ../../../../../utils/sh-test-lib
. ../../../../../utils/env_parameter.inc

#获取脚本名称作为测试用例名称
test_name=$(basename $0 | sed -e 's/\.sh//')
#创建log目录
TMPDIR=/var/logs_test/temp
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

pkgs="ethtool sshpass"
install_deps "$pkgs"

SSH="timeout 1000 sshpass -p root ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
SCP="timeout 1000 sshpass -p root scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
   
}


#测试电口收发包
function test_case()
{

#获取本端和对端ip
sut_ip_20=$env_sut_on_board_TP_20
tc_ip_20=$env_tc_on_board_TP_20


#查询网卡收包统计情况
sut_eth=`ip addr|grep $sut_ip_20 |awk '{print $NF}'`
rx_num=`ethtool -S $sut_eth |grep mac_rx_total_pkt_num|awk '{print $2}'`



#在客户端ping服务端
$SSH root@{$tc_ip_20} "ping ${sut_ip_20} -c 1000"


#查询网卡在客户端发包后的收包信息
rx_num_later=`ethtool -S $sut_eth |grep mac_rx_total_pkt_num|awk '{print $2}'`	
if [ $rx_num_later -gt $rx_num ]
then
	fn_writeResultFile "${RESULT_FILE}" "receive_ge_packager" "pass"
	PRINT_LOG "INFO" "receive packet is successfully"
else
	fn_writeResultFile "${RESULT_FILE}" "receive_ge_packager" "fail"
	PRINT_LOG "FATAL" "receive packet is fail "
fi

check_result ${RESULT_FILE}	

}


#恢复环境
function clean_env()
{
    #清除临时文件
    FUNC_CLEAN_TMP_FILE
    
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

main 
ret=$?
#LAVA平台上报结果接口，勿修改
lava-test-case "$test_name" --result ${test_result}
exit ${ret}















