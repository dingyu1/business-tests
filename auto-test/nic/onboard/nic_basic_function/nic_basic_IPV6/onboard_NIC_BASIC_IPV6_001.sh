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
# Name        : get_tc_ip                               #
# Description : 获取对端ip                               #
# Parameters  : $1=网口
# return value：无              #
#************************************************************#
function get_tc_ip(){
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
	
	sut_ip=`ip address show $network |  grep -w inet | awk -F'[ /]+' '{print $3}'`
	tc_ip=`echo $IP_table | sed 's/ /\n/g' | grep -w ${sut_ip%.*} | grep -v $sut_ip | awk -F = '{print $2}'`
	echo $tc_ip
}

#************************************************************#
# Name        : ipv6_test                               #
# Description : ipv6测试                              #
# Parameters  : $1=网口
# return value：无              #
#************************************************************#
function ipv6_test(){
	sut_name=$1
	tc_ip=$(get_tc_ip $sut_name)
	ping $tc_ip -c 5
	if [ $? -eq 0 ];then
		PRINT_LOG "INFO" "$tc_ip connect properly."
		fn_writeResultFile "${RESULT_FILE}" "${tc_ip}_connect" "pass"
		#ip a del 2001:da8:2004:1000:202:116:160:41/64 dev $sut_name
        ip a add 2001:da8:2004:1000:202:116:160:41/64 dev $sut_name

		sleep 2
		
		tc_name=`${SSH} root@${tc_ip} ip a | grep $tc_ip | awk '{print $NF}'`
		#$SSH root@${tc_ip} ip a del 2001:da8:2004:1000:202:116:160:42/64 dev $tc_name
		$SSH root@${tc_ip} ip a add 2001:da8:2004:1000:202:116:160:42/64 dev $tc_name
		
		sleep 2
		
		ping6 2001:da8:2004:1000:202:116:160:42 -c 5
        if [ $? -ne 0 ];then
           fn_writeResultFile "${RESULT_FILE}" "${sut_name}_ipv6_connect" "fail"
        else
           fn_writeResultFile "${RESULT_FILE}" "${sut_name}_ipv6_connect" "pass"
        fi
		sleep 5
		
		ip a del 2001:da8:2004:1000:202:116:160:41/64 dev $sut_name
		ip a show $sut_name
		$SSH root@${tc_ip} ip a del 2001:da8:2004:1000:202:116:160:42/64 dev $tc_name
		$SSH root@${tc_ip} ip a show $tc_name
	else
		PRINT_LOG "FATAL" "$tc_ip connect is not normal."
		fn_writeResultFile "${RESULT_FILE}" "${tc_ip}_connect" "fail"
	fi
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
    fn_install_pkg "sshpass" 2
	fn_install_pkg "ethtool" 2
	distinguish_card
	#board_card=(enp125s0f2)
}



#测试执行
function test_case()
{
   	for net in ${board_card[@]}
	do
		ipv6_test $net 
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

