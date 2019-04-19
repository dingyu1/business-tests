#!/bin/bash

#*****************************************************************************************
# *用例名称：Check_010                                                         
# *用例功能：enp125s0f0网口类型检查                                             
# *作者：fwx654472                                                                       
# *完成时间：2019-1-21                                                                   
# *前置条件：                                                                            
#   1、D06服务器一台                                                                   
# *测试步骤：                                                                               
#   1 进入操作系统
#   2 获取前4个板载网卡
#   3 检查是前两个网口类型是否为FIBRE ，后两个为port 为M_II
# *测试结果：                                                                            
#   查询到enp125s0f0为FIBRE类型                                                        
#*****************************************************************************************

#加载公共函数
. ../../../../utils/error_code.inc
. ../../../../utils/test_case_common.inc
. ../../../../utils/sys_info.sh
. ../../../../utils/sh-test-lib     
#. ./error_code.inc
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
    fn_checkResultFile ${RESULT_FILE}
    ethtool -h || fn_install_pkg ethtool 3
}

function fn_get_on_board_network_card()
{

    declare -a physical_network_card

    network_interface_list=`ip a | grep ^[[:digit:]] | egrep -v "lo|vi" | awk -F":" '{print $2}'`
    j=0
    for i in ${network_interface_list}
    do
        ethtool -i  ${i} |  grep -i "driver" | grep hns
        if [ $? -eq 0 ]
        then
            physical_network_card[j]=$i
            let j++
            echo "physical_network_card[$j]=$i"
        else
            echo "$i is not on board network card "
        fi
    done
    #eval $1='${physical_network_card[@]}'
    PRINT_LOG "INFO" "physical_network_card=${physical_network_card[@]}"

    #on_board_list=(enp189s0f0 enp125s0f0 enp125s0f2 enp125s0f1 enp125s0f3  enp189s0f1)
    on_board_list=${physical_network_card[@]}
    len=${#on_board_list[@]}
    #echo on_board_list=${on_board_list[@]}
    for((i=0; i<$len; i++)){
        for((j=i+1; j<$len; j++)){

            if [ ${on_board_list[i]} \> ${on_board_list[j]} ]
            then
            temp=${on_board_list[i]}
            on_board_list[i]=${on_board_list[j]}
            on_board_list[j]=$temp
            fi

        }
    }
    eval $1='${on_board_list[@]}'
}


#测试执行
function test_case()
{
    #测试步骤实现部分
    
    fn_get_on_board_network_card on_board_network_interface_list
    
    local count_tp=0
    local count_fb=0
    local count=0
    for network_card in ${on_board_network_interface_list}
    do
        ethtool ${network_card} >${TMPFILE} 2>&1
        PRINT_FILE_TO_LOG "${TMPFILE}"
        cat ${TMPFILE} | grep -i "port" | grep -w "TP"
        if [ $? -eq 0 ]
        then
            let count_tp++
            PRINT_LOG "INFO" "count num of TP type is ${count_tp}"
            if [ ${count_tp} = 1 ]
            then
                PRINT_LOG "INFO" "Get front 4 network_card  have ${count_tp} is  TP "
                fn_writeResultFile "${RESULT_FILE}" "count_fb_${count_tp}" "pass"
                break 
            fi
        
        fi 
        
    done
   
    if [ ${count_tp} = 0 ]
    then
        PRINT_LOG "INFO" "can not get network card type is  TP "
        fn_writeResultFile "${RESULT_FILE}" "count_tp_${count_tp}" "fail"
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
    PRINT_LOG "INFO" "end of running test case<${test_name}>"
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
