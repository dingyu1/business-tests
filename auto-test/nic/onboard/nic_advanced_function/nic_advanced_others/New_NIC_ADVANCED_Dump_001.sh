#!/bin/bash

#*****************************************************************************************
# *用例名称：New_NIC_Dump
# *用例功能: 查询和设置dump flag data
# *作者：mwx547872
# *完成时间：2019-4-11
# *前置条件：
#   1、预装liunx操作系统
# *测试步骤：
#   1、 进入linux操作系统。
#   2.  设置
#   3.  查询
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
        # network_name=`ifconfig|grep 'BROADCAST,RUNNING,MULTICAST'|egrep -v "vir|br|vnet"|awk -F: '{print $1}'`
         network_name=`ip link|grep "state UP"|awk '{print $2}'|sed 's/://g'|egrep -v "vir|br|docker|vnet"`
         echo $network_name

         for i in $network_name
         do
          ethtool -W $i 1 >1.log 2>&1
          #str1为0代表不支持
          #str2为0代表设置成功
          str1=`grep "not supported" 1.log`
          str2=`ethtool -W $i 1`
          if [ "$str1" != "" ];
          then
              fn_writeResultFile "${RESULT_FILE}" "not support set dump flag data" "pass"
              PRINT_LOG "INFO" "not support set dump flag data"
          elif [ $str2 -eq 0 ]; then
                    ethtool -w $i
                    if [ $? -eq 0 ];then
                      fn_writeResultFile "${RESULT_FILE}" "set dump flag data" "pass"
                      PRINT_LOG "INFO" "set dump flag data"
                    else
                     fn_writeResultFile "${RESULT_FILE }" "set dump flag data" "fail"
                     PRINT_LOG "FAIL" "set dump flag data"
                    fi
          else
             fn_writeResultFile "${RESULT_FILE}" "set dump flag data" "fail"
             PRINT_LOG "FAIL" "set dump flag data"
         fi


         done

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
