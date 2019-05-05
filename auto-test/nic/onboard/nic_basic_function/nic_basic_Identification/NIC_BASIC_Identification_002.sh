#!/bin/bash 

#*****************************************************************************************
# *用例名称：NIC_BASIC_Identification_002                                                       
# *用例功能: 网卡IO Space大小测试
# *作者：                                                                       
# *完成时间：2019-4-28                                                               
# *前置条件：                                                                             
#   1、预先安装linux操作系统
# *测试步骤：       
#   1、在系统中执行lspci 查询出网卡bus号
#   2、在系统中执行cat /proc/iomem查看iomem空间大小
#                                                                  
# *测试结果：       
# 可查看到网卡占用的IO空间大小。                                                                     
#*****************************************************************************************

#加载公共函数
. ../../../../../utils/test_case_common.inc
. ../../../../../utils/error_code.inc
. ../../../../../utils/sys_info.sh
. .../../../../../utils/sh-test-lib		

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

    #root用户执行
    if [ `whoami` != 'root' ]
    then
        PRINT_LOG "WARN" " You must be root user "
        return 1
    fi
 #   fn_install_pkg "net-tools" 2
}

#测试执行
function test_case()
{
    bus_info=`lspci -nnD |egrep -i "eth|mellanox|X550|82599|1822|I350"|awk '{print $1}'`
    echo "$bus_info"
	for i in $bus_info
	do
		#将查询结果写入文件
		cat /proc/iomem |grep "$i" |tee nic_iomom.log
	
	
	#判断文件是否为空	
	if [ ! -s nic_iomom.log ]
	then
		PRINT_LOG "FATAL" "Query iomem fail"
		fn_writeResultFile "${RESULT_FILE}" "${i}_Query_iomem" "fail"
	else
		PRINT_LOG "INFO" "Query iomem success"
		fn_writeResultFile "${RESULT_FILE}" "${i}_Query_iomem" "pass"
	fi
	done
#检查结果文件，根据测试选项结果，有一项为fail则修改test_result值为fail，
   check_result ${RESULT_FILE}
}
 

#恢复环境
function clean_env()
{

    #清除临时文件
    FUNC_CLEAN_TMP_FILE
	rm -f nic_iomom.log
    #自定义环境恢复实现部分,工具安装不建议恢复
      #需要日志打印，使用公共函数PRINT_LOG，用法：PRINT_LOG "INFO|WARN|FATAL" "xxx"
	

}

function main()
{
    init_env || test_result="fail"
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