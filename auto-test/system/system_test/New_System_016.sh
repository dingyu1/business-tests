#!/bin/bash -x

#*****************************************************************************************
# *用例名称：New_System_016                                                         
# *用例功能: reboot -f强制重启测试                                                 
# *作者：dwx572468                                                                       
# *完成时间：2019-3-22                                                                   
# *前置条件：                                                                            
#   1、预装linux系统  
#   1、已插上标卡（intel 82599）和raid卡（3108）                                                                 
# *测试步骤：       
#   1、被测OS安装和升级补丁、驱动完成
#   2、执行reboot -f命令，查看OS是否正常重启
#   3、再次登录系统，查看dmesg是否有异常信息
#      dmesg|egrep -i "error|fail|warn "                                                                        
# *测试结果：       
# 系统可以正常进行重启操作，dmesg信息没有和平常启动不同的异常信息。                                                                     
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

#自定义变量区域（可选）
#var_name1="xxxx"
#var_name2="xxxx"
reboot_ip=172.19.20.162
reboot_user="root"
reboot_pass="root"

#自定义函数区域（可选）
#function xxx()
#	{}

#预置条件
function init_env()
{
    #检查结果文件是否存在，创建结果文件：
	fn_checkResultFile ${RESULT_FILE}
    #自定义测试预置条件检查实现部分：比如工具安装，检查多机互联情况，执行用户身份 
	  #需要安装工具，使用公共函数install_deps，用法：install_deps "${pkgs}"
	  #需要日志打印，使用公共函数PRINT_LOG，用法：PRINT_LOG "INFO|WARN|FATAL" "xxx"
	fn_install_pkg sshpass 1
	if [ $? != 0 ];then
		PRINT_LOG "FATAL" "download pkg"
		exit 1
	fi
}

#测试执行
function test_case()
{
	#测试步骤实现部分
	#如果执行的命令分系统，请使用distro变量来区分OS类型
	#需要日志打印，使用公共函数PRINT_LOG，用法：PRINT_LOG "INFO|WARN|FATAL" "xxx"
	  #记录每项测试结果，使用公共函数fn_writeResultFile，用法：fn_writeResultFile "${RESULT_FILE}" "test_item_name" "pass|fail"
	sshpass -p $reboot_pass scp -r -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ../../../utils/check ${reboot_user}@${reboot_ip}:/home
	timeout 30 sshpass -p $reboot_pass ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${reboot_user}@${reboot_ip} "cd /home/check;./checkcpu.sh;./checkhdd.sh;./checkmem.sh;./checknet.sh 0 0;./checkpci.sh;reboot -f"
	sleep 200
	count=1
	while :
	do
		ping $reboot_ip -c 3 > ${TMPFILE}
		match=`grep "100% packet loss" $TMPFILE`
		if [[ "$match" = "" ]];then
			fn_writeResultFile "${RESULT_FILE}" "reboot" "pass"
			break
		else
			sleep 30
			let count+=1	
		fi
		if [ $count -eq 10 ];then
			fn_writeResultFile "${RESULT_FILE}" "reboot" "fail"
			break
		fi
	done
	sleep 10 
	sshpass -p $reboot_pass ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${reboot_user}@${reboot_ip} "cd /home/check;./checkcpu.sh;./checkhdd.sh;./checkmem.sh;./checknet.sh 1 1 ;./checkpci.sh"
	sshpass -p $reboot_pass scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${reboot_user}@${reboot_ip}:/home/check/check*_result.log ../../../utils/check
	sshpass -p $reboot_pass ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${reboot_user}@${reboot_ip} "rm -rf /home/check"
	for file in `ls ../../../utils/check/*result.log`
	do
		mid=${file##*/}
		issue=${mid%%_*}
		result=`cat $file`
		if [[ "$result" =~ "OK" ]];then
			fn_writeResultFile "${RESULT_FILE}" "$issue" "pass"
		else
			fn_writeResultFile "${RESULT_FILE}" "$issue" "fail"
		fi
	done
	#检查结果文件，根据测试选项结果，有一项为fail则修改test_result值为fail
	check_result ${RESULT_FILE}
}

#恢复环境
function clean_env()
{
	#清除临时文件
	FUNC_CLEAN_TMP_FILE
	#自定义环境恢复实现部分,工具安装不建议恢复
	  #需要日志打印，使用公共函数PRINT_LOG，用法：PRINT_LOG "INFO|WARN|FATAL" "xxx"	
	rm -f ../../../utils/check/check*_result.log
}


function main()
{
	init_env || test_result="fail"
	if [ ${test_result} = "pass" ]
	then
		test_case || test_result="fail"
	fi
	clean_env || test_result="fail"
}

main $@
ret=$?
#LAVA平台上报结果接口，勿修改
# lava-test-case "$test_name" --result ${test_result}
exit ${ret}
