#!/bin/bash

#*****************************************************************************************
#用例名称：New_NIC_BASIC_Negotiation_013
#用例功能：对端指定100MSpeed开启自协商，本端板载电口自协商测试
#作者：qwx655884
#完成时间：
#前置条件
#  网卡为默认设置
#测试步骤
#  1、对端使用命令ethtool -s ethx  speed 100 duplex full autoneg on 命令修改对端网卡速率。
#  2、待协商成功后，使用ethtool ethx查看测试端网卡适配信息，有结果A
#  3、本端ping对端的ip，有结果B
#  4、遍历板载电口
#测试结果
#  A)Speed: 100Mb/s
#    Duplex: Full
#    Auto-negotiation: on
#  B)ip能ping通
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

debug=false

sut_on_board_fiber_10=$env_sut_on_board_fiber_0
sut_on_board_TP_20=$env_sut_on_board_TP_20
sut_on_board_TP_30=$env_sut_on_board_TP_30
sut_on_board_TP_40=$env_sut_external_network_card_40
#client_ip_50=$env_sut_external_network_card_50

tc_on_board_fiber_10=$env_tc_on_board_fiber_0
tc_on_board_TP_20=$env_tc_on_board_TP_20
tc_on_board_TP_30=$env_tc_on_board_TP_30
tc_on_board_TP_40=$env_tc_external_network_card_40
#server_ip_50=env_tc_external_network_card_50

password=$env_tc_passwd

if [ $debug = true ];then
    #sut 本端，tc对端
    sut_on_board_fiber_10=192.168.1.3
    sut_on_board_TP_20=192.168.10.3
    sut_on_board_TP_30=192.168.20.3
    sut_on_board_TP_40=192.168.30.3
    #client_ip_50=192.168.50.11
    
    tc_on_board_fiber_10=192.168.1.6
    tc_on_board_TP_20=192.168.10.6
    tc_on_board_TP_30=192.168.20.6
    tc_on_board_TP_40=192.168.30.6
    #server_ip_50=192.168.50.12
    
    password=root
fi


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
	#安装ethtool工具
	ethtool -h || fn_install_pkg ethtool 3
	fn_install_pkg "gcc make tar wget sshpass net-tools" 2
}

#测试执行
function test_case()
{
    SSH="timeout 1000 sshpass -p root ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
	SCP="timeout 1000 sshpass -p root scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
    eth1=`$SSH root@$tc_on_board_fiber_10 ip a | grep $tc_on_board_TP_20 | awk '{print $NF}'`
    eth2=`$SSH root@$tc_on_board_fiber_10 ip a | grep $tc_on_board_TP_30 | awk '{print $NF}'`
    echo $eth1
    echo $eth2
    #恢复网卡默认设置
    ethtool -s $eth1 autoneg on
    ethtool -s $eth2 autoneg on
    $SSH root@$tc_on_board_fiber_10 "ethtool -s $eth1 speed 100 duplex full autoneg on"
    if [ $? -eq 0 ];then
        PRINT_LOG "INFO" "$eth1 set success"
        fn_writeResultFile "${RESULT_FILE}" "$eth1 set autoneg" "pass"
    else
        PRINT_LOG "FATAL" "$eth1 set fail"
        fn_writeResultFile "${RESULT_FILE}" "$eth1 set autoneg" "fail"
    fi

    $SSH root@$tc_on_board_fiber_10 "ethtool -s $eth2 speed 100 duplex full autoneg on"
    if [ $? -eq 0 ];then
        PRINT_LOG "INFO" "$eth2 set success"
        fn_writeResultFile "${RESULT_FILE}" "$eth2 set autoneg" "pass"
    else
        PRINT_LOG "FATAL" "$eth2 set fail."
        fn_writeResultFile "${RESULT_FILE}" "$eth2 set autoneg" "fail"
    fi
    sleep 5
    $SSH root@$tc_on_board_fiber_10 ethtool $eth1
    $SSH root@$tc_on_board_fiber_10 ethtool $eth2

    eth3=`ip a | grep $sut_on_board_TP_20 | awk '{print $NF}'`
    sleep 5
    a=`ethtool $eth3`
    speed=`ethtool $eth3|grep Speed|awk '{print $2}'`
    Duplex=`ethtool $eth3|grep Duplex|awk '{print $2}'`
    Auto=`ethtool $eth3|grep Auto|awk '{print $2}'`
    if [ $speed = 100Mb/s ];then
        if [ $Duplex = Full ];then
          if [ $Auto = on ];then
            PRINT_LOG "INFO" "$eth3 Auto_negotiation success"
            fn_writeResultFile "${RESULT_FILE}" "$eth3 Auto_negotiation" "pass"
          else
            PRINT_LOG "FATAL" "$Auto"
            fn_writeResultFile "${RESULT_FILE}" "$eth3 Auto_negotiation" "fail"
          fi
        else
            PRINT_LOG "FATAL" "$Duplex"
            fn_writeResultFile "${RESULT_FILE}" "$eth3 Auto_negotiation" "fail"
        fi
      else
          PRINT_LOG "FATAL" "$speed"
          fn_writeResultFile "${RESULT_FILE}" "$eth3 Auto_negotiation" "fail"
      fi


    eth4=`ip a | grep $sut_on_board_TP_30 | awk '{print $NF}'`
    sleep 5
    b=`ethtool $eth4`
    speed=`ethtool $eth4|grep Speed|awk '{print $2}'`
    Duplex=`ethtool $eth4|grep Duplex|awk '{print $2}'`
    Auto=`ethtool $eth4|grep Auto|awk '{print $2}'`
    if [ $speed = 100Mb/s ];then
       if [ $Duplex = Full ];then
         if [ $Auto = on ];then
           PRINT_LOG "INFO" "$eth4 Auto_negotiation success"
           fn_writeResultFile "${RESULT_FILE}" "$eth4 Auto_negotiation" "pass"
         else
           PRINT_LOG "FATAL" "$Auto"
           fn_writeResultFile "${RESULT_FILE}" "$eth4 Auto_negotiation" "fail"
         fi
       else
           PRINT_LOG "FATAL" "$Duplex"
           fn_writeResultFile "${RESULT_FILE}" "$eth4 Auto_negotiation" "fail"
       fi
     else
         PRINT_LOG "FATAL" "$speed"
         fn_writeResultFile "${RESULT_FILE}" "$eth4 Auto_negotiation" "fail"
     fi

     sleep 5 
   ping $tc_on_board_TP_20 -c 4
    if [ $? -eq 0 ];then
      PRINT_LOG "INFO" "$eth1 ping success"
        fn_writeResultFile "${RESULT_FILE}" "$eth1 ping" "pass"
    else
        PRINT_LOG "FATAL" "$eth1 ping fail"
        fn_writeResultFile "${RESULT_FILE}" "$eth1 ping" "fail"
    fi
   ping $tc_on_board_TP_30 -c 4
    if [ $? -eq 0 ];then
       PRINT_LOG "INFO" "$eth2 ping success"
        fn_writeResultFile "${RESULT_FILE}" "$eth2 ping" "pass"
    else
        PRINT_LOG "FATAL" "$eth2 ping fail"
        fn_writeResultFile "${RESULT_FILE}" "$eth2 ping" "fail"
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
     #恢复对端环境
    $SSH root@$tc_on_board_fiber_10 "ethtool -s $eth1 autoneg on"
    $SSH root@$tc_on_board_fiber_10 "ethtool -s $eth2 autoneg on"
    ethtool -s $eth3 autoneg on
    ethtool -s $eth4 autoneg on
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

