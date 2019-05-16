#!/bin/bash

#*****************************************************************************************
# *用例名称：CPU频率检查                                                         
# *用例功能：CPU频率检查                                                 
# *作者：lwx652446                                                                      
# *完成时间：2019-2-20                                                               
# *前置条件：                                                                            
#   1、D06服务器1台
#	2、系统启动正常                                                                  
# *测试步骤：                                                                               
#   1 进入操作系统，
#	2 执行dmidecode|grep -I "Current Speed"
#	3 观察操作情况     
# *测试结果：                                                                            
#   显示cpu频率为：2.4GHZ                                                         
#*****************************************************************************************

#加载公共函数
. ../../../../utils/test_case_common.inc
. ../../../../utils/error_code.inc
. ../../../../utils/sys_info.sh
. ../../../../utils/sh-test-lib	

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
		PRINT_LOG "INFO" "You must be root user " 
		fn_writeResultFile "${RESULT_FILE}" "Run as root" "fail"
	fi
}

#测试执行
function test_case()
{
	#检查CPU频率为2.4GHz
    Frequency=`dmidecode|grep -I "Current Speed"|awk -F ":" '{print $2}'|head -n 1|awk '{print $1}'`
	echo $Frequency"MHz"
	if [ $Frequency != "2400" ]
	then
		echo "cpu frequency not is 2.4GHz"
		PRINT_LOG "FATAL" "cpu frequency not is 2.4GHz"
		fn_writeResultFile "${RESULT_FILE}" "Check_007" "fail"
	else
		echo "cpu frequency is 2.4GHz"
		PRINT_LOG "INFO" "cpu frequency is 2.4GHz"
		fn_writeResultFile "${RESULT_FILE}" "Check_007" "pass"
	fi	
	#检查结果文件，根据测试选项结果，有一项为fail则修改test_result值为fail，
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
	init_env || test_result = "fail"
	if [ ${test_result} = "pass" ]
	then
		test_case || test_result="fail"
	fi
	clean_env || test_result="fail"
	[ "${test_result}" = "fail" ] && return 1
}

main $@
ret=$?
#LAVA平台上报结果接口，勿修改
lava-test-case "$test_name" --result ${test_result}
exit ${ret}