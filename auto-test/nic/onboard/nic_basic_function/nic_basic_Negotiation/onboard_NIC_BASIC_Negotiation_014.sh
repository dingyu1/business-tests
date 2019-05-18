#!/bin/bash

#*****************************************************************************************
# *用例名称：New_NIC_BASIC_Negotiation_014                                                  
# *用例功能：对端指定1000MSpeed开启自协商，本端板载电口自协商测试                                            
# *作者：cwx620666                                                                     
# *完成时间：2019-5-8                                                            
# *前置条件：                                                                            
#    1.网卡为默认设置                                                              
# *测试步骤：                                                                               
#   1、对端使用命令ethtool -s ethx  speed 1000 duplex full autoneg on命令修改对端网卡速率。
#	2、待协商成功后，使用ethtool ethx查看测试端网卡适配信息，有结果A
#	3、本端ping对端的ip，有结果B
#	4、遍历板载电口
# *测试结果：                                                                            
#  A)
#	Speed: 1000Mb/s
#	Duplex: Full
#	Auto-negotiation: on
#	
#	B)ip能ping通                                                 
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
	
	fn_install_pkg "gcc" 3
	fn_install_pkg "make" 3
	fn_install_pkg "sshpass" 3
	sshpass -h
	if [ $? -ne 0 ];then
		cd ../../../../../utils/sshpass.tar.gz
		cp sshpass.tar.gz /home
		tar -zxvf /home/sshpass.tar.gz
		chmod 777 -R /home/sshpass
		cd -
		cd /home/sshpass
		./configure
		make && make install
		cd -
	fi
	return 0
}


#测试执行
function test_case()
{	
	
	SSH="timeout 1000 sshpass -p root ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
	tc_port_20=`$SSH root@$env_tc_on_board_fiber_10 ip a | grep $env_tc_on_board_TP_20 | awk '{print $NF}'`
    tc_port_30=`$SSH root@$env_tc_on_board_fiber_10 ip a | grep $env_tc_on_board_TP_30 | awk '{print $NF}'`
	echo $tc_port_20
    echo $tc_port_30
	
	$SSH root@$env_tc_on_board_fiber_10 ethtool -s $tc_port_20  autoneg on
    $SSH root@$env_tc_on_board_fiber_10 ethtool -s $tc_port_30  autoneg on
	sleep 10
	$SSH root@$env_tc_on_board_fiber_10 ethtool -s $tc_port_20 speed 1000 duplex full autoneg on
    $SSH root@$env_tc_on_board_fiber_10 ethtool -s $tc_port_30 speed 1000 duplex full autoneg on
	sleep 10
	
	##tc_port_20=`$SSH root@192.168.1.3 ip a | grep 192.168.20.3 | awk '{print $NF}'`
    ##tc_port_30=`$SSH root@$192.168.1.3 ip a | grep 192.168.30.3 | awk '{print $NF}'`
	##echo $tc_port_20
    ##echo $tc_port_30
	##
	##$SSH root@192.168.1.3 ethtool -s $tc_port_20 autoneg on
    ##$SSH root@192.168.1.3 ethtool -s $tc_port_30  autoneg on
	##sleep 10
	##
	##$SSH root@192.168.1.3 ethtool -s $tc_port_20 speed 1000 duplex full autoneg on
    ##$SSH root@192.168.1.3 ethtool -s $tc_port_30 speed 1000 duplex full autoneg on
	##sleep 10
	
	sut_port_20=`ip route|grep -i $env_sut_on_board_TP_20 |awk '{print $3}'`
	sut_port_30=`ip route|grep -i $env_sut_on_board_TP_30 |awk '{print $3}'`
	
	##sut_port_20=`ip route|grep -i 192.168.20.6 |awk '{print $3}'`
	##sut_port_30=`ip route|grep -i 192.168.30.6 |awk '{print $3}'`
	
	for i in $sut_port_20 $sut_port_30
	do
	#for i in enp125s0f2
		echo $i
		ethtool -s $i  autoneg on
		sleep 10
		tp_port=`ethtool  $i |grep "Supported ports"|awk '{print $4}'`
		if [ $tp_port = "TP" ];then
			echo "$i is onboard TP port"
			speed_info=`ethtool $i |grep "Speed"|awk -F ':' '{print $2}'|sed 's/ //g'|sed 's/Mb\/s//g'`
			if [ $speed_info = "1000" ];then
				echo "the interface $i speed is 1000Mb/s "
				PRINT_LOG "INFO" "$i speed is $speed_info" 
				fn_writeResultFile "${RESULT_FILE}" "speed_info" "passs"
			else
				echo "the interface $i speed not is 1000Mb/s "
				PRINT_LOG "INFO" "$i speed is $speed_info" 
				fn_writeResultFile "${RESULT_FILE}" "speed_info" "fail"
			fi
			duplex_info=`ethtool $i |grep "Duplex"|awk '{print $NF}'`
			if [ $duplex_info = "Full" ];then
				echo "the interface $i duplex is full "
				PRINT_LOG "INFO" "$i duplex is $duplex_info" 
				fn_writeResultFile "${RESULT_FILE}" "duplex_info" "pass"
			else
				echo "the interface $i duplex not is full "
				PRINT_LOG "INFO" "$i duplex is $duplex_info" 
				fn_writeResultFile "${RESULT_FILE}" "duplex_info" "fail"
			fi
			autoneg_info=`ethtool $i |grep "Auto-negotiation"|awk '{print $NF}'`
			if [ $autoneg_info = "on" ];then
				echo "the interface $i autoneg is on "
				PRINT_LOG "INFO" "$i autoneg_info is $autoneg_info" 
				fn_writeResultFile "${RESULT_FILE}" "autoneg_info" "pass"
			else
				echo "the interface $i autoneg not is on "
				PRINT_LOG "INFO" "$i autoneg_info is $autoneg_info" 
				fn_writeResultFile "${RESULT_FILE}" "autoneg_info" "fail"
			fi
		fi
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