#!/bin/bash

#*****************************************************************************************
# *用例名称：CPU压力测试                                                         
# *用例功能：验证CPU加压下OS运行正常                                                 
# *作者：swx562878                                                                       
# *完成时间：2019-3-26                                                                   
# *前置条件：                                                                            
#   1、已连接本地KVM和远程KVM
#	2、OS没有异常
#	3、OS已配置SOL，连接系统串口
#	4、安装stress                                                                  
# *测试步骤：                                                                               
#   1、使用stress对CPU进行压力测试2个小时：
#	stress -c n -t 7200，其中n是CPU虚拟核数，有结果A)      
# *测试结果：                                                                            
#   A)测试过程中，系统运行正常且无任何错误信息输出。无掉盘，网卡link状态正常                                                       
#*****************************************************************************************

#加载公共函数
. ../../../../utils/test_case_common.inc
. ../../../../utils/error_code.inc
. ../../../../utils/sys_info.sh
. ../../../../utils/sh-test-lib		

#获取脚本名称作为测试用例名称
test_name=$(basename $0 | sed -e 's/\.sh//')
#创建log目录

logpath=`pwd`
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
cpu_num=$(lscpu |grep ^"CPU(s)" |awk -F ':' '{print $2}' |awk '{sub("^ *","");sub(" *$","");print}')
test_time=20
#自定义函数区域（可选）
#function xxx()
#	{}

function install_stress()
{
	if [ ! -d "/home/stress" ];then
		mkdir -p /home/stress
	else
		rm -rf /home/stress
		mkdir -p /home/stress
	fi
	cd /home/stress
	wget -c -q  --no-check-certificate  http://172.19.20.15:8083/perform_depends/test_dependent/stress-1.0.4.tar.gz
        tar -xf stress-1.0.4.tar.gz
        cd stress-1.0.4
        ./configure
        make
        make install
	cd $logpath
}

#预置条件
function init_env()
{
    #检查结果文件是否存在，创建结果文件：
	fn_checkResultFile ${RESULT_FILE}
    #自定义测试预置条件检查实现部分：比如工具安装，检查多机互联情况，执行用户身份 
	#需要安装工具，使用公共函数install_deps，用法：install_deps "${pkgs}"
	#需要日志打印，使用公共函数PRINT_LOG，用法：PRINT_LOG "INFO|WARN|FATAL" "xxx"

	fn_install_pkg "wget gcc make" 2
	if [ $? -eq 0 ];then
		fn_writeResultFile "${RESULT_FILE}" "install_deps"  "pass"
	else
		fn_writeResultFile "${RESULT_FILE}" "install_deps"  "fail"
	fi
	install_stress
	if [ $? -eq 0 ];then
                fn_writeResultFile "${RESULT_FILE}" "install_stress"  "pass"
        else
                fn_writeResultFile "${RESULT_FILE}" "install_stress"  "fail"
        fi

}

#测试执行
function test_case()
{
	#测试步骤实现部分
	#如果执行的命令分系统，请使用distro变量来区分OS类型
	#需要日志打印，使用公共函数PRINT_LOG，用法：PRINT_LOG "INFO|WARN|FATAL" "xxx"
	#记录每项测试结果，使用公共函数fn_writeResultFile，用法：fn_writeResultFile "${RESULT_FILE}" "test_item_name" "pass|fail"
	
	dmesg -c
	cd $logpath/../../../../utils/check
        ./checkcpu.sh
        ./checkhdd.sh
        ./checkmem.sh
        ./checknet.sh 0 0
        ./checkpci.sh
	cd -

	stress -c ${cpu_num} -t ${test_time} > ${TMPFILE}
	sleep 20
	grep -rn "WARN|FATAL|FAIL" ${TMPFILE}	
	if [ $? == 0 ];then
		fn_writeResultFile "${RESULT_FILE}" "check_num" "fail"
	else
		fn_writeResultFile "${RESULT_FILE}" "check_num" "pass"
	fi
	
	cd $logpath/../../../../utils/check
	./checkcpu.sh
        ./checkhdd.sh
        ./checkmem.sh
        ./checknet.sh 1 1
        ./checkpci.sh
	cd -

	for file in `ls $logpath/../../../../utils/check/*result.log`
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
	rm -rf /home/stress
	ls $logpath/../../../../utils/check/* |grep -v .sh$|xargs rm -rf 
}


function main()
{
	init_env || test_result="fail"
	if [ ${test_result} = "pass" ];then
		test_case || test_result="fail"
	fi
	clean_env || test_result="fail"
}

main $@
ret=$?
#LAVA平台上报结果接口，勿修改
lava-test-case "$test_name" --result ${test_result}
exit ${ret}
