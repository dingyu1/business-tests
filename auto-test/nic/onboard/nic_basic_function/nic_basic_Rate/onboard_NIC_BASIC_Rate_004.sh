#!/bin/bash

#*****************************************************************************************
# *用例名称：New_NIC_BASIC_Rate_004                                                  
# *用例功能：电口速率和双工模式设置                                             
# *作者：cwx620666                                                                     
# *完成时间：2019-5-8                                                            
# *前置条件：                                                                            
#    1.单板启动正常
#	 2.所有电口各模块加载正常                                                              
# *测试步骤：                                                                               
#   1.网口up后，使用ethtool命令先关闭自协商，再分别设置为10M 半双工、10M 全双工、100M 半双工、
#	100M 全双工、1000M 全双工，有结果A）。
#	2.设置为1000M 半双工，有结果B）。
#	步骤1和2命令参考，如10M全双工命令：ethtool -s 网口 speed 10 duplex full autoneg off
#	10M半双工命令：ethtool -s 网口 speed 10 duplex half autoneg off，
#	3.使用ethtool命令查询基本配置，确认设置成功：ethtool 网口，有结果C）
# *测试结果：                                                                            
#   A）命令执行成功
#	B）命令返回不支持此模式
#	C）查询到正确的速率                                                  
#*****************************************************************************************

#加载公共函数
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
		PRINT_LOG "INFO" "You must be root user " 
		fn_writeResultFile "${RESULT_FILE}" "Run as root" "fail"
		return 1
	fi
}

function speed_10_test_info()
{
	test_port=$1
	ethtool $test_port |grep -i "Advertised link modes"|grep 10
	if [ $? -eq 0 ];then
		echo "speed=10"
		fn_writeResultFile "${RESULT_FILE}" "speed_10_test_info" "pass"
		else 
		echo "speed!=10 "
		fn_writeResultFile "${RESULT_FILE}" "speed_10_test_info" "fail"
	fi
	
}

function speed_100_test_info()
{
	test_port=$1
	ethtool $test_port |grep -i "Advertised link modes"|grep 100
	if [ $? -eq 0 ];then
		echo "speed=100"
		fn_writeResultFile "${RESULT_FILE}" "speed_100_test_info" "pass"
		else 
		echo "speed!=100"
		fn_writeResultFile "${RESULT_FILE}" "speed_100_test_info" "fail"
	fi
}

function speed_1000_test_info()
{
	test_port=$1
	ethtool $test_port |grep -i "Advertised link modes"|grep 1000
	if [ $? -eq 0 ];then
		echo "speed=1000"
		fn_writeResultFile "${RESULT_FILE}" "speed_1000_test_info" "pass"
		else 
		echo "speed!=1000"
		fn_writeResultFile "${RESULT_FILE}" "speed_1000_test_info" "fail"
	fi
}

#测试执行
function test_case()
{
	fn_get_physical_network_card network_interface_list
	echo "$network_interface_list"
	for i in $network_interface_list
	do
		echo " port :$i"
		tp_port=`ethtool  $i |grep "Supported ports"|awk '{print $4}'`
		if [ $tp_port = "TP" ];then
			echo "TP port is $i"
			ethtool -s $i autoneg on
			ifconfig $i up
			
			for t in 10 100 1000
			do
				for j in half full
				do 
					ethtool -s $i autoneg off speed $t duplex $j
					if [ $? -eq 0 ];then
						echo "command autoneg off speed $t duplex $j  success"
						else 
						echo "command autoneg off speed $t duplex $j fail"
					fi
					sleep 10
					speed_"$t"_test_info $i
				done
			done
		fi	
	done

	
	#检查结果文件，根据测试选项结果，有一项为fail则修改test_result值为fail，
	check_result ${RESULT_FILE}
}

#恢复环境
function clean_env()
{
	
	fn_get_physical_network_card network_interface_list
	echo "$network_interface_list"
	for i in $network_interface_list
	do
		echo $i
		tp_port=`ethtool  $i |grep "Supported ports"|awk '{print $4}'`
		if [ $tp_port = "TP" ];then
			echo "TP port is $i"
			ethtool -s $i autoneg on
		fi
	done
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
	[ "${test_result}" = "pass" ] || return 1
}

main $@
ret=$?
#LAVA平台上报结果接口，勿修改
lava-test-case "$test_name" --result ${test_result}
exit ${ret}