#!/bin/bash

#*****************************************************************************************
# *用例名称：X6000_NUMA_001                                                         
# *用例功能：NUMA节点测试                                                
# *作者：lwx637528                                                              
# *完成时间：2019-1-22                                                                   
# *前置条件：     
#       已安装OS
# *前置条件：                                                                   
#   1、配置yum源，安装numactl命令
#   2、numactl –H查看NUMA节点情况
#  
# *测试结果：                                                                            
#   A)、可见4个NUMA节点，每个节点下16（D05）/24个核（D06）                                                       
#*****************************************************************************************


#加载公共函数
. ../../../../utils/error_code.inc
. ../../../../utils/test_case_common.inc
. ../../../../utils/sys_info.sh
. ../../../../utils/sh-test-lib

#. ./error_code.inc
#. ./test_case_common.inc
#获取脚本名称作为测试用例名称
test_name=$(basename $0 | sed -e 's/\.sh//')
#创建log目录
TMPDIR=./logs/temp
mkdir -p ${TMPDIR}
#存放脚本处理中间状态/值等
TMPFILE=${TMPDIR}/${test_name}.tmp
#存放每个测试步骤的执行结果
RESULT_FILE=${TMPDIR}/${test_name}.result

#自定义变量区域（可选）
#var_name1="xxxx"
#var_name2="xxxx"
test_result="pass"
#************************************************************#
# Name        : check_numa_cpu                                        #
# Description : 查询每个节点cpu的个数                                #
# Parameters  : 无           #
#************************************************************#
function check_numa_cpu(){	
	numa_node_nums=`numactl -H| head -1 |awk '{print $2}'`
	cpu_nums=`lscpu | grep -i "^CPU(s):" |awk '{print $2 }'`
	average_cpu_nums=`expr $cpu_nums / $numa_node_nums`
	if [ ${numa_node_nums} -eq 4 ]
	then
		PRINT_LOG "INFO" "numa nodes are 4"
		fn_writeResultFile "${RESULT_FILE}" "node_4" "pass"		
		for i in `seq ${numa_node_nums}`
		do
			per_node_nums=$(numactl -H|grep cpus|sed -n "$i p" |awk -F ':' '{print $2 }'|wc -w)
			if [ ${average_cpu_nums} -eq ${per_node_nums} ]
			then
				PRINT_LOG "INFO" " per node ${per_node_nums} success"
				fn_writeResultFile "${RESULT_FILE}" "${i}_per_node_nums" "pass"
			else
				PRINT_LOG "FATAL" " per node ${per_node_nums} error "
				fn_writeResultFile "${RESULT_FILE}" "${i}_per_node_nums" "fail"
				return 1
			fi
		done
	else
		numactl -H
		PRINT_LOG "FATAL" "numa nodes are not 4"
		fn_writeResultFile "${RESULT_FILE}" "node_4" "fail"	
	fi	
}

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
    numactl -H || fn_install_pkg "numactl" 10
}

#测试执行
function test_case()
{
    #测试步骤实现部分
    #需要日志打印，使用公共函数PRINT_LOG，用法：PRINT_LOG "INFO|WARN|FATAL" "xxx"
    #记录每项测试结果，使用公共函数fn_writeResultFile，用法：fn_writeResultFile "${RESULT_FILE}" "test_item_name" "pass|fail"
    	
	check_numa_cpu
	
    #检查结果文件，根据测试选项结果，有一项为fail则修改test_result值为fail，
    check_result ${RESULT_FILE}
}

#恢复环境
function clean_env()
{
    #清除临时文件
    FUNC_CLEAN_TMP_FILE
    #自定义环境恢复实现部分,工具安装不建议恢复
    #需要日志打印，使用公共函数PRINT_LOG，用法：PRINT_LOG "INFO|WARN|FATAL" "xxx"  
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

