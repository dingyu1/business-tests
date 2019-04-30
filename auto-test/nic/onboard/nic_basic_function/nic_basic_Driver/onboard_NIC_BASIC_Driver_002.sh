#!/bin/bash

#*****************************************************************************************
# *用例名称：NIC_BASIC_Driver_002
# *用例功能：网口驱动版本信息查询
# *作者：lwx638710
# *完成时间：2019-4-28
# *前置条件
#  预安装Linux系统
# *测试步骤：
#  查询网卡和Firmware信息
# *测试结果：
#  网口查询出的驱动版本和Firmware信息相同
#*****************************************************************************************

#加载公共函数
. ../../../../../utils/error_code.inc
. ../../../../../utils/test_case_common.inc
. ../../../../../utils/sys_info.sh
. ../../../../../utils/sh-test-lib
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

#预置条件
function init_env()
{
    #检查结果文件是否存在，创建结果文件：
    PRINT_LOG "INFO" "*************************start to run test case<${test_name}>**********************************"
     fn_install_pkg "ethtool" 2
     lspci > /dev/null
     if [ $? -ne 0 ]
     then
     fn_install_pkg pci* 3
     fi
     fn_checkResultFile ${RESULT_FILE}
}
function test_case()
{
   #fn_install_pkg pci* 3
   #检查本机有多少网卡，并且取出网卡和网卡对应的bus号
	nic_count=`lspci -D|grep Ethernet|awk '{print $1}'|awk -F"." '{print $1}'|sort -u |wc -l`
	if [ $? -eq 0 ]
	then
		bus_list=`lspci -D|grep Ethernet|awk '{print $1}'|awk -F"." '{print $1}'|sort -u`
		for i in $bus_list
		do
		PRINT_LOG "INFO" "The count of Ethernet device is $nic_count, this dev businfo is $i"
		#fn_writeResultFile "${RESULT_FILE}" "The count of Ethernet device" "$nic_count"
		done
	else
		PRINT_LOG "FATAL" "nic_count excecute is fail.Please check the lspci command"
	fi
	bus_nicname=`ls -l /sys/class/net/|grep -i "/devices/pci"|awk -F"/" '{print $(NF-2),$NF}'`
	if [ $? -eq 0 ]
	then
		PRINT_LOG "INFO" "list businfo and nicname from /sys/class/net is pass"
	else
		PRINT_LOG "FATAL" "list businfo and nicname from /sys/class/net is fail."
	fi


	for i in $bus_list
		do
		first_nic=`ls -l /sys/class/net/|grep -i "/devices/pci"|awk -F"/" '{print $(NF-2),$NF}'|grep $i.0|awk '{print $2}'` #查询对应网卡第一个网口的名称
		#eval echo "$first_nic_$i is $first_nic"
		first_fw=`ethtool -i $first_nic|grep "firmware-version:"|awk -F":" '{print $2}'` #查询第一个网口的固件版本
		first_driver=`ethtool -i $first_nic|grep "driver:"|awk -F":" '{print $2}'`
		if [ ! -n $first_fw ]
		then
			PRINT_LOG "FATAL" "The fw of $first_nic is null,please check it"
			fn_writeResultFile "${RESULT_FILE}" "The-fw-of-$first_nic-check is" "fail"
		fi
		if [ ! -n $first_driver ]
		then
			PRINT_LOG "FATAL" "The driver of $first_nic is null,please check it"
			fn_writeResultFile "${RESULT_FILE}" "The-driver-of-$first_nic-check-is" "fail"
		fi

		#eval echo "$first_fw_$i is $first_fw`
		niclist=`ls -l /sys/class/net/|grep -i "/devices/pci"|awk -F"/" '{print $(NF-2),$NF}'|grep ${i}|awk '{print $2}'`  #查询同一个网卡的所有网口名称
		#遍历所有网口，检查是否与第一个网口的固件版本一致
		for m in $niclist
		do
		#对网口固件查询100次
		for n in {1..100}
			do
				fw_cur=`ethtool -i $m|grep "firmware-version:"|awk -F":" '{print $2}'`
				driver_cur=`ethtool -i $m|grep "driver:"|awk -F":" '{print $2}'`
				if [ "$fw_cur" == "$first_fw" -a "${driver_cur}" == "${first_driver}" ]
				then
					#eval echo "$n check fw $m pass"
					PRINT_LOG "INFO" "The $n times check of $m firmware is equal to $first_fw and driver is equal to $first_driver"
                                        #fn_writeResultFile "${RESULT_FILE}" "The-$n-times-check-of-$m-firmware-and-driver" "pass"
					if [ $n -eq 100 ]
					then
						PRINT_LOG "INFO" "100 times check of $m firmware is equal to $first_fw and driver is equal to $driver_cur"
						fn_writeResultFile "${RESULT_FILE}" "100-times-check-of-$m-firmware-and-driver" "pass"
					fi
				else
					#eval echo "$n check fw $m fail"
                    PRINT_LOG "FATAL" "The $n times check of $m firmware is $fw_cur, driver is $driver_cur, not equal to $first_fw and $first_driver"
                                        fn_writeResultFile "${RESULT_FILE}" "The-$n-times-check-of-$m-firmware-and-driver" "fail"
             fi
      done
   done
done
#检查结果文件，根据测试选项结果，有一项为fail则修改test_result值为fail，
    	check_result ${RESULT_FILE}

}
	#从bus_list获取其中一个bus0，从bus_nicname过滤bus0对应的网卡名。并且对所有网卡名查询固件信息

#恢复环
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


