#!/bin/bash

#*****************************************************************************************
# *用例名称：New_NIC_BASIC_Rate_008
# *用例功能: 光口不支持速率设置和自协商
# *作者：mwx547872
# *完成时间：2019-4-24
# *前置条件：
#   1、预装liunx操作系统
#   2. 所有光口网口模块加载正常
# *测试步骤：
#   1、 ethtoo -s 网口 autoeng on
#   2.  ethtool -s 网口 10M/100M/1000M
# *测试结果
#  不支持自协商，不支持修改速率
#*****************************************************************************************
set -x
#加载公共函数
. ../../../../../utils/test_case_common.inc
. ../../../../../utils/error_code.inc
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
test_result="pass"


#预置条件
function init_env()
{
        #检查结果文件是否存在，创建结果文件：
        fn_checkResultFile ${RESULT_FILE}
        if [ `whoami` != 'root' ]; then
            echo "You must be the superuser to run this script" > $2
            exit 1
        fi
        ethtool -h
        if [ $? -eq 0 ];
        then
           PRINT_LOG "INFO" "the ethtool package has been installed"
         else
           fn_install_pkg "ethtool" 2
        fi
}

#测试执行
function test_case()
{
         check_result ${RESULT_FILE}
         #获取所有已经启动的网口的名称
         network_name=`ip link|grep "state UP"|awk '{print $2}'|sed 's/://g'|egrep -v "vir|br|vnet|docker"`
         echo $network_name

         for i in $network_name
         do
          #获取到光口名称
          str1=`ethtool $i |grep "FIBRE"`
          #判断是否支持开启自协商
          if [ "$str1" != "" ];
	      then
              ethtool -s $i autoneg on > 1.log 2>&1
              grep "not supported" 1.log
              if [ $? -eq 0 ];then
             
               fn_writeResultFile "${RESULT_FILE}" "network_card_does_not_support_autoeng" "pass"
               PRINT_LOG "INFO" "network_card_does_not_support_autoeng"
              else
               fn_writeResultFile "${RESULT_FILE}" "network_card_set_autoeng" "fail"
               PRINT_LOG "FAIL" "network_card_set_autoeng"
              fi
          
           #判断是否可以设置速率为10M/100M/1000M
           for j in 10 100 1000
           do
               ethtool -s $i speed $j > 2.log 2>&1
               echo $i
               echo $j
               grep "not supported" 2.log
               if [ $? -eq 0 ];then
                  fn_writeResultFile "${RESULT_FILE}" "network_card_does_not_support_set_speed" "pass"
                  PRINT_LOG "INFO" "network_card_does_not_support_set_speed"
               else
                  fn_writeResultFile "${RESULT_FILE}" "network_card_set_speed" "fail"
                  PRINT_LOG "INFO" "network_card_set_speed"
               fi
               #确认设置速率没有成功
              speed=`ethtool $i |grep "Speed"|awk -F ':' '{print $2}'|sed 's/ //g'|sed 's/Mb\/s//g'`
              echo $speed
              if [ $speed -ne $j ];
              then
                fn_writeResultFile "${RESULT_FILE}" "network_card_set_speed_does_not_success" "pass"
                PRINT_LOG "INFO" "network_card_set_speed_does_not_success"
              else
                fn_writeResultFile "${RESULT_FILE}" "network_card_set_speed" "fail"
                PRINT_LOG "FAIL" "network_card_set_speed"
              fi

               
           done
    
           #确认设置自协商没有成功
          auto=`ethtool $i|grep "Auto-negotiation"|awk -F ':' '{print $2}'|sed 's/ //g'`
          echo $auto  
          if [ "$auto" == "off" ];
          then
              fn_writeResultFile "${RESULT_FILE}" "network_card_set_autoneg_does_not_success" "pass"
              PRINT_LOG "INFO" "network_card_set_autoneg_does_not_success"
          else
              fn_writeResultFile "${RESULT_FILE}" "network_card_set_autoeng" "fail"
              PRINT_LOG "FAIL" "network_card_set_autoeng"
          fi
    
     fi          
done
         

         check_result ${RESULT_FILE}



}
function clean_env()
{
       FUNC_CLEAN_TMP_FILE
       rm -f 1.log
       rm -f 2.log

}

function main()
{
        init_env|| test_result="fail"
        if [ ${test_result} = "pass" ]
        then

        test_case || test_result="fail"
       fi
        clean_env || test_result="fail"
        [ "${test_result}" = "pass" ] || return 1

}

main
ret=$?
lava-test-case "$test_name" --result ${test_result}
exit ${ret}
