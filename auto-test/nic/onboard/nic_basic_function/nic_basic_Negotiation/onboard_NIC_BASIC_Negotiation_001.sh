#!/bin/bash

#*****************************************************************************************
#用例名称：NIC_BASIC_Negotiation_001
#用例功能：网卡PCIE自协商测试
#作者：hwx653129
#完成时间：2019-1-28

#前置条件：
# 	无

#测试步骤：
# 	1. 将网卡插到PCIE槽上，单板上电，进入系统后，通过lspic |grep -I eth查看到是否能找到网卡，lspci -vvv 查询网卡协商是否正常，有结果A)
# 	2. 配置IP检查网卡是否能正常通信，有结果B)
# 	3. 支持的网卡需要遍历支持的PCIE槽位，重复步骤1-2

#测试结果:
# 	A) OS下能找到网卡，网卡PCIe 协商速率带宽LnkSta字段显示的值正常
# 	B) 网卡能正常通信。                                               
#*****************************************************************************************

#加载公共函数,具体看环境对应的位置修改
#. ./utils/test_case_common.inc
#. ./utils/error_code.inc
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

#************************************************************#
# Name        : distinguish_card                               #
# Description : 区分板载和标卡                              #
# Parameters  : 无                                           #
#************************************************************#
function distinguish_card(){
    #查找所有物理网卡
    fn_get_physical_network_card total_network_cards
	total_network_cards=(`echo ${total_network_cards[@]}`)
	
    for ((i=0;i<${#total_network_cards[@]};i++))
    do
        driver=`ethtool -i ${total_network_cards[i]} | grep driver | awk '{print $2}'`
        if [ "$driver" == "hns" -o "$driver" == "hns3" ];then
            board_card[i]=${total_network_cards[i]}
            board_card=(`echo ${board_card[@]}`)
        else
            standard_card[i]=${total_network_cards[i]}
            standard_card=(`echo ${standard_card[@]}`)
        fi
    done
}
#************************************************************#
# Name        : verify_negotiate                               #
# Description : 确认网卡协商速率                               #
# Parameters  : 无                                           #
#************************************************************#
function verify_negotiate(){
	for net in ${board_card[@]}
	do
		bus_num=`ethtool -i $net | grep bus | awk '{print $2}'`
		LnkSta=`lspci -s $bus_num -vvv | grep LnkSta: | cut -d " " -f 2`
		LnkCap=`lspci -s $bus_num -vvv | grep LnkCap: | cut -d " " -f 4`	
		if [ "$LnkSta" == "$LnkCap" ]
		#网卡协商正常
		then 
			PRINT_LOG "INFO" "$net standard speed is equal to capacity speed."
			fn_writeResultFile "${RESULT_FILE}" "${net}_speed_negotiate" "pass"
		else
			PRINT_LOG "FATAL" "$net standard speed is not equal to capacity speed, please check it."
			fn_writeResultFile "${RESULT_FILE}" "${net}_speed_negotiate" "fail"
			return 1
		fi	
	done
}
#************************************************************#
# Name        : verify_connect                               #
# Description : 确认网卡连通性                               #
# Parameters  : 无                                           #
#************************************************************#
function verify_connect(){
	debug=false
	password=$env_tc_passwd
	test_ip=($env_tc_on_board_fiber_0 $env_tc_on_board_fiber_10 $env_tc_on_board_TP_20 $env_tc_on_board_TP_30)
	if [ "$debug" = true ];then
		password=root
		test_ip=(192.168.1.6 192.168.10.6 192.168.20.6 192.168.30.6)
		env_tc_on_board_fiber_0=192.168.1.6
	fi
	SSH="sshpass -p $password ssh -o StrictHostKeyChecking=no"
	
	
	for ip in ${test_ip[@]}
	do
		ping $ip -c 5
		if [ $? -eq 0 ]
		then 
			PRINT_LOG "INFO" "$ip connect properly."
			fn_writeResultFile "${RESULT_FILE}" "${ip}_connect" "pass"
		else
			PRINT_LOG "FATAL" "$ip connect is not normal."
			fn_writeResultFile "${RESULT_FILE}" "${ip}_connect" "fail"
			ip a
			echo "client-------------"
			ping $env_tc_on_board_fiber_0 -c 5
			$SSH root@$env_tc_on_board_fiber_0 "ip a"
			return 1
		fi
		sleep 5
	done
}

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
	sshpass -h || fn_install_pkg "sshpass" 10
	distinguish_card
    #自定义测试预置条件检查实现部分：比如工具安装，检查多机互联情况，执行用户身份 
      #需要安装工具，使用公共函数install_deps，用法：install_deps "${pkgs}"
      #需要日志打印，使用公共函数PRINT_LOG，用法：PRINT_LOG "INFO|WARN|FATAL" "xxx"
}

#测试执行
function test_case()
{
	verify_negotiate
	verify_connect

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