#!/bin/bash

#*****************************************************************************************
#用例名称：onboard_NIC_BASIC_IPV6_001
#用例功能：ipv6支持测试
#作者：lwx588815
#完成时间：2019-4-29
#前置条件
#
#测试步骤
#   1、 单板上电启动，进入OS
#   2、 配置网卡IPV6,如ifconfig eth0 inet6 add 2001:da8:2004:1000:202:116:160:41/64 up
#   3、 测试IPV6是否能正常通信，如：ping6 2001:da8:2004:1000:202:116:160:41
#   4、 遍历所有网口
#测试结果
#   A) 能正常配置IPV6
#   B) 能正常通信
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
    fn_install_pkg "sshpass" 2
}

#测试执行
function test_case()
{   
    ip_board=$env_tc_on_board_fiber_0
    netw=`ip route | sed -r -n 's/.*dev (\w+).*src ([^ ]*) .*/\1 \2/p'|egrep -v "vir|br|vnet|lo" |grep $ip_board|awk '{print $1}'`
    network=`ip route | sed -r -n 's/.*dev (\w+).*src ([^ ]*) .*/\1 \2/p'|egrep -v "vir|br|vnet|lo|$netw"|awk '{print $1}'`
    for i in $network
    do	
        ip a del 2001:da8:2004:1000:202:116:160:41/64 dev $i
        ip a add 2001:da8:2004:1000:202:116:160:41/64 dev $i
        sleep 2
        ip a |grep "2001:da8:2004:1000:202:116:160:41/64"
	if [ $? -ne 0 ];then
           PRINT_LOG "FATAL" "set-ipv6-fail"
           fn_writeResultFile "${RESULT_FILE}" "set-ipv6-$i-error" "fail"
	else
	   PRINT_LOG "INFO" "set ipv6 success."
           fn_writeResultFile "${RESULT_FILE}" "set-ipv6-$i-ok" "pass"
	fi
        
        sshpass -p root ssh root@$ip_board ip a del 2001:da8:2004:1000:202:116:160:42/64 dev $i
        sshpass -p root ssh root@$ip_board ip a add 2001:da8:2004:1000:202:116:160:42/64 dev $i

        sleep 5    
	ping6 2001:da8:2004:1000:202:116:160:42 -c 3
	if [ $? -ne 0 ];then
	   PRINT_LOG "FATAL" "ping-$i-ipv6-fail"
           fn_writeResultFile "${RESULT_FILE}" "ping6-$i-fail" "fail"
	else
	   PRINT_LOG "INFO" "ping-$i-ipv6-ok"
           fn_writeResultFile "${RESULT_FILE}" "ping6-$i-ok" "pass"
	fi
        ip a del 2001:da8:2004:1000:202:116:160:41/64 dev $i
        sshpass -p root ssh root@$ip_board ip a del 2001:da8:2004:1000:202:116:160:42/64 dev $i
	
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


