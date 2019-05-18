#!/bin/bash
set -x

#*****************************************************************************************
# *用例编号：Performance2_007
# *用例名称：lmbench性能数据测试
# *作者：dwx588814
# *完成时间：2019-02-21
# *前置条件：
#   1、D06服务器1台
#   2、bios关闭smmu和ras
#   3、透明页模式设置为always：
#   4、服务器连接显示器、键盘
#   5、获取lmbench测试套上传到服务器的root用户下
# *测试步骤：
#   1 使用root用户登录操作系统
#   2 进入lmbench目录
#   3 执行lmbench-test.sh脚本，使用默认设置：sh ./lmbench-test.sh
#   4 4 观察脚本运行结果
# *测试结果：
#   1 脚本正常结束
#   2 获取脚本执行收集到数据
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



function init_env()
{

#检查结果文件是否存在，创建结果文件
fn_checkResultFile ${RESULT_FILE}

#root用户执行
if [ `whoami` != 'root' ]
then
    echo " You must be root user " 
    return 1
fi

#安装依赖包
case "$distro" in
  centos|redhat|suse)
	install_deps "wget make gcc gcc-c++"
	;;
  debian|ubuntu)
	install_deps "wget gcc g++ make"
	;;
esac

#透明页模式设置为always
echo always > /sys/kernel/mm/transparent_hugepage/defrag
echo always > /sys/kernel/mm/transparent_hugepage/enabled


#获取lmbench测试套压缩文件
if [ -d "lmbench/" ];then
	rm -rf lmbench/
fi

wget ${ci_http_addr}/test_dependents/lmbench.tar
tar xf lmbench.tar && rm -rf lmbench.tar

}



#测试执行
function test_case()
{


cd lmbench/
chmod 777 lmbench-test.sh

EXPECT=$(which expect)
$EXPECT << EOF
set timeout 300000
spawn sh lmbench-test.sh
expect "MULTIPLE COPIES"
send "1\r"
expect "Job placement selection"
send "1\r"
expect "MB"
send "512\r"
expect "SUBSET"
send "\r"
expect "FASTMEM"
send "\r"
expect "SLOWFS"
send "\r"
expect "DISKS"
send "\r"
expect "REMOTE"
send "\r"
expect "Processor mhz"
send "\r"
expect "FSDIR"
send "\r"
expect "Status output file"
send "\r"
expect "Mail results"
send "no\r"
expect eof
EOF

if [ $? -eq 0 ];then
	fn_writeResultFile "${RESULT_FILE}" "lmbench-test" "pass"
    PRINT_LOG "INFO" "lmbench-test is success"
else
    fn_writeResultFile "${RESULT_FILE}" "lmbench-test" "fail"
    PRINT_LOG "INFO" "lmbench-test is fail"
fi


#检查lmbench测试结果
cd lmbench-3.0-a9/
make see > see.log
grep "Error" see.log
if [ $? -eq 1 ];then
	fn_writeResultFile "${RESULT_FILE}" "make_see" "pass"
    PRINT_LOG "INFO" "make_see is success"
else
    fn_writeResultFile "${RESULT_FILE}" "make_see" "fail"
    PRINT_LOG "INFO" "make_see is fail"
fi

check_result ${RESULT_FILE}

cd ../../


}


#恢复环境
function clean_env()
{
    #清除临时文件
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

main $@
ret=$?
#LAVA平台上报结果接口，勿修改
lava-test-case "$test_name" --result ${test_result}
exit ${ret}














