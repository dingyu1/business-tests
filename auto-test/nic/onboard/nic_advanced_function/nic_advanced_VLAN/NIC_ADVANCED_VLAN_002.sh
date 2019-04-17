#!/bin/bash

###############################################################################
#用例名称：config_valn（配置VLAN）
#用例功能：给所有的网口配置VLAN
#作者：mwx547872
#完成时间：2019-1-22
#前置条件：
#   OS系统正常启动
#测试步骤：
# 1. os下查询到所有网口的名字
# 2. 给所有的网口配置2个VLAN
# 3. 给VLAN配置IP
# 4. 删除VLAN
#测试结果
# 可以正常配置VLAN，配置VLAN IP ,成功删除VALN
################################################################################
#加载公共函数
. ../../../../../utils/test_case_common.inc
. ../../../../../utils/error_code.inc
. ../../../../../utils/sys_info.sh
. ../../../../../utils/sh-test-lib
set -x
#获取脚本名称作为测试用例名称
test_name=$(basename $0 | sed -e 's/\.sh//')
#创建log目录
TMPDIR=./logs/temp
mkdir -p ${TMPDIR}

#存放脚本处理中间状态/值等
TMPFILE=${TMPDIR}/${test_name}.tmp

#存放每个测试步骤执行结果
RESULT_FILE=${TMPDIR}/${test_name}.result
test_result="pass"


################判断是否在root下面执行用例#############
function init_env(){
   fn_checkResultFile ${RESULT_FILE}
   if [ `whoami` != 'root' ]
   then
     echo "You must be root user " >$2
     exit 1
   fi
    yum install vconfig -y
}


function test_case()
{
  check_result ${RESULT_FILE}
  network_name=`ip link|grep "state UP"|awk '{print $2}'|sed 's/://g'|egrep -v "vir|br|vnet|docker"`
  echo $network_name
 for i in $network_name
 do
     vconfig add $i 100
     if [ $? -eq 0 ];then
        PRINT_LOG "INFO" "add vlan first"
        fn_writeResultFile "${RESULT_FILE}" "add vlan first" "pass"
     else
       PRINT_LOG "FAIL" "add valan first"
       fn_writeResultFile "${RESULT_FILE}" "add vlan first" "fail"
     fi

     ip address add dev $i.100 192.168.1.26/24 dev $i.100
     if [ $? -eq 0 ];then
         PRINT_LOG "INFO" "add ip on vlan first"
         fn_writeResultFile "${RESULT_FILE}" "add ip on vlan first" "pass"
     else
         PRINT_LOG "FAIL" "add ip on vlan first"
         fn_writeResultFile "${RESULT_FILE}" "add ip on vlan first" "fail"
     fi
     vconfig add $i 200
     if [ $? -eq 0 ];then
        PRINT_LOG "INFO" "add vlan two"
        fn_writeResultFile "${RESULT_FILE}" "add vlan two" "pass"
     else
       PRINT_LOG "FAIL" "add vlan two"
       fn_writeResultFile "${RESULT_FILE}" "add vlan two" "fail"
     fi
     ip address add dev $i.200 192.168.1.27/24 dev $i.100
     if [ $? -eq 0 ];then

        PRINT_LOG "INFO" "add ip on vlan two"

        fn_writeResultFile "${RESULT_FILE}" "add ip vlan two" "pass"
     else

       PRINT_LOG "FAIL" "add ip  vlan two"

       fn_writeResultFile "${RESULT_FILE}" "add ip  vlan two" "fail"
     fi
     vconfig rem  $i.100
     if [ $? -eq 0 ];then
        PRINT_LOG "INFO" "rm vlan first"
        fn_writeResultFile "${RESULT_FILE}" "rm vlan first" "pass"
     else
       PRINT_LOG "FAIL" "rm vlan first"
      fn_writeResultFile "${RESULT_FILE}" "rm vlan first" "fail"
    fi

     vconfig rem $i.200

    if [ $? -eq 0 ];then
       PRINT_LOG "INFO" "rm two vlan"
       fn_writeResultFile "${RESULT_FILE}" "rm two vlan" "pass"
    else
       PRINT_LOG "FAIL" "rm two vlan"
       fn_writeResultFile "${RESULT_FILE}" "rm two vlan" "fail"
    fi
 done
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
lava-test-case "$test_name" --result ${test_result}
exit ${ret}
