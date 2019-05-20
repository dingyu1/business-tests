#!/bin/bash

#*****************************************************************************************
# *用例名称：Hi1822卡端口检查                                                         
# *用例功能：Hi1822卡端口检查                                                 
# *作者：lwx652446                                                                      
# *完成时间：2019-2-20                                                               
# *前置条件：                                                                            
#   1、安装suse操作系统的D06服务器1台
#   2、单板上配置有Hi1822卡                                                                  
# *测试步骤：                                                                               
#   1 进入操作系统
#   2 使用ip a命令检查是否能观察到Hi1822卡的端口
#   3 使用ethtool查询Hi1822卡所以端口类型     
# *测试结果：                                                                            
#   1 能检查到Hi1822卡的四个端口信息
#   2 能检查到Hi1822卡的四个端口类型是光口类型                                                         
#*****************************************************************************************

#加载公共函数
. ../../../../utils/test_case_common.inc
. ../../../../utils/error_code.inc
. ../../../../utils/sys_info.sh
. ../../../../utils/sh-test-lib      

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
	ifconfig -h || fn_install_pkg net-tools 3
    
	#root用户执行
	if [ `whoami` != 'root' ]
	then
		PRINT_LOG "INFO" "You must be root user " 
		fn_writeResultFile "${RESULT_FILE}" "Run_as_root" "fail"
	fi

}

#测试执行
function test_case()
{
	port_total=0
    for i in `ip a|grep -i 'state'|awk -F: '{print $2}'`
    do
        echo $i
		lspci | grep `ethtool -i $i| grep bus-info | awk '{print $2}'|awk -F":" '{print $2":"$3}'` | grep -i 1822
		if [ $? -eq 0 ]
		then
			echo "$i is 1822 interface "
			PRINT_LOG "INFO" "$i is 1822  interface" 
			#判断是否是光口
			port_support=`ethtool $i |grep -i "Supported ports"|awk -F":" '{print $2}'|awk '{print $2}'`
			if [ "$port_support" = "FIBRE" ] || [ "$port_support" = "fibre" ]
			then
				echo "$i is 1822 fibre interface"
				PRINT_LOG "INFO" "$i is 1822 fibre interface" 
				let port_total+=1
			else
				echo "$i not is 1822 fibre interface"
				PRINT_LOG "FATAL" "$i not is1822 fibre interface" 
			fi
		fi
	done
	
	if [ "$port_total" -eq 4 ]
	then
		echo "1822 has 4 fibre  interface "
		PRINT_LOG "INFO" "has_4_interface" 
		fn_writeResultFile "${RESULT_FILE}" "has_4_interface" "success"
	else
		echo "1822 not has 4 fibre interface "
		PRINT_LOG "INFO" "not_has_4_interface" 
		fn_writeResultFile "${RESULT_FILE}" "not_has_4_interface" "fail"
	fi
    #检查结果文件，根据测试选项结果，有一项为fail则修改test_result值为fail，
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
    if [ ${test_result} = "pass" ]
    then
        test_case || test_result="fail"
    fi
    clean_env || test_result="fail"
    [ "${test_result}" = "fail" ] && return 1
}

main $@
ret=$?
#LAVA平台上报结果接口，勿修改
lava-test-case "$test_name" --result ${test_result}
exit ${ret}