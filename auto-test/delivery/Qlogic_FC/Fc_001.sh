#!/bin/bash

#*****************************************************************************************
# *用例名称：Fc_001                                                      
# *用例功能：Qlogic FC识别                                                
# *作者：cwx620666                                                                      
# *完成时间：2019-5-14                                                               
# *前置条件：                                                                            
#   1、D06单板1台
#	2、单板配置Qlogic FC
#	3、安装好suse操作系统                                                                 
# *测试步骤：                                                                               
#   1 登录操作系统
#	2 使用lspci|grep -i QLogic命令查询是否能够查询到Qlogic FC设备     
# *测试结果：                                                                            
#   可以查询到Qlogic FC设备                                                         
#*****************************************************************************************

#加载公共函数
. ../../../utils/test_case_common.inc
. ../../../utils/error_code.inc
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
		fn_writeResultFile "${RESULT_FILE}" "Run_as_root" "fail"
	fi

}

#测试执行
function test_case()
{
	#查询到Qlogic FC设备
	#增加：lspci 查询建链信息
	lspci|grep -i QLogic
	if [ $? -ne 0 ]
	then
		echo "No QLogic devices"
		PRINT_LOG "FATAL" "No QLogic devices"
		fn_writeResultFile "${RESULT_FILE}" "No_QLogic_devices" "fail"
		
		for i in `lspci |grep -i |awk QLogic'{print $1}'`
		do
			link_info=`lspci -vvv -s $i |grep -w LnkSta | awk -F":" '{print $2}'|awk -F"," '{print $1","$2}'`
			echo "link info is : $i  $link_info"
		done
	else
		echo "has QLogic devices"
		PRINT_LOG "INFO" "has QLogic devices"
		fn_writeResultFile "${RESULT_FILE}" "has_QLogic_devices" "pass"
    fi
	
	
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
	init_env || test_result="fail"
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