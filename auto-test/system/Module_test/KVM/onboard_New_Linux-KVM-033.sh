#!/bin/bash

#*****************************************************************************************
# *用例ID：New_Linux-KVM-033
# *用例名称：VF创建                                                    
# *用例功能：验证板载光口VF的创建和删除功能                                              
# *作者：LWX638710                                                                     
# *完成时间：2019-5-04    
#预置条件：
#1、确保网卡驱动为发布的最新驱动
#2、确保smmu+ras开关为on
#3、/sys/class/net/eth0/device/sriov_numvfs文件当前为0，且无已创建VF被占用
#4、HNS3驱动电口不支持SR-IOV
#测试步骤：
#1、进入系统，使用echo '3' > /sys/class/net/eth0/device/sriov_numvfs创建虚拟网卡，数量3。
#2、使用lspci | grep -i "Virtual Function“命令查询虚拟网卡是否创建成功，并获取设备bus info。
#预期结果：
#1、创建3个虚拟网卡能够成功
#2、lspci能查询到设备。                                              
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
				for n in {1..3}
				do
				nic_c_first=`lspci|grep Ethernet|wc -l`
                echo 0 > /sys/class/net/$i/device/sriov_numvfs #清除原始配置
                sleep 5            
				echo 3 > /sys/class/net/$i/device/sriov_numvfs
				sleep 2
				nic_c_cur=`lspci|grep Ethernet|wc -l`
				let nic_c_cur=$nic_c_cur-3
				if [ $nic_c_cur -eq $nic_c_first ]
				then
					PRINT_LOG "INFO" "The $n time $i create 3 vf success!"
					fn_writeResultFile "${RESULT_FILE}" "${i}_create_vf" "pass"
				else
					PRINT_LOG "FATAL" "The $n time $i create 3 vf fail!"
                                        fn_writeResultFile "${RESULT_FILE}" "${i}_create_vf" "fail"
				fi
				echo 0 > /sys/class/net/$i/device/sriov_numvfs
				sleep 2
				nic_c_cur=`lspci|grep Ethernet|wc -l`
                               
                                if [ $nic_c_cur -eq $nic_c_first ]
                                then
                                        PRINT_LOG "INFO" "The $n time $i delete 3 vf success!"
                                        fn_writeResultFile "${RESULT_FILE}" "${i}_delete_vf" "pass"
                                else
                                        PRINT_LOG "FATAL" "The $n time $i delete 3 vf fail!"
                                        fn_writeResultFile "${RESULT_FILE}" "${i}_delete_vf" "fail"
                                fi

				done
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


