#!/bin/bash

#*****************************************************************************************
# *用例ID：New_Linux-KVM-032
# *用例名称：网卡直通支持查询                                                       
# *用例功能：查询板载网卡是否支持直通                                                
# *作者：LWX638710                                                                     
# *完成时间：2019-5-04    
#预置条件：
#1、确保网卡驱动为发布的最新驱动
#2、确保smmu+ras开关为on
#3、HNS3驱动电口不支持SR-IOV
#测试步骤：
#1、进入系统，执行lspci -s “bus-info” -vvv | grep -i "SR-IOV" 查询网卡是否支持直通模式
#预期结果：
#网卡支持直通模式                                              
#*****************************************************************************************

#加载公共函数
. ../../../../utils/error_code.inc
. ../../../../utils/test_case_common.inc
. ../../../../utils/sys_info.sh
. ../../../../utils/sh-test-lib     
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
    fn_checkResultFile ${RESULT_FILE}
	command -v lspci
	if [ $? -ne 0 ]
	then
		fn_install_pkg pci* 3
	fi
	command -v ethtool
	if [ $? -ne 0 ]
	then
		fn_install_pkg ethtool 3
	fi

	
}
function test_case()
{
	niclist=`ls -l /sys/class/net|grep -v virtual|awk -F"/" '{print $NF}'|grep -v ^total`
	for i in $niclist
	do
		driver=`ethtool -i $i|grep "driver: "|awk '{print $2}'`
		if [ "$driver" == "hns3" ] || [ "$driver" == "hns" ]
		then
			nic_type=`ethtool $i|grep "Supported ports:"|awk '{print $4}'`
			if [ "$nic_type" == "FIBRE" ]
			then
				nic_bus=`ethtool -i $i|grep "bus-info"|awk '{print $2}'`
				VF=`lspci -vvv -s $nic_bus|grep "Initial VFs:"|awk '{print $3}'|awk -F"," '{print $1}'`
				if [ $VF -gt 0 ]
				then
                                     	PRINT_LOG "INFO" "hns3 fibre support vf"
                                        fn_writeResultFile "${RESULT_FILE}" "${i}_check_SR-IOV" "pass"
                                else
                                        PRINT_LOG "FATAL" "hns3 fibre not support vf"
                                        fn_writeResultFile "${RESULT_FILE}" "${i}_check_SR-IOV" "fail"
				fi
			fi
		fi
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


