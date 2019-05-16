#!/bin/bash
set -x
#===========================================================
#用例名称：NIC_BASIC_Statistics_004
#用例功能：接入小网后网口标准统计查询
#作者：dwx588814
#完成时间：2019-1-30
#前置条件
#    1.单板启动正常
#    2.所有xGE网口各模块加载正常
#测试步骤
#	1.网口正常初始化后，接入小网，等待10分钟
#   2.调用标准统计接口查询(ethtool ethx)
#	3.ifconfig ethx查看是否丢包错包
#测试结果
#   1.正确打印标准统计
#	2.底层没有丢包和错包
#===========================================================

#加载公共函数,具体看环境对应的位置修改
. ../../../../../utils/error_code.inc
. ../../../../../utils/test_case_common.inc
. ../../../../../utils/sys_info.sh
. ../../../../../utils/sh-test-lib
. ../../../../../utils/env_parameter.inc


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


install_deps "wget gcc automake make sshpass ethtool" 
#判断是否安装netperf,如果没有 就安装
if [ ! -n "$(which netperf)" ]
then
    echo "don't have netperf"
    wget  ${ci_http_addr}/test_dependents/netperf.tar.gz
    tar -zxf netperf.tar.gz && rm -rf netperf.tar.gz
    cd netperf
    ./install_netperf.sh
    cd ../
else
    netperf -V
    echo "netperf is already installed"
fi

SSH="timeout 1000 sshpass -p root ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" 
SCP="timeout 1000 sshpass -p root scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
  
}

#测试执行
function test_case()
{
#获取本端和对端网卡ip
sut_ip_10=$env_sut_on_board_fiber_10
tc_ip_10=$env_tc_on_board_fiber_10
	

#获取本端ip对应网卡名称
sut_eth=`ip addr|grep $sut_ip_10 |awk '{print $NF}'`

#执行ethtool ethx
xge=`ethtool $sut_eth|grep "Supported ports"|awk '{print $4}'`
if [ "$xge"x == "FIBRE"x ]
then
	fn_writeResultFile "${RESULT_FILE}" "ethtool_ethx_fiber" "pass"
	PRINT_LOG "INFO" "the network_card is fiber"
else
	fn_writeResultFile "${RESULT_FILE}" "ethtool_ethx_fiber" "fail"
	PRINT_LOG "FATAL" "the network_card is  not fiber"
fi


#获取网卡统计数据信息
ip -s link ls $sut_eth > eth.log 2>&1
RX_packets=`awk -v line=$(awk '/RX/{print NR}' eth.log) '{if(NR==line+1){print $2}}' eth.log`
TX_packets=`awk -v line=$(awk '/TX/{print NR}' eth.log) '{if(NR==line+1){print $2}}' eth.log`
RX_dropped=`awk -v line=$(awk '/RX/{print NR}' eth.log) '{if(NR==line+1){print $4}}' eth.log`
TX_dropped=`awk -v line=$(awk '/TX/{print NR}' eth.log) '{if(NR==line+1){print $4}}' eth.log`
RX_overruns=`awk -v line=$(awk '/RX/{print NR}' eth.log) '{if(NR==line+1){print $5}}' eth.log`
TX_overruns=`awk -v line=$(awk '/TX/{print NR}' eth.log) '{if(NR==line+1){print $5}}' eth.log`

#关闭防火墙
case "$distro" in
    centos|redhat)
		systemctl stop firewalld
		;;
	ubuntu|debian)
		apt install ufw -y
		ufw disable
		;;
	suse)
		zypper install -y firewalld
		systemctl stop  firewalld
		;;
esac

#本端开启netperf	
pkill netserver
netserver


#在对端向本端发包
path=`pwd`
$SCP $path/install_netperf.sh  root@$env_tc_on_board_fiber_10:/root/
$SSH root@$env_tc_on_board_fiber_10 "bash install_netperf.sh; netperf -H $env_sut_on_board_fiber_10 -t UDP_STREAM -l 30 -- -m 10240; exit"


#查询网卡在客户端发包后的收包信息
ip -s link ls $sut_eth > eth.log.later 2>&1
RX_packets_later=`awk -v line=$(awk '/RX/{print NR}' eth.log.later) '{if(NR==line+1){print $2}}' eth.log.later`
TX_packets_later=`awk -v line=$(awk '/TX/{print NR}' eth.log.later) '{if(NR==line+1){print $2}}' eth.log.later`
RX_dropped_later=`awk -v line=$(awk '/RX/{print NR}' eth.log.later) '{if(NR==line+1){print $4}}' eth.log.later`
TX_dropped_later=`awk -v line=$(awk '/TX/{print NR}' eth.log.later) '{if(NR==line+1){print $4}}' eth.log.later`
RX_overruns_later=`awk -v line=$(awk '/RX/{print NR}' eth.log.later) '{if(NR==line+1){print $5}}' eth.log.later`
TX_overruns_later=`awk -v line=$(awk '/TX/{print NR}' eth.log.later) '{if(NR==line+1){print $5}}' eth.log.later`


if [ $RX_packets_later -gt $RX_packets ] && [ $TX_packets_later -gt $TX_packets ] && [ $RX_dropped_later -eq $RX_dropped ] && [ $TX_dropped_later -eq $TX_dropped ] && [ $RX_overruns_later -eq $RX_overruns ] && [ $TX_overruns_later -eq $TX_overruns  ]
then
	fn_writeResultFile "${RESULT_FILE}" "RX-TX-statistics" "pass"
	PRINT_LOG "INFO" "Receiving and sending statistics are successful"
else
	fn_writeResultFile "${RESULT_FILE}" "RX-TX-statistics" "fail"
	PRINT_LOG "FATAL" "failed to Receiving and sending statistics  "
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

main $@
ret=$?
#LAVA平台上报结果接口，勿修改
lava-test-case "$test_name" --result ${test_result}
exit ${ret}
