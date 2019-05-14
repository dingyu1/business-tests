#!/bin/bash

#*****************************************************************************************
# *用例名称：Check_008                                                         
# *用例功能：cpu核数检查                                                 
# *作者：lwx652446                                                                      
# *完成时间：2019-2-20                                                               
# *前置条件：                                                                            
#   1、D06服务器1台
#	2、系统启动正常                                                                  
# *测试步骤：                                                                               
#   '1 进入操作系统，
#	2 执行：cat /proc/cpuinfo |grep "processor"|sort -u|wc -l
#	3 观察操作情况    
# *测试结果：                                                                            
#   检查到cpu核数是96个                                                         
#*****************************************************************************************

#加载公共函数
. ./test_case_common.inc
. ./error_code.inc
#. ./common/sys_info.sh
#. ./common/sh-test-lib		

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
	
}

#测试执行
function test_case()
{
	#进入系统查询cpu核数是否是96
	if ! dmesg|grep D06
	then
		cpu_number=`cat /proc/cpuinfo |grep processor |sort -u|wc -l`
		echo "cpu core number:"$cpu_number
		if [ $cpu_number -ne 64 ]
		then
			echo "CpuNumber is not 64"
			PRINT_LOG "FATAL" "CpuNumber is not 64"
			fn_writeResultFile "${RESULT_FILE}" "Check_D05_CPU" "fail"
		else		
			echo "CpuNumber is 64"	
			PRINT_LOG "INFO" "CpuNumber is 64"
			fn_writeResultFile "${RESULT_FILE}" "Check_D05_CPU" "pass"		
		fi
	else
		cpu_number=`cat /proc/cpuinfo |grep processor |sort -u|wc -l`
		echo "cpu core number:"$cpu_number
		if [ $cpu_number -ne 96 ]
		then
			echo "CpuNumber is not 96"
			PRINT_LOG "FATAL" "CpuNumber is not 96"
			fn_writeResultFile "${RESULT_FILE}" "Check_D06_CPU" "fail"
		else		
			echo "CpuNumber is 96"	
			PRINT_LOG "INFO" "CpuNumber is 96"
			fn_writeResultFile "${RESULT_FILE}" "Check_D06_CPU" "pass"		
		fi
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
	[ "${test_result}" = "pass" ] || return 1
}

main $@
ret=$?
#LAVA平台上报结果接口，勿修改
lava-test-case "$test_name" --result ${test_result}
exit ${ret}