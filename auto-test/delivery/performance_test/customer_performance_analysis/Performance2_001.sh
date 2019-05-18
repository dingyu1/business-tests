#!/bin/bash
set -x

#==========================================================================
# *用例编号： Performance2_001
# *用例名称： 关闭smmu和ras                     
# *作者：dwx588814                            
# *完成时间：2019-2-20                      
# *前置条件：
#    1 D06服务器1台
#    2 BIOS管理页中将smmu和ras设置为disable
# *测试步骤:
#    1 启动单板并进入操作系统
#    2 执行:dmesg|grep -i smmu
#    3 执行:dmesg|grep -i GHES
#    4 执行:dmesg|grep -i EINJ
# *测试结果
#    1 启动日志中查询不到smmu关键字
#    2 启动日志中查询不到GHES、EINJ关键字
#=========================================================================


#加载公共函数,具体看环境对应的位置修改
. ../../../../utils/test_case_common.inc
. ../../../../utils/error_code.inc
. ../../../../utils/sys_info.sh
. ../../../../utils/sh-test-lib       

#获取脚本名称作为测试用例名称
test_name=$(basename $0 | sed -e 's/\.sh//')
#创建log目录
TMPDIR=/var/logs_test/temp
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

#root用户执行
if [ `whoami` != 'root' ]
then
     echo  " You must be root user " 
     return 1
fi

}

#测试执行
function test_case()
{

#执行:dmesg|grep -i smmu
smmu=`dmesg|grep -i smmu`
if [ "$smmu"x == ""x ]
then
	fn_writeResultFile "${RESULT_FILE}" "check_smmu" "pass"
	PRINT_LOG "INFO" "the smmu is not found successfully"
else
	fn_writeResultFile "${RESULT_FILE}" "check_smmu" "fail"
	PRINT_LOG "FATAL" "the smmu is not found faild"
fi

#执行:dmesg|grep -i GHES
GHES=`dmesg|grep -i GHES`
if [ "$GHES"x == ""x ]
then
	fn_writeResultFile "${RESULT_FILE}" "check_GHES" "pass"
	PRINT_LOG "INFO" "the GHES is not found successfully"
else
	fn_writeResultFile "${RESULT_FILE}" "check_GHES" "fail"
	PRINT_LOG "FATAL" "the GHES is not found faild"
fi

#执行:dmesg|grep -i EINJ
EINJ=`dmesg|grep -i EINJ`
if [ "$EINJ"x == ""x ]
then
	fn_writeResultFile "${RESULT_FILE}" "check_EINJ" "pass"
	PRINT_LOG "INFO" "the EINJ is not found successfully"
else
	fn_writeResultFile "${RESULT_FILE}" "check_EINJ" "fail"
	PRINT_LOG "FATAL" "the EINJ is not found faild"
fi

check_result ${RESULT_FILE}	
}




#恢复环境
function clean_env()
{

#清除临时文件
FUNC_CLEAN_TMP_FILE
  

}


function main()
{
    init_env || test_result="fail"
    if [ ${test_result} = 'pass' ]
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

























