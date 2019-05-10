#!/bin/bash
set -x

#==========================================================================================================
#用例编号：Ipmitool_001
#用例名称：ipmitool sol串口模式
#作者：dwx588814
#完成时间：2019/2/20
#预置条件：
# 1 安装有ubuntu操作系统的D06服务器2台。
# 2 bios在Oem config里开启IBMC WDT Support For POST
# 3 BIOS中MIS Config中开启Support SPCR
# 4 安装ipmitool工具。
#测试步骤：
# 1 登录一台单板执行ipmitool -H <另一台单板BMC的ip> -I lanplus -U Administrator -P Admin@9000 sol activate
# 2 输入正确的用户名和密码检查能否登录系统
#测试结果：
# 1 能够正常登录系统
#=============================================================================================================

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

#root用户执行
if [ `whoami` != 'root' ]
then
    PRINT_LOG "WARN" " You must be root user " 
    return 1
fi

#安装依赖包
install_deps "ipmitool expect"


#关闭SOL功能
ipmitool -H $ipmitool_bmc -I lanplus -U $ipmitool_bmc_user -P $ipmitool_bmc_password sol deactivate

#重启另一块单板
ipmitool -H $ipmitool_bmc -I lanplus -U $ipmitool_bmc_user -P $ipmitool_bmc_password power reset
if [ $? -eq 0 ]
then
	PRINT_LOG "INFO" "reset SOL is success"
	fn_writeResultFile "${RESULT_FILE}" "reset_SOL" "pass"
else
	PRINT_LOG "FATAL" "reset SOL is fail"
	fn_writeResultFile "${RESULT_FILE}" "reset_SOL" "fail"
fi

}

#测试执行
function test_case()
{

#登录单板
EXPECT=$(which expect)
$EXPECT << EOF
set timeout 3600
spawn ipmitool -H $ipmitool_bmc -I lanplus -U $ipmitool_bmc_user -P $ipmitool_bmc_password sol activate
expect "login:"
send "root\r";
expect "Password:"
send "root\r";
expect "#"
send "ip a\r";

expect eof
EOF

if [ $? -eq 0 ]
then
	PRINT_LOG "INFO" "login  is success"
	fn_writeResultFile "${RESULT_FILE}" "login_SOL" "pass"
else
	PRINT_LOG "FATAL" "login is fail"
	fn_writeResultFile "${RESULT_FILE}" "login_SOL" "fail"
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


