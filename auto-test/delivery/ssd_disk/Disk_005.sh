#!/bin/bash

#*****************************************************************************************
# *用例名称：Disk_005                                                      
# *用例功能：硬盘大小查询                                               
# *作者：cwx620666                                                                      
# *完成时间：2019-5-8                                                          
# *前置条件：                                                                            
#   1、安装好redhat操作系统的D06服务器1台
#	2、单板中配置SSD盘                                                                
# *测试步骤：                                                                               
#   1 进入操作系统
#	2 执行lsblk命令     
# *测试结果：                                                                            
#   可以查询到硬盘大小                                                   
#*****************************************************************************************

#加载公共函数
. ../../../utils/error_code.inc
. ../../../utils/test_case_common.inc
. ../../../utils/sys_info.sh
. ../../../utils/sh-test-lib 	

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
		return 1
	fi

}

#测试执行
function test_case()
{
	#查询硬盘容量    
	num=`lsblk |grep disk|awk '{print $1":"$4}'`
	if [ $? -eq 0 ]
	then
	fn_writeResultFile "${RESULT_FILE}" "disk_capacity："$num"" "pass"
	else
	fn_writeResultFile "${RESULT_FILE}" "disk_capacity_command " "fail"
	fi
	echo "disk capacity："$num" "
	
	number=`lsblk |grep disk|awk '{print $4}'|wc -l`
	if [ $? -eq 0 ]
	then
	fn_writeResultFile "${RESULT_FILE}" "It_has_$number_disk" "pass"
	else
	fn_writeResultFile "${RESULT_FILE}" "lsblk_command " "fail"
	fi
	echo "It has $number disk"
	#检查结果文件，根据测试选项结果，有一项为fail则修改test_result值为fail，
	check_result ${RESULT_FILE}
}

#恢复环境
function clean_env()
{
	#清除临时文
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