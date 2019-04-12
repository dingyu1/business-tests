#!/bin/bash -x

#*****************************************************************************************
# *用例名称：New_System_017                                                       
# *用例功能: LTP测试                                            
# *作者：dwx572468                                                                       
# *完成时间：2019-3-26                                                                   
# *前置条件：                                                                            
#   1、预装linux系统  
#   2、满配内存、USB设备（USB键盘鼠标、U盘）
#   3、已编译安装LTP测试工具                                                               
# *测试步骤：       
#   1. 首先执行 runltp –c 2 –p –o output1.txt –l log1.txt 执行默认的测试项：
#    a. 执行的是runtest目录下下面文件中测试用例：
#       syscalls ： 系统调用相关的测试
#       fs/fsx ：文件系统压力测试
#       dio ：direct I/O测试
#       mm ：内存管理测试
#       ipc ：进程间通讯测试
#       sched ：调度压力测试
#       math ：数学运算CPU测试
#       nptl ：nptl测试（一种线程库测试）
#       pty ：终端类型测试
#       containers ：
#          controllers ：内核资源管理测试，目前测试CPU和内存
#       filecaps ：测试文件容量（由于需要的命令行没有安装，一般执行错误）
#     输出结果 output1.txt是测试中的详细输出位于ltp-xxxx/output目录下；log1.txt位于ltp-xxxx/results目录下
#   2. 使用 runltp –c 2 –p –o output1.txt –l log1.txt –f filename 依次执行下面的命令文件：
#      ballista：对系统调用进行故障注入测试 #  
#      commands：常用命令行测试
#      io：测试光驱和软驱
#      pipes：管道测试
#      modules：模块操作测试
#      quickhit：系统调用的一个字集
#      stres.part1/part2/part3 系统压力测试
#      hugetlb：内存相关（测试不过）
#      hyperthreading：超线程（测试错误）
#      ltp-aio-stress.part1/ltp-aio-stress.part2 ：测试异步IO（代码错误）                                                                
# *测试结果：       
#  所有测试均pass                                                                     
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
# issues=(syscalls fs fsx dio mm ipc sched math nptl pty containers controllers filecaps commands io quickhit stress.part1 stress.part2 stress.part3 hugetlb hyperthreading ltp-aio-stress.part1 ltp-aio-stress.part2)
issues=(quickhit hyperthreading)
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
	# install_deps unzip make gcc automake
	for pkg in unzip make gcc automake wget
        do
                which $pkg || fn_install_pkg $pkg 1
                if [ $? != 0 ];then
                        PRINT_LOG "FATAL" "download $pkg"
                        exit 1
                fi
        done
}

#测试执行
function test_case()
{
	#测试步骤实现部分
	#如果执行的命令分系统，请使用distro变量来区分OS类型
	#需要日志打印，使用公共函数PRINT_LOG，用法：PRINT_LOG "INFO|WARN|FATAL" "xxx"
	  #记录每项测试结果，使用公共函数fn_writeResultFile，用法：fn_writeResultFile "${RESULT_FILE}" "test_item_name" "pass|fail"
	cd /home/ && wget -c -q http://172.19.20.15:8083/perform_depends/test_dependent/ltp-master.zip && unzip -q ltp-master.zip
	cd -
	cd /home/ltp-master && ./build.sh
	cd -
	for i in $(seq 0 1)
	do
		$HOME/ltp-install/runltp -c 2 -p -o /home/output_${issues[$i]}.txt -l /home/log_${issues[$i]}.txt -f ${issues[$i]}
		fail_num=`grep "Total Failures" /home/log_${issues[$i]}.txt |awk '{print $3}'`
		if [ $fail_num -eq 0  ];then
			fn_writeResultFile "${RESULT_FILE}" "${issues[$i]}" "pass"
		else
			fn_writeResultFile "${RESULT_FILE}" "${issues[$i]}" "fail"
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
	rm -rf /home/ltp-master $HOME/ltp-install /home/ltp-master.zip
	rm -f /home/log_*.txt /home/output_*.txt
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
