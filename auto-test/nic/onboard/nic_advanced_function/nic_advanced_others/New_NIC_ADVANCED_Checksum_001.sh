#!/bin/bash

#*****************************************************************************************
# *用例名称：New_NIC_ADVANCED_Checksum_001
# *用例功能: checksum默认参数检查
# *作者：mwx547872
# *完成时间：2019-4-16
# *前置条件：
#   1、预装liunx操作系统
# *测试步骤：
#   1、 进入linux操作系统。
#   2.  检查
# *测试结果
#  设置成功
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
        fn_install_pkg "ethtool" 2
}

#测试执行
function test_case()
{
         check_result ${RESULT_FILE}

         network_name=`ip link|grep "state UP"|awk '{print $2}'|sed 's/://g'|egrep -v "vir|br|vnet|docker"`
         echo $network_name

         for i in $network_name
         do
          type=`ethtool -i $i|grep "driver"|awk -F ':' '{print $2}'|sed 's/ //g'`
          if [ $type == "hns3" ];then
              fn_writeResultFile "${RESULT_FILE}" "IS the onboard nic " "pass"
              PRINT_LOG "INFO" "is the onboard nic success"
          else
              fn_writeResultFile "${RESULT_FILE}" "not onboard nic" "fail"
              PRINT_LOG "FAIL" "not onboard nic"
              exit 1
          fi


          ethtool -k $i         
          if [ $? -eq 0 ];
	  then
              fn_writeResultFile "${RESULT_FILE}" "query the onboard nic default parameters" "pass"
              PRINT_LOG "INFO" "query the onboard nic default parameters"
          else
              fn_writeResultFile "${RESULT_FILE}" "query the onboard nic default parameters" "fail"
              PRINT_LOG "FAIL" "query the onboard nic default parameters"
          fi


         done
         ethtool -K $i|sed -n '1,8p' > 1.log
         cat 1.log
         
         check_result ${RESULT_FILE}



}
function clean_env()
{
       FUNC_CLEAN_TMP_FILE

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
#LAVA平台上报结果接口，勿修改
lava-test-case "$test_name" --result ${test_result}
exit ${ret}
