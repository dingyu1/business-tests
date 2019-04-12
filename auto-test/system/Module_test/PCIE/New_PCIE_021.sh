#!/bin/bash -x

#*****************************************************************************************
# *用例名称：New_PCIE_021                                                       
# *用例功能: PCIE设备重置测试-SAS                                            
# *作者：dwx572468                                                                       
# *完成时间：2019-3-29                                                                   
# *前置条件：     
#   1.使用ES3000硬盘安装操作系统，作为系统分区。
#   2.打开系统日志级别
#   echo 7 > /proc/sys/kernel/printk
#   3.满载硬盘，且创建了分区                                                                       
# *测试步骤：      
#   1、lspci 查询SAS slot
#   2、进入SAS slot目录/sys/bus/pci/devices/0000\:xx\:xx.x
#   3、执行echo 1 > reset，有结果A
#   4、重置完成后，使用lspci查看slot是否重新挂载，使用lsblk确认硬盘是否全部挂载，对所有硬盘使用命令fio -filename=/dev/sdx -direct=1 -iodepth 1 -thread -rw=rw -ioengine=psync -bs=4k -size=10G -numjobs=1 -runtime=10 -group_reporting -na    me=rw_10G_4k进行读写测试，有结果B
#   5、遍历所有SAS slot 
# *测试结果：       
#  所有测试均pass                                                                     
#*****************************************************************************************

#加载公共函数
. ../../../../utils/test_case_common.inc
. ../../../../utils/error_code.inc
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

#自定义变量区域（可选）
#var_name1="xxxx"
#var_name2="xxxx"

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
	# install_deps sshpass
	for pkg in pciutils fio
	do
		if [ "$pkg" = "pciutils" ];then
			which lspci || fn_install_pkg $pkg 1
		else
			which $pkg || fn_install_pkg $pkg 1
		fi
		if [ $? != 0 ];then
                	PRINT_LOG "FATAL" "download $pkg"
                	exit 1
        	fi
	done
	echo 7 > /proc/sys/kernel/printk
}

#测试执行
function test_case()
{
	#测试步骤实现部分
	#如果执行的命令分系统，请使用distro变量来区分OS类型
	#需要日志打印，使用公共函数PRINT_LOG，用法：PRINT_LOG "INFO|WARN|FATAL" "xxx"
	  #记录每项测试结果，使用公共函数fn_writeResultFile，用法：fn_writeResultFile "${RESULT_FILE}" "test_item_name" "pass|fail"
	disknum=`lsblk|grep disk|wc -l`
	for SAS_slot in `lspci |grep SAS|awk '{print $1}'`
	do
		dmesg -c > /dev/null
		cd /sys/bus/pci/devices/*${SAS_slot}*
		echo 1 > reset
		cd -
		reset_msg=`dmesg|egrep -i "error|fail|warn"`
		if [ "$reset_msg" = "" ];then
			fn_writeResultFile "${RESULT_FILE}" "check_SAS_reset_msg" "pass"
		else
			fn_writeResultFile "${RESULT_FILE}" "check_SAS_reset_msg" "fail"
		fi
		check_SAS_slot=`lspci |grep ^${SAS_slot}`
		if [ "$check_SAS_slot" = "" ];then
			fn_writeResultFile "${RESULT_FILE}" "check_SAS_slot" "fail"
	 	else
			fn_writeResultFile "${RESULT_FILE}" "check_SAS_slot" "pass"
		fi
		check_disk=`lsblk|grep disk|wc -l`
		if [ $disknum -eq $check_disk ];then
			fn_writeResultFile "${RESULT_FILE}" "check_disk_num" "pass"
		else
			fn_writeResultFile "${RESULT_FILE}" "check_disk_num" "fail"
		fi
		for disk_name in `lsblk|grep disk|grep -v sda|awk '{print $1}'`
		do
			fio -filename=/dev/$disk_name -direct=1 -iodepth 1 -thread -rw=rw -ioengine=psync -bs=4k -size=10G -numjobs=1 -runtime=10 -group_reporting -name=rw_10G_4k > ${TMPDIR}/${disk_name}_rw.log
			if [ $? == 0 ];then
				fn_writeResultFile "${RESULT_FILE}" "${disk_name}_rw" "pass"
			else
				fn_writeResultFile "${RESULT_FILE}" "${disk_name}_rw" "fail"
			fi
		done
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
	rm -f ${TMPDIR}/*sd*_rw.log	
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
