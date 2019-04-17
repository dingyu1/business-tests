#!/bin/bash

#*****************************************************************************************
# *用例名称：New_NIC_ADVANCED_FlowControl_015                                                     
# *用例功能：网卡PAUSE Transmit-only状态检查                          
# *作者：lwx588815                                                          
# *完成时间：2019-4-10                                                               
# *前置条件：                                                                            
#      1.网卡未设置过参数
#      2.所有网口已连接          
#      3.本端关闭网口流控自协商：板载电口ethtool -s ethX autoneg off ,标卡电口使用ethtool -A ethX auton#      eg off                                                       
# *测试步骤：                                                                               
#      1、测试端执行ethtool -A ethx rx off
#      2、测试端执行ethtool ethx查看PAUSE状态，有结果A
#      3、测试端执行ethtool -A ethx rx on恢复设置
# *测试结果：                                                                            
#      1.Advertised pause frame use: Transmit-only                                                  
#*****************************************************************************************

#加载公共函数
. ../../../../../utils/error_code.inc
. ../../../../../utils/test_case_common.inc
. ../../../../../utils/sys_info.sh
. ../../../../../utils/sh-test-lib

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
        #install
        fn_install_pkg "ethtool" 2

        network=`ip link | grep "state UP" | awk '{ print $2 }' | sed 's/://g'|egrep -v "vir|br|docker|vnet"`
        for i in $network
        do
        ethtool $i|grep "Supported ports:"|grep "TP"
        if [ $? -eq 0 ];then
            echo "$i" | tee -a network.txt
        fi
        done
}       

#测试执行
function test_case()
{ 

    for j in `cat network.txt`
    do
       ethtool -i $j|grep "driver"|grep "hns3"
       if [ $? -eq 0 ];then
          ethtool -s $j autoneg off
       else
          ethtool -A $j autoneg off
       fi
 
       ethtool -A $j rx off 
       sleep 5
       ethtool $j 2>&1 |tee run.txt
       PAUSE=`cat run.txt|grep "Advertised pause frame use:"|awk '{print $5}'`
       if [ "$PAUSE"x = "Transmit-only"x ];then
           PRINT_LOG "INFO" "$j have Transmit-only"
           fn_writeResultFile "${RESULT_FILE}" "$j Transmit-only" "pass"
       else
           PRINT_LOG "FATAL" "$j not have Transmit-only"
           fn_writeResultFile "${RESULT_FILE}" "$j not  Transmit-only" "fail"
       fi
       ethtool -A $j rx on
    done
     
	#检查结果文件，根据测试选项结果，有一项为fail则修改test_result值为fail，
    check_result ${RESULT_FILE}

}


#恢复环境
function clean_env()
{
	#清除临时文件
	FUNC_CLEAN_TMP_FILE
        rm -rf network.txt run.txt

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
