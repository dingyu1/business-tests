#!/bin/bash

#*****************************************************************************************
# *用例名称：Ssd_001                                                      
# *用例功能：ssd盘（es3000）查询                                                
# *作者：lwx652446                                                                      
# *完成时间：2019-2-28                                                               
# *前置条件：                                                                            
#   1、D06服务器1台
#	2、单板中配置一个ssd盘
#	3、安装好suse操作系统                                                                 
# *测试步骤：                                                                               
#   1 登录操作系统
#	2 使用lsblk检查能否查询到ssd盘     
# *测试结果：                                                                            
#   可以查询到ssd盘                                                      
#*****************************************************************************************

#加载公共函数
. ../../utils/error_code.inc
. ../../utils/test_case_common.inc
. ../../utils/sys_info.sh
. ../../utils/sh-test-lib 		

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
	#安装smartmontools工具
	#fn_install_pkg "smartmontools" 3
	
	#使用smartctl判断硬盘类型
	#pkgs="smartmontools"
	#PRINT_LOG "INFO" "Start to install $pkgs"
	#install_deps_ex "${pkgs}"
	#if [ $? -ne 0 ]
	#then
	#	PRINT_LOG "FATAL" "Install $pkgs fail"
	#	fn_writeResultFile "${RESULT_FILE}" "Install $pkgs" "fail"
	#	return 1
	#fi

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
	#lsblk查询ssd盘,rota对应值为0则为SSD盘
	num=`lsblk -d -o name,rota|wc -l`
	i=2
	for i in $num
	do
		if ! `lsblk -d -o name,rota|awk 'NR==$i{print $NF}'`
		then
			echo "No SSD"
			PRINT_LOG "FATAL" "No SSD" 
			fn_writeResultFile "${RESULT_FILE}" "No SSD" "fail"
		else
			echo "has SSD"
			PRINT_LOG "INFO" "SSD test pass" 
			fn_writeResultFile "${RESULT_FILE}" "SSD test" "pass"
		fi
		let i++
	done
	#smartctl查询ssd盘,smartctl -a /dev/$disk_name如果查询到Rotation行值为Solid State Device则判断为ssd盘
	#disk_name=`lsblk |grep disk|awk 'NR==1{print $1}'`
	#if smartctl -a /dev/$disk_name|grep "Rotation Rate"|grep "Solid State Device"
	#then
	#	echo "has SSD"
	#	PRINT_LOG "INFO" "has SSD" 
	#	fn_writeResultFile "${RESULT_FILE}" "has SSD " "pass"
	#else
	#	echo "No SSD"
	#	PRINT_LOG "FATAL" "No SSD" 
	#	fn_writeResultFile "${RESULT_FILE}" "No SSD" "fail"
	#fi

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