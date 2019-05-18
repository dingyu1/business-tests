#!/bin/bash

#*****************************************************************************************
# *用例名称：NIC_BASIC_Identification_001                                                    
# *用例功能：网卡识别测试                                               
# *作者：cwx620666                                                                     
# *完成时间：2019-5-8                                                            
# *前置条件：                                                                            
#    1.服务器1台且已安装操作系统
#     2.被测网卡一块                                                               
# *测试步骤：                                                                               
#   1、lspci查看网卡设备
#	2、ip a查看网卡MAC、IP信息
#	3、给网口设置IP，ping网络  (网口已有ip，不需要再设置)
# *测试结果：                                                                            
#   1.服务器上电后能正常检测到网卡和网口
#	2.能ping通无丢包
#	3.遍历服务器PCIE卡槽、均无异常                                                   
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

function check_ip()
{
	IP=$1
	VALID_CHECK=$(echo $IP|awk -F. '$1<=255&&$2<=255&&$3<=255&&$4<=255{print "yes"}')
	if echo $IP|grep -E "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$">/dev/null;then
		if [ ${VALID_CHECK:-no}=="yes" ];then
			echo "IP $IP available"
			PRINT_LOG "INFO" "$IP is available" 
			fn_writeResultFile "${RESULT_FILE}" "IP_info" "pass"
		else
			echo "IP $IP not available"
			PRINT_LOG "INFO" "$IP is not available" 
			fn_writeResultFile "${RESULT_FILE}" "IP_info" "fail"
		fi
	else
		echo "IP $IP formort error"
		PRINT_LOG "INFO" "IP format error" 
		fn_writeResultFile "${RESULT_FILE}" "IP_info_format" "fail"
			
	fi
}



#************************************************************#
# Name        : verify_connect                               #
# Description : 确认网络连接                               #
# Parameters  : 无
# return value：无              #
#************************************************************#
function verify_connect(){
	network=$1
	IP_table=`cat ../../../../../utils/env_parameter.inc`

	debug=false
	if [ $debug = true ];then
	cat << EOF > IP_table.txt
	client_ip_10=192.168.1.3
	client_ip_20=192.168.10.3
	client_ip_30=192.168.20.3
	client_ip_40=192.168.30.3
	#client_ip_50=192.168.50.11
	
	server_ip_10=192.168.1.6
	server_ip_20=192.168.10.6
	server_ip_30=192.168.20.6
	server_ip_40=192.168.30.6
	#server_ip_50=192.168.50.12
EOF
		IP_table=`cat IP_table.txt`
	fi
	
	local_ip=`ip address show $network |  grep -w inet | awk -F'[ /]+' '{print $3}'`
	remote_ip=`echo $IP_table | sed 's/ /\n/g' | grep -w ${local_ip%.*} | grep -v $local_ip | awk -F = '{print $2}'`
	echo $remote_ip
	ping $remote_ip -c 5
	if [ $? -eq 0 ]
	then 
		PRINT_LOG "INFO" "$remote_ip connect properly."
		fn_writeResultFile "${RESULT_FILE}" "${remote_ip}_connect" "pass"
	else
		PRINT_LOG "FATAL" "$remote_ip connect is not normal."
		fn_writeResultFile "${RESULT_FILE}" "${remote_ip}_connect" "fail"
		ip a
		echo "ping test"
		ping $remote_ip -c 5
		return 1
	fi
	sleep 5
}

#测试执行
function test_case()
{
		fn_get_physical_network_card network_interface_list
		echo "$network_interface_list"
		for t in $network_interface_list
		do
			echo "$t"
			bus_info=`ethtool -i $t|grep "bus-info"|awk -F":" '{print $3":"$4}'`
			if [ ${#bus_info} -eq 7 ];then
				echo "$t bus-info $bus_info length is 7"
				PRINT_LOG "INFO" "$t bus-info $bus_info length is 7"
				fn_writeResultFile "${RESULT_FILE}" "$t_bus_info" "pass"
			else
				echo "$t bus-info $bus_info length not is 7"
				PRINT_LOG "INFO" "$t bus-info $bus_info length not is 7"
				fn_writeResultFile "${RESULT_FILE}" "$t_bus_info" "fail"
			fi
			
			lspci -v -s $bus_info
			echo "$t interface lspci info"
			PRINT_LOG "INFO" "$i interface lspci info" 
			
			mac_info=`ip a show $t |grep "link/ether"|awk '{print $2}'`
			if [ ${#mac_info} -eq 17 ];then
				echo "$t mac is $mac_info length is 17"
				PRINT_LOG "INFO" "$t mac is $mac_info length is 17" 
				fn_writeResultFile "${RESULT_FILE}" "mac_info" "pass"
			else
				echo "$t mac is $mac_info length not is 17"
				PRINT_LOG "FATAL" " $t mac is $mac_info length is 17 " 
				fn_writeResultFile "${RESULT_FILE}" "mac_info" "fail"
			fi
			
			
			ipv4_info=`ip a show $t |grep -w "inet"|awk '{print $2}'|awk -F"/" '{print $1}'`
			echo $ipv4_info
			check_ip $ipv4_info
			
			#确认网络连接状态
			verify_connect $t
		done
	
	
	
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
	[ "${test_result}" = "pass" ] || return 1
}

main $@
ret=$?
#LAVA平台上报结果接口，勿修改
lava-test-case "$test_name" --result ${test_result}
exit ${ret}