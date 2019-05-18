#!/bin/bash
set -x

#*****************************************************************************************
# *用例编号：Performance2_033
# *用例名称：iozone性能数据测试
# *作者：dwx588814
# *完成时间：2019-02-21
# *前置条件：
#   1、D06服务器1台
#   2、bios关闭smmu和ras
#   3、透明页模式设置为always：
#   4、服务器连接显示器、键盘
#   5、获取iozone测试套上传到服务器的root用户下
# *测试步骤：
#   1 使用root用户登录操作系统
#   2 进入iozone目录
#   3 执行iozone-test.sh脚本：source iozone-test.sh
#   4 观察脚本运行结果
# *测试结果：
#   1 脚本正常结束
#   2 每项检查都为OK
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
 
#检查结果文件是否存在，创建结果文件：
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


#获取iozone测试套压缩文件
if [ -d "iozone/" ];then
	rm -rf iozone/
fi

wget ${ci_http_addr}/test_dependents/iozone.tar
tar xf iozone.tar && rm -rf iozone.tar

}



#测试执行
function test_case()
{

cd iozone/
source iozone-test.sh > iozone.log
result_iozone=`grep "iozone test complete" iozone.log|wc -l`
if [ "${result_iozone}"x == "3"x  ]
then
	PRINT_LOG "INFO" "execute the script is successful"
	fn_writeResultFile "${RESULT_FILE}" "iozone_test" "pass"
else
	PRINT_LOG "FATAL" "execute the script is fail"
	fn_writeResultFile "${RESULT_FILE}" "iozone_test" "fail"
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














