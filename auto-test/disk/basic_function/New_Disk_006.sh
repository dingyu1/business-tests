#!/bin/bash

#*****************************************************************************************
# *用例名称：New_Disk_006                                                         
# *用例功能：硬盘读写裸盘测试-SAS HDD盘                                         
# *作者：fwx654472                                                                       
# *完成时间：2019-1-21                                                                   
# *前置条件：                                                                            
#	硬盘直通状态，硬盘SAS HDD满配 
# *测试步骤：                                                                               
#	1、OS正常运行的情况下，lsblk查看各个硬盘是否在位，有结果A）
#	2、通过BMC查看硬盘是否在位，有结果B）
#	3、使用lspci -s 74:02.0 -vvv 查看中断类型，MSI: Enable- 表示未使能，MSI-X: Enable+ 表示使能；有结果C）
#	4、cat /proc/interrupts查看MSI中断数据；
#	5、使用fio分别对非系统分区和其他所有所有盘下发bs=4k，iodepth=128读IO，有结果D）
#	6、再次查看中断数据cat /proc/interrupts，对比步骤4和6前后数据是否一致，有结果E）
# *测试结果：                                                                            
#	A)显示所有硬盘信息，大小无误
#	B)显示所有硬盘信息，大小无误
#	C)正确显示pci信息
#	D)OS正常运行，dmesg中无报错，硬盘可以正常读写
#	E)前后一致                                                 
#*****************************************************************************************

#加载公共函数
. ../../../utils/error_code.inc
. ../../../utils/test_case_common.inc
. ../../../utils/sys_info.sh
. ../../../utils/sh-test-lib     
#. ./utils/error_code.inc
#. ./test_case_common.inc

#获取脚本名称作为测试用例名称
test_name=$(basename $0 | sed -e 's/\.sh//')
#创建log目录
TMPDIR=./logs/temp
mkdir -p ${TMPDIR}
#存放脚本处理中间状态/值等
TMPFILE=${TMPDIR}/${test_name}.tmp
#存放每个测试步骤的执行结果
RESULT_FILE=${TMPDIR}/${test_name}.result
TMPCFG=${TMPDIR}/${test_name}.tmp_cfg
test_result="pass"


cat << EOF > ${TMPCFG}
disk_nums=12
disk_type=sas
cpi_sequence=74:02.0
case_name=New_Disk_006
EOF

#预置条件
function init_env()
{
    #检查结果文件是否存在，创建结果文件：
	PRINT_LOG "INFO" "*************************start to run test case<${test_name}>**********************************"
    fn_checkResultFile ${RESULT_FILE}
    ethtool -h || fn_install_pkg ethtool 3
}



#测试执行
function test_case()
{
    #测试步骤实现部分
	cpi_sequence=`fn_get_value ${TMPCFG} cpi_sequence`
	lspci -s ${cpi_sequence} -vvv | grep "MSI.*Enable"
	if [ $? -eq 0 ]
	then
		PRINT_LOG "INFO" "Check out MSI Enable lab."
		fn_writeResultFile "${RESULT_FILE}" "MSI" "pass"
	else
		PRINT_LOG "FATAL" "Can not check MSI Enable lab,check it fail"
		fn_writeResultFile "${RESULT_FILE}" "MSI" "fail"
	fi
	
	blk_list=`lsblk -d| grep -v MOUNTPOINT| awk '{print $1}'`
	PRINT_LOG "INFO" "blk list is $blk_list"
	
	
	declare -a bare_disk_list
	j=0
	for i in $blk_list
	do
		lsblk -a | egrep -v "MOUNTPOINT" | grep "/" | grep $i
		if [ $? -ne 0 ]
		then
			echo "$i is pure blk"
			bare_disk_list[j]=$i
			let j++
		else
			echo "$i is used for system parttion "
		fi
	
	done

	
	
	for blk in ${bare_disk_list[@]}
	do
		exec_before=`cat /proc/interrupts |awk '{print $1 $NF}'|grep -i cq | wc -l`
		cat /proc/interrupts |awk '{print $1 $NF}'|grep -i cq >$TMPFILE
		fio -filename=/dev/$blk -ioengine=sync -direct=1 -iodepth=128 -rw=write -bs=4k -size=1G -numjobs=8 -runtime=10 -group_reporting -name=fio_test
		exec_after=`cat /proc/interrupts |awk '{print $1 $NF}'|grep -i cq | wc -l`
		if [ ${exec_before} = ${exec_after} ]
		then
			PRINT_LOG "INFO" "test is interrupt  number isistent is ok "
			interrupt_list=` cat /proc/interrupts |awk '{print $1 $NF}'|grep -i cq| awk -F":" '{print $1}'`
			for interrupt_number in ${interrupt_list}
			do
				cat $TMPFILE | grep "${interrupt_number}"
				if [ $? -eq 0 ]
				then
					PRINT_LOG "INFO" "test disk ${interrupt_number} is OK ,test is ok"
					fn_writeResultFile "${RESULT_FILE}" "interrup_num" "pass"
				else
					PRINT_LOG "INFO" "test disk  ${interrupt_number} is new ,test is fail"
					fn_writeResultFile "${RESULT_FILE}" "${interrupt_number}" "fail"
				fi
				
			done
		else
			PRINT_LOG "FATAL" "test is interrupt  number is inconsistent ,test is fail "
			fn_writeResultFile "${RESULT_FILE}" "interrup_num" "fail"
		fi
	
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
    PRINT_LOG "INFO" "*************************end of running test case<${test_name}>**********************************"
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



