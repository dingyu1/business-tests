#!/bin/bash
set -x

#*****************************************************************************************
# *用例编号：Performance2_005
# *用例名称：ltp测试套执行
# *作者：dwx588814
# *完成时间：2019-02-21
# *前置条件：
#   1、D06服务器1台
#   2、bios关闭smmu和ras
#   3、透明页模式设置为always：
#   echo always > /sys/kernel/mm/transparent_hugepage/enabled；
#   echo always > /sys/kernel/mm/transparent_hugepage/defrag
#   4、服务器连接显示器、键盘
#   5、上传ltp测试套到服务器的root用户下                                                            
# *测试步骤：
#  1 通过显示器模式下安装以下软件包：apt-get install -y make autoconf automake libtool
#  2 进入ltp目录执行：sh ltp-build.sh
#  3 第二步执行完成后在ltp目录下执行: sh  ltp-test.sh
#  4 使用ssh模式登录服务器
#  5 使用top观察cpu和内存占用情况
#  6 持续运行ltp-build.sh脚本7天，观察系统运行情况
# *测试结果：
#  1 观察cpu占用率100%，内存占用率40%+
# 2 持续运行7天机器不会出现挂死，系统运行正常
#*****************************************************************************************

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

#安装依赖包
install_deps "make autoconf automake libtool"

#获取ltp测试套压缩文件
if [ -d "ltp/" ];then
	rm -rf ltp/
fi

wget ${ci_http_addr}/test_dependents/ltp.tar
tar xf ltp.tar && rm -rf ltp.tar

}


测试执行
function test_case()
{

#ltp编译测试
cd ltp/

chmod 777 ltp-build.sh
chmod 777 ltp-test.sh

sh ltp-build.sh > ltp-build.log 2>&1
if [ $? -eq 0 ]
then
	PRINT_LOG "INFO" "ltp build is successful"
	fn_writeResultFile "${RESULT_FILE}" "ltp-build" "pass"
else
	PRINT_LOG "FATAL" "ltp build is fail"
	fn_writeResultFile "${RESULT_FILE}" "ltp-build" "fail"
fi


#ltp测试执行，持续运行7天
num=`dmesg|egrep "error|fail"|wc -l`

sh  ltp-test.sh > ltp-test.log 2>&1

num_later=`dmesg|egrep "error|fail"|wc -l`

if [ $? -eq 0 ] && [ $num -eq $num_later ]
then
	PRINT_LOG "INFO" "ltp test is successful"
	fn_writeResultFile "${RESULT_FILE}" "ltp-test" "pass"
else
	PRINT_LOG "FATAL" "ltp test is fail"
	fn_writeResultFile "${RESULT_FILE}" "ltp-test" "fail"
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












