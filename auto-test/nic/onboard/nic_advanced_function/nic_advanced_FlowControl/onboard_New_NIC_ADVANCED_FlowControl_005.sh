#!/bin/bash

#*****************************************************************************************
#用例名称：New_NIC_ADVANCED_FlowControl_005
#用例功能：电口流控使能自协商设置与查询
#作者：qwx655884
#完成时间：
#前置条件
#  1.单板启动正常
#  2.所有电口各模块加载正常
#测试步骤
#  1.网口初始化后，查询流控信息：ethtool -a ethx，设置本端autoneg关闭：ethtool -A ethx autoneg off，预期结果A）
#  2.（此步板载需要执行）设置本端autoneg关闭：ethtool -s ethx autoneg off，预期结果B）
#  3.查询流控信息：ethtool -a ethx，预期结果C）
#  4.设置本端autoneg打开：ethtool -A ethx autoneg on，预期结果D）
#  5.（此步板载需要执行）设置本端autoneg关闭：ethtool -s ethx autoneg on，预期结果E）
#  6.查询流控信息：ethtool -a ethx，预期结果F）
#测试结果
#  A)提示命令不支持，且提示使用ethtool -s 命令去设置
#  B)设置成功
#  C)Autonegotiate:  off
#  D)提示命令不支持，且提示使用ethtool -s 命令去设置
#  E)设置成功
#  F)Autonegotiate:  on
#*****************************************************************************************

#加载公共函数,具体看环境对应的位置修改
. ../../../../../utils/error_code.inc
. ../../../../../utils/test_case_common.inc
. ../../../../../utils/sys_info.sh
. ../../../../../utils/sh-test-lib
. ../../../../../utils/env_parameter.inc

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

#自定义变量区域（可选）
#var_name1="xxxx"
#var_name2="xxxx"
test_result="pass"

#************************************************************#
# Name        : distinguish_card                               #
# Description : 区分板载和标卡                               #
# Parameters  : 无
# return value：onboard_fibre_card[]   onboard_tp_card[]  standard_card[]              #
#************************************************************#
function distinguish_card(){
    #查找所有物理网卡
   # find_physical_card
   fn_get_physical_network_card total_network_cards
   total_network_cards=(`echo ${total_network_cards[@]}`)
   
   for ((i=0;i<${#total_network_cards[@]};i++))
    do
        driver=`ethtool -i ${total_network_cards[i]} | grep driver | awk '{print $2}'`
        if [ "$driver" == "hns" -o "$driver" == "hns3" ];then
			port=`ethtool ${total_network_cards[i]} | grep "Port:"| awk '{print $2}'`
			if [ "$port" == "FIBRE" ];then
				onboard_fibre_card[i]=${total_network_cards[i]}
				onboard_fibre_card=(`echo ${onboard_fibre_card[@]}`)
			elif [ "$port" == "MII" ];then
				onboard_tp_card[i]=${total_network_cards[i]}
				onboard_tp_card=(`echo ${onboard_tp_card[@]}`)
			fi
        else
            standard_card[i]=${total_network_cards[i]}
            standard_card=(`echo ${standard_card[@]}`)
        fi
    done
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
	distinguish_card
    dmesg --clear

}

#测试执行
function test_case()
{      #抓取自协商状态
    for net in ${onboard_tp_card[@]}
    do
        ethtool -a $net
		if [ $? -eq 0 ];then
		    PRINT_LOG "INFO" "execution success"
            fn_writeResultFile "${RESULT_FILE}" "search" "pass"
        else
            PRINT_LOG "FATAL" "execution fail,please chick it."
            fn_writeResultFile "${RESULT_FILE}" "search" "fail"
		fi
       #ethtool -A 关闭autoneg
         ethtool -A $net autoneg off
         if [ $? -ne 0 ];then
            x=`dmesg|grep "To change autoneg please use: ethtool -s <dev> autoneg <on|off>"`
			  if [ $? -eq 0 ];then
		    PRINT_LOG "INFO" "$x"
            fn_writeResultFile "${RESULT_FILE}" "${net} autoneg status" "pass"
            dmesg --clear
         else
            PRINT_LOG "FATAL" "result fail."
            fn_writeResultFile "${RESULT_FILE}" "${net} autoneg status" "fail"
              fi
         fi
        #ethtool -s 关闭autoneg
            ethtool -s $net autoneg off
                #抓取自协商状态
                ethtool -a $net
            statu2=`ethtool -a $net|grep Autonegotiate|awk '{print $2}'`
            if [ "$statu2" = "off" ];then
                PRINT_LOG "INFO" "set success"
                fn_writeResultFile "${RESULT_FILE}" "${net} set autoneg" "pass"
            else
                PRINT_LOG "FATAL" "set fail,please chick it."
                fn_writeResultFile "${RESULT_FILE}" "${net} set autoneg" "fail"
                        ethtool -a $net
            fi
        #ethtool -A 开启autoneg
            ethtool -A $net autoneg on
             if [ $? -ne 0 ];then
              x=`dmesg|grep "To change autoneg please use: ethtool -s <dev> autoneg <on|off>"`
			     if [ $? -eq 0 ];then
			     PRINT_LOG "INFO" "$x"
                fn_writeResultFile "${RESULT_FILE}" "${net} autoneg status" "pass"
              dmesg --clear
             else
               PRINT_LOG "FATAL" "result fail."
              fn_writeResultFile "${RESULT_FILE}" "${net} autoneg status" "fail"
                 fi
             fi
        #ethtool -s 打开autoneg
            ethtool -s $net autoneg on
                #抓取自协商状态
            statu3=`ethtool -a $net|grep Autonegotiate|awk '{print $2}'`
            if [ "$statu3" = "on" ];then
                PRINT_LOG "INFO" "set success"
                fn_writeResultFile "${RESULT_FILE}" "${net} set autoneg" "pass"
            else
                PRINT_LOG "FATAL" "set fail,please chick it."
                fn_writeResultFile "${RESULT_FILE}" "${net} set autoneg" "fail"
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









