#!/bin/bash

#*****************************************************************************************
#用例编号：New_NIC_BASIC_Link_003
#用例名称：网口开关容错测试
#作者：hwx658002
#前置条件
#	1、单板启动正常
#	2、所有网口各模块加载正常
#	
#测试步骤
#   1、 调用命令“ifconfig 网口名 up”、“ifconfig 网口名 down”，输入错误的网口名（如eth10），或者空，观察返回情况
#
#	
#测试结果
#   打印信息提示无此设备
#   
#*****************************************************************************************

#加载公共函数,具体看环境对应的位置修改
. ../../../../../utils/error_code.inc
. ../../../../../utils/test_case_common.inc
. ../../../../../utils/sys_info.sh
. ../../../../../utils/sh-test-lib
#. ../../../../../utils/env_parameter.inc

#. ./error_code.inc
#. ./test_case_common.inc

#获取脚本名称作为测试用例名称
test_name=$(basename $0 | sed -e 's/\.sh//')
#创建log目录
TMPDIR=./logs/temp
mkdir -p ${TMPDIR}
#存放脚本处理中间状态/值等
TMPFILE=${TMPDIR}/${test_name}.tmp
TMPFILE1=${TMPDIR}/${test_name}.tmp
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
 #   fn_install_pkg "net-tools" 2
}

#测试执行
function test_case()
{	
#将标准错误重定向到TMPFILE文件中
	ip link set xxx up &>  $TMPFILE
#判断是否包含关键字来确定是否有此设备
	a="`cat $TMPFILE`"
	b="Cannot find"
	if [[ $a =~ $b ]];then
		fn_writeResultFile "${RESULT_FILE}" "Query_xxx_device" "pass"
	else
		fn_writeResultFile "${RESULT_FILE}" "Query_xxx_device" "fail"
	fi

		
	ip link set xxx down &> $TMPFILE1
	a=`cat $TMPFILE1`
	b="Cannot find"
	if [[ $a =~ $b ]];then
		fn_writeResultFile "${RESULT_FILE}" "Query_xxx_device" "pass"
	else
		fn_writeResultFile "${RESULT_FILE}" "Query_xxx_device" "fail"
	fi

	
	

#检查结果文件，根据测试选项结果，有一项为fail则修改test_result值为fail，
   check_result ${RESULT_FILE}
}



#恢复环境
function clean_env()
{

    #清除临时文件
    FUNC_CLEAN_TMP_FILE
	rm -rf ./logs/temp/TMPFILE*
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


