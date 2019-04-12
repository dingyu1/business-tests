#!/bin/bash

#*****************************************************************************************
# *用例名称：Version_005                                                        
# *用例功能：检查BIOS固件版本                                           
# *作者：fwx654472                                                                       
# *完成时间：2019-1-21                                                                   
# *前置条件：                                                                            
#   1、D06服务器一台                                                                   
# *测试步骤：                                                                               
#   1 进入操作系统
#   2 执行ipmitool -H 192.168.1.186 -I lanplus -U Administrator -P Admin@9000 mc info
# *测试结果：                                                                            
#   可以查询到BMC版本号为2.83                                                      
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
TMPCFG=${TMPDIR}/${test_name}.tmp_cfg
test_result="pass"

ibmc_ip_list=(172.16.11.5 172.16.11.6 172.16.11.11 172.16.11.10 192.168.1.154)
ibmc_user=root
ibmc_pwd=Huawei12#$


#预置条件
function init_env()
{
    #检查结果文件是否存在，创建结果文件：
    PRINT_LOG "INFO" "*************************start to run test case<${test_name}>**********************************"
    fn_checkResultFile ${RESULT_FILE}
    ethtool -h || fn_install_pkg ethtool 3
    ipmitool -h || fn_install_pkg ipmitool 3
}



#测试执行
function test_case()
{
    #测试步骤实现部分
    
    count=0
    len=${#ibmc_ip_list[@]}
    for ip in ${ibmc_ip_list[@]}
    do
        get_firminfo=`ipmitool -H $ip -I lanplus -U ${ibmc_user} -P ${ibmc_pwd} mc info`
        if [ $? -eq 0 ]
        then
            PRINT_LOG "INFO" "ip:$ip is this server ip address,get it"
            bios_version=`echo "{get_firminfo}" | grep "Firmware Revision" | awk -F":" '{print $2}'`
            PRINT_LOG "INFO" "server firm info,bios version is ${bios_version}"
            break
        else
            PRINT_LOG "INFO" "ip:$ip is not this server ip address"
        fi
        let count++
    done
    
    if [ ${count} = $len ]
    then
        fn_writeResultFile "${RESULT_FILE}" "get_firminfo" "fail"
    else
        fn_writeResultFile "${RESULT_FILE}" "get_firminfo" "pass"
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



