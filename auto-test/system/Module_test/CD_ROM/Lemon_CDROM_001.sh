#!/bin/bash

#*****************************************************************************************
#用例名称：Lemon_CDROM_001
#用例功能：验证光驱可以正常挂载、拷贝、正常卸载
#作者：hwx653129
#完成时间：2019-1-30

#前置条件：
# 	1、已经安装系统，系统没有异常
# 	2、创建两个目录:
# 	mkdir –p /tmp/DIR0_CDROM /tmp/DIR1_CDROM
# 	3、已准备好USB物理光驱
# 	4、OS已配置SOL，连接系统串口

#测试步骤：
# 	1、将光驱插到server板上，放入光盘，光驱被正确识别，比如/dev/sr0
#	2、连接虚拟光驱挂载镜像，光驱被正确识别，比如/dev/sr1
# 	3、光驱测试：
# 	dd if=/dev/sr0 of=/tmp/cdrom.iso 
# 	mount –o loop /tmp/cdrom.iso /tmp/DIR0_CDROM
# 	mount /dev/sr0 /tmp/DIR1_CDROM 
# 	文件比较测试：diff –r /tmp/DIR0_CDROM /tmp/DIR1_CDROM
# 	umount /tmp/cdrom.iso
# 	umount /dev/sr0
# 	4、光驱测试
# 	dd if=/dev/sr1 of=/tmp/cdrom1.iso 
# 	mount –o loop /tmp/cdrom1.iso /tmp/DIR0_CDROM
# 	mount /dev/sr1 /tmp/DIR1_CDROM 
# 	文件比较测试：diff –r /tmp/DIR0_CDROM /tmp/DIR1_CDROM
# 	umount /tmp/cdrom1.iso
# 	umount /dev/sr1

#测试结果:
#	各种情况下，光驱都可以正常挂载、拷贝、正常卸载，对比副件与原件相同                                                        
#*****************************************************************************************

#加载公共函数,具体看环境对应的位置修改
. ../../../../utils/error_code.inc
. ../../../../utils/test_case_common.inc
. ../../../../utils/sys_info.sh
. ../../../../utils/sh-test-lib    
#. ./test_case_common.inc
#. ./error_code.inc  

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
# Name        : clean                                        #
# Description : 清除环境                                 #
# Parameters  : 无           #
# return value：无
#************************************************************#
function clean(){
	lsblk -o MOUNTPOINT | egrep  "${TMPDIR}/cdrom_1|${TMPDIR}/cdrom_2"
	if [ $? -eq 0 ];then
		umount ${TMPDIR}/cdrom_1 && umount ${TMPDIR}/cdrom_2
		if [ $? -eq 0 ]
		then
			PRINT_LOG "INFO" "umount file is normally."
			fn_writeResultFile "${RESULT_FILE}" "umount file" "pass"
		else
			PRINT_LOG "FATAL" "error umount file, please check it."
			fn_writeResultFile "${RESULT_FILE}" "umount file" "fail"
		fi
	fi

	if [  -d ${TMPDIR}/cdrom_1 ] || [ -d ${TMPDIR}/cdrom_2 ]; then
		rm -rf ${TMPDIR}/cdrom_1 && rm -rf ${TMPDIR}/cdrom_2
	fi
	
	if [  -f  ${TMPDIR}/cdrom_1.iso ] || [ -f ${TMPDIR}/cdrom_2.iso ]; then
		rm -rf ${TMPDIR}/cdrom_1.iso && rm -rf ${TMPDIR}/cdrom_2.iso
	fi
}
#************************************************************#
# Name        : prepare                                        #
# Description : 准备环境                                 #
# Parameters  : 无           #
# return value：无
#************************************************************#
function prepare(){
	if [  ! -d ${TMPDIR}/cdrom_1 ] || [ ! -d ${TMPDIR}/cdrom_2 ]; then
		mkdir -p ${TMPDIR}/cdrom_1 && mkdir -p ${TMPDIR}/cdrom_2
		if [ $? -eq 0 ]
		then
			PRINT_LOG "INFO" "create a directory is normally."
			fn_writeResultFile "${RESULT_FILE}" "create dir" "pass"
		else
			PRINT_LOG "FATAL" "create a directory fail, please check it."
			fn_writeResultFile "${RESULT_FILE}" "create dir" "fail"
			return 1
		fi
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
	wget -h || fn_install_pkg "wget" 10	
	clean
	prepare
    #自定义测试预置条件检查实现部分：比如工具安装，检查多机互联情况，执行用户身份 
      #需要安装工具，使用公共函数install_deps，用法：install_deps "${pkgs}"
      #需要日志打印，使用公共函数PRINT_LOG，用法：PRINT_LOG "INFO|WARN|FATAL" "xxx"
}

#测试执行
function test_case()
{
	wget --tries=3 -c http://172.19.20.15:8083/open-estuary/old_iso/centos/Centos7-5-1804/auto-install.iso -O centos.iso
	mv centos.iso ${TMPDIR}/cdrom_1.iso
	
	#sshpass -p 123456 scp -o StrictHostKeyChecking=no minshuai@192.168.1.107:/var/www/html/rp1612/v5.2-rc4/CentOS/centos-everything-v5.2-rc4.iso ${TMPDIR}
	#mv ${TMPDIR}/centos-everything-v5.2-rc4.iso ${TMPDIR}/cdrom_1.iso
	
	#光驱复制
	dd if="${TMPDIR}/cdrom_1.iso" of="${TMPDIR}/cdrom_2.iso" 
	if [ $? -eq 0 ]
	then
		PRINT_LOG "INFO" "CD-ROM replication normal."
		fn_writeResultFile "${RESULT_FILE}" "copy_file" "pass"
	else
		PRINT_LOG "FATAL" "CD-ROM replication error, please check it."
		fn_writeResultFile "${RESULT_FILE}" "copy_file" "fail"
	fi		
	
	#挂载光驱
	mount -o loop ${TMPDIR}/cdrom_1.iso ${TMPDIR}/cdrom_1
	if [ $? -eq 0 ]
	then
		PRINT_LOG "INFO" "mounting file is normally."
		fn_writeResultFile "${RESULT_FILE}" "mount_file" "pass"
	else
		PRINT_LOG "FATAL" "error mounting file, please check it."
		fn_writeResultFile "${RESULT_FILE}" "mount_file" "fail"
		lsblk
		ls ${TMPDIR}
	fi
	
	#将复制光驱文件当作硬盘分区挂载
	mount -o loop ${TMPDIR}/cdrom_2.iso ${TMPDIR}/cdrom_2
	if [ $? -eq 0 ]
	then
		PRINT_LOG "INFO" "mounting copy file is normally."
		fn_writeResultFile "${RESULT_FILE}" "mount_copy_file" "pass"
	else
		PRINT_LOG "FATAL" "error mounting copy file, please check it."
		fn_writeResultFile "${RESULT_FILE}" "mount_copy_file" "fail" 
	fi
	
	
	#比较两个文件之间有没有差异
	diff -r ${TMPDIR}/cdrom_1 ${TMPDIR}/cdrom_2
	if [ $? -eq 0 ]
	then
		PRINT_LOG "INFO" "This two files are the same."
		fn_writeResultFile "${RESULT_FILE}" "differ_file" "pass"
	else
		PRINT_LOG "FATAL" "This two files do not match, please check it."
		fn_writeResultFile "${RESULT_FILE}" "differ_file" "fail"
	fi	
		
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
	clean
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
