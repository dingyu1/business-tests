#!/bin/bash
set -x

#*****************************************************************************************
# *用例编号：Performance2_003                                                         
# *用例名称：对齐性格标杆参数：400.perlbench 462.libquantum                                              
# *作者：dwx588814                                                                       
# *完成时间：2019-02-21                                                                   
# *前置条件：                                                                            
#   1、D06服务器1台
#   2、bios关闭smmu和ras
#   3、透明页模式设置为always：
#   echo always > /sys/kernel/mm/transparent_hugepage/enabled；
#   echo always > /sys/kernel/mm/transparent_hugepage/defrag
#   4、获取测试套压缩文件/opt/linaro-rp/sailing/ubuntu/test-tool/1620check.tar并解压到服务器的root用户下                                                                
# *测试步骤：                                                                               
#   1 按解压后目录下的readme.txt的1~3步进行操作
#   2 检查收集400.perlbench和462.libquantum的数据是否符合需求
# *测试结果：
#   收集到400.perlbench和462.libquantum的数据符合要求

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
case "$distro" in
  centos|redhat|suse)
	install_deps "wget make gcc gcc-c++"
	;;
  debian|ubuntu)
	install_deps "wget gcc g++ make"
	;;
esac

#获取1620check测试套压缩文件
if [ -d "1620check/" ];then
	rm -rf 1620check/
fi

wget ${ci_http_addr}/test_dependents/1620check.tar
tar xf 1620check.tar && rm -rf 1620check.tar

}


#测试执行
function test_case()
{

#修改文件执行权限
file1="1620check/specint-ubuntu/400.perlbench/perlbench_base.d06-ubuntu"
file2="1620check/specint-ubuntu/462.libquantum/libquantum_base.d06-ubuntu"
file3="1620check/specint-ubuntu/400-462.sh"
file4="1620check/specint-ubuntu/arm_log_process.py"
file5="1620check/specint-ubuntu/run-test.sh"

for i in $file1 $file2 $file3 $file4 $file5
do
	if [ ! -x "$i" ];then
		chmod 777 $i
	fi
done

#执行脚本run-test.sh
cd 1620check/specint-ubuntu/
source run-test.sh > run.log
grep "end of file" run.log
if [ $? -eq 0 ];then
	fn_writeResultFile "${RESULT_FILE}" "run-test" "pass"
    PRINT_LOG "INFO" "execute the script is success"
else
    fn_writeResultFile "${RESULT_FILE}" "run-test" "fail"
    PRINT_LOG "INFO" "execute the script is fail"
fi

grep "400.perlbench" run.log
if [ $? -eq 0 ];then
	fn_writeResultFile "${RESULT_FILE}" "400-perlbench" "pass"
    PRINT_LOG "INFO" "execute the script is success"
else
    fn_writeResultFile "${RESULT_FILE}" "400-perlbench" "fail"
    PRINT_LOG "INFO" "execute the script is fail"
fi

grep "400.perlbench" run.log
if [ $? -eq 0 ];then
	fn_writeResultFile "${RESULT_FILE}" "462-libquantum" "pass"
    PRINT_LOG "INFO" "execute the script is success"
else
    fn_writeResultFile "${RESULT_FILE}" "462-libquantum" "fail"
    PRINT_LOG "INFO" "execute the script is fail"
fi

cd ../

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






























































