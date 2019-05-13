#!/bin/bash

#*****************************************************************************************
# *用例名称：Check_003                                                      
# *用例功能：不同内存占用情况检查                                               
# *作者：cwx620666                                                                     
# *完成时间：2019-5-7                                                               
# *前置条件：                                                                            
#   1、D06单板配置16根32G内存条
#	2 安装有memter工具                                                                
# *测试步骤：                                                                               
#   1 启动D06服务器，进入操作系统
#	2 使用memter工具命令分别检查申请20%的内存、40%、60%、80%的情况     
# *测试结果：                                                                            
#   内存占20%、40%、60%、80%时所有检查项都OK                                                     
#*****************************************************************************************

#加载公共函数
. ../../../../utils/error_code.inc
. ../../../../utils/test_case_common.inc
. ../../../../utils/sys_info.sh
. ../../../../utils/sh-test-lib 	

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
	#调用函数安装unzip
	fn_install_pkg "gcc" 3
	fn_install_pkg "make" 3
	fn_install_pkg "unzip" 3
	
	
#解压lmbench-master文件 路径需要可根据实际修改 cp到本地目录
	
	cd ../../../../utils/tools
	cp lmbench-master.zip /home
	cd /home
	unzip lmbench-master.zip
	chmod -R 777 lmbench-master
	cd lmbench-master/src
	make 
}

#测试执行
function test_case()
{
	#查询内存
	
	cd /home/lmbench-master/bin
	memory=`free -m|grep Mem|awk '{print $2}'`
	echo "total memory："$memory"MB"
	
	#20%内存
	test1=`echo $memory*0.2 |bc`
	echo "20% memory："$test1
	aaa=`./memsize $test1`
	if [ $aaa -ne $test1  ]
	then
		#echo $test1"not equal to "$aaa"test rusualt is fail"
        fn_writeResultFile "${RESULT_FILE}" "20% memroy test " "fail"
	else
		#echo $test1"equal to" $aaa "test rusualt is OK"
        fn_writeResultFile "${RESULT_FILE}" "20% memroy test" "pass"
	fi	
	
	#40%内存
	test2=`echo $memory*0.4 |bc`
	echo "40% memory："$test2
	bbb=`./memsize $test2`
	if [ $bbb -ne $test2 ]
	then
		#echo $test2"not equal to"$bbb"test rusualt is fail"
        fn_writeResultFile "${RESULT_FILE}" "40% memroy test" "fail"
	else
		#echo $test2"equal to"$bbb"test rusualt is OK"
        fn_writeResultFile "${RESULT_FILE}" "40% memroy test" "pass"
	fi	
	
	#60%内存
	test3=`echo $memory*0.6 |bc`
	echo "60% memory："$test3
	ccc=`./memsize $test3`
	if [ $ccc -ne $test3 ]
	then
		#echo $test3"not equal to"$ccc"test rusualt is fail"
        fn_writeResultFile "${RESULT_FILE}" "60% memroy test" "fail"
	else
		#echo $test3"equal to"$ccc"test rusualt is OK"
        fn_writeResultFile "${RESULT_FILE}" "60% memroy test" "pass"
	fi	
	
	#80%的内存
	test4=`echo $memory*0.8 |bc`
	echo "80% memory："$test4
	ddd=`./memsize $test4`
	if [ $ddd -ne $test4]
	then
		#echo $test4"not equal to"$ddd"test rusualt is fail"
        fn_writeResultFile "${RESULT_FILE}" "80% memroy test" "fail"
	else
		#echo $test4"equal to"$ddd"test rusualt is OK"
        fn_writeResultFile "${RESULT_FILE}" "80% memroy test" "pass"
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
	[ "${test_result}" = "pass" ] || return 1
}

main $@
ret=$?
#LAVA平台上报结果接口，勿修改
lava-test-case "$test_name" --result ${test_result}
exit ${ret}