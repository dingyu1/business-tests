#!/bin/bash

#*****************************************************************************************
# *用例ID：Function_001
# *用例名称：李仁性                                              
# *用例功能：板载端口检查                                    
# *作者：LWX638710                                                                     
# *完成时间：2019-5-04    
#预置条件：
#1、安装ubuntu18.04.1操作系统的D06服务器1台
#2、单板卡从片riser卡PCIe上槽位上插Mellanox 25G网卡
#测试步骤：
#1 进入操作系统
#2 使用ip a命令检查是否能观察到板载所有网口
#3 使用ethtool命令查询每个网口的信息
#预期结果：
#1 能检查到板载的两个光口、两个电口和1个100G网口                                 
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
	command -v ethtool
	if [ $? -ne 0 ]
	then
		fn_install_pkg ethtool 3
	fi

}
#测试步骤函数
function test_case()
{
        niclist=`ls -l /sys/class/net|grep -v virtual|awk -F"/" '{print $NF}'|grep -v ^total`
        firbe_nic_num=0
        tp_nic_num=0
	for i in $niclist
        do
                driver=`ethtool -i $i|grep "driver: "|awk '{print $2}'`
                if [ "$driver" == "hns3" ] || [ "$driver" == "hns" ]
                then
                        nic_type=`ethtool $i|grep "Supported ports:"|awk '{print $4}'`
                        if [ "$nic_type" == "FIBRE" ];then
                                ethtool $i|grep -A2  "Supported link modes:"|grep "10000base"
								if [ $? -eq 0 ];then
                                let firbe_nic_num=$firbe_nic_num+1
                                PRINT_LOG "INFO" "check FIBRE $i success,the current onboard nic is 10G,the current onboard nic num is $firbe_nic_num "
                                fn_writeResultFile "${RESULT_FILE}" "${i}_check" "pass"
								fi
						elif [ "$nic_type" == "TP" ];then
                                ethtool $i|grep -A2 "Supported link modes:"|grep "1000baseT"
                                if [ $? -eq 0 ];then
								let tp_nic_num=$tp_nic_num+1
                                PRINT_LOG "INFO" "check TP $i success,the current onboard nic num is $tp_nic_num "
                                fn_writeResultFile "${RESULT_FILE}" "${i}_check" "pass"
								else
								PRINT_LOG "FATAL" "check TP $i fail,the current onboard nic num is $tp_nic_num "
								fn_writeResultFile "${RESULT_FILE}" "${i}_check" "fail"
								fi
                        else
                                PRINT_LOG "FATAL" "check the nic type fail,please check manually"
                                fn_writeResultFile "${RESULT_FILE}" "${i}_check" "fail"
                        fi
				fi
             
        done
	                if [ $tp_nic_num -eq 2 ];then
                         PRINT_LOG "INFO" "The onboard NIC_TP num is $tp_nic_num, is equal to 2 "
                         fn_writeResultFile "${RESULT_FILE}" "onboard_tp_check_num" "pass"
                    else
                         PRINT_LOG "FATAL" "The onboard NIC_TP num is $tp_nic_num, is not equal to 2 "
                         fn_writeResultFile "${RESULT_FILE}" "onboard_tp_check_num" "fail"
                    fi
                    if [ $firbe_nic_num -eq 2 ];then
                         PRINT_LOG "INFO" "The onboard NIC_firbe num is $firbe_nic_num, is equal to 2 "
                         fn_writeResultFile "${RESULT_FILE}" "onboard_check_num" "pass"
                    else
                         PRINT_LOG "FATAL" "The onboard NIC_firbe num is $firbe_nic_num, is not equal to 2 "
                         fn_writeResultFile "${RESULT_FILE}" "onboard_check_num" "fail"
                    fi

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


