#!/bin/bash

#用例名称：NIC_PERFORMANCE_003                 
#用例功能：内置电口1文件传输检查
#作者：fwx654472                            
#完成时间：2019-1-22                        
#前置条件：                                 
#1 D06服务器使用第一个电口连接交换机
#2 交换机与其他同一网段的机器连接          
#测试步骤：                                 
#1 登陆D06服务操作系统
#2 使用scp命令从其他同网段的机器上获取文件
#测试结果：
#1 通过服务器上两个电口可以从内网同一网段的机器获取文件
#######################################################################
#加载公共函数,具体看环境对应的位置修改

. ../../../../utils/error_code.inc
. ../../../../utils/test_case_common.inc
. ../../../../utils/env_parameter.inc
. ../../../../utils/sys_info.sh
. ../../../../utils/sh-test-lib     

#. ./error_code.inc
#. ./test_case_common.inc
#. ./env_parameter.inc

#获取脚本名称作为测试用例名称
test_name=$(basename $0 | sed -e 's/\.sh//')
#创建log目录
TMPDIR=./logs/temp
mkdir -p ${TMPDIR}
#存放脚本处理中间状态/值等
TMPDIR=${TMPDIR}/${test_name}.tmp
#存放每个测试步骤的执行结果
RESULT_FILE=${TMPDIR}/${test_name}.result

#自定义变量区域（可选）
#var_name1="xxxx"
#var_name2="xxxx"
test_result="pass"
testcount=3
debug=false
#client_ip_0=$env_sut_on_board_fiber_0
#client_ip_10=$env_sut_on_board_fiber_10
sut_on_board_TP_20=$env_sut_on_board_TP_20
#client_ip_30=$env_sut_on_board_TP_30
#client_ip_40=$env_sut_external_network_card_40
#client_ip_50=$env_sut_external_network_card_50
#server_ip_0=$env_tc_on_board_fiber_0
#server_ip_10=$env_tc_on_board_fiber_10
tc_on_board_TP_20=$env_tc_on_board_TP_20
#server_ip_30=$env_tc_on_board_TP_30
#server_ip_40=$env_tc_external_network_card_40
#server_ip_50=env_tc_external_network_card_50

password=$env_tc_passwd

if [ $debug = true ];then
	#sut 本端，tc对端
	#client_ip_0=192.168.1.3
	#client_ip_10=192.168.10.3
	sut_on_board_TP_20=192.168.20.3
	#client_ip_30=192.168.30.3
	#client_ip_50=192.168.50.11
	
	#server_ip_0=192.168.1.6
	#server_ip_10=192.168.10.6
	tc_on_board_TP_20=192.168.20.6
	#server_ip_30=192.168.30.6
	#server_ip_50=192.168.50.12
	testcount=3
	#password=root
fi


SCP="sshpass -p $password scp -o StrictHostKeyChecking=no"
SSH="sshpass -p $password ssh -o StrictHostKeyChecking=no"
#***********************************************************t*
# Name        : file_transport_test                        #
# Description : 文件传输测试                                #
# Parameters  : 无
# return      : 无                                      #
#************************************************************#
function file_transport_test(){
    
    dd if=/dev/zero of=/root/testfile bs=1M count=2048
    sync
    sync
    md5_testfile=`md5sum /root/testfile |awk '{print $1}'`  
    PRINT_LOG "INFO" "md5_testfile<$md5_testfile>"    
    $SCP /root/testfile root@${tc_on_board_TP_20}:/root/testfile1
    if [ $? -eq 0 ]
    then
        PRINT_LOG "INFO" "file copy success from port $sut_on_board_TP_20 to ${tc_on_board_TP_20}"
        fn_writeResultFile "${RESULT_FILE}" "copy_file_to_${tc_on_board_TP_20}" "pass"
    else
        PRINT_LOG "FATAL" "copy file error, please check your network"
		PRINT_LOG "FATAL" "$SCP /root/testfile root@${tc_on_board_TP_20}:/root/testfile1"
        fn_writeResultFile "${RESULT_FILE}" "copy_file_to_${tc_on_board_TP_20}" "fail"
		return 1
    fi
    sync
    sync
	
	    $SCP root@${tc_on_board_TP_20}:/root/testfile1 /root/testfile2 
    if [ $? -eq 0 ]
    then
        PRINT_LOG "INFO" "file copy success from port ${tc_on_board_TP_20} to $sut_on_board_TP_20"
        fn_writeResultFile "${RESULT_FILE}" "copy_file_to_$sut_on_board_TP_20" "pass"
    else
        PRINT_LOG "FATAL" "copy file error, please check your network"
		PRINT_LOG "FATAL" "$SCP root@${tc_on_board_TP_20}:/root/testfile1 /root/testfile2"
        fn_writeResultFile "${RESULT_FILE}" "copy_file_to_$sut_on_board_TP_20" "fail"
		return 1
    fi
    sync
    sync
    md5_testfile2=`md5sum /root/testfile2 |awk '{print $1}'`
    PRINT_LOG "INFO" "md5_testfile2<$md5_testfile2>"    
    if [ "${md5_testfile}" = "${md5_testfile2}" ]
    then
        PRINT_LOG "INFO" "md5_testfile=${md5_testfile}-----md5_testfile2=${md5_testfile2} "
        fn_writeResultFile "${RESULT_FILE}" "md5value" "pass"
    else
        PRINT_LOG "FATAL" "md5_testfile=${md5_testfile}-----md5_testfile2=${md5_testfile2} ,two value is not equal please check it . "
        fn_writeResultFile "${RESULT_FILE}" "md5value" "fail"
		return 1
    fi
}

function sshpas_compile()
{
    sshpass -h
    if [ $? -eq 0 ];then
        PRINT_LOG "INFO" "sshpass is installed"
        fn_writeResultFile "${RESULT_FILE}" "sshpass_install" "pass"
    else
        cp -r ../../../../utils/tools/sshpass.tar.gz .
        for n in {1..5}
        do
            tar -zxvf sshpass.tar.gz
            chmod 755 -R sshpass && cd sshpass && ./configure && sync && make && make install
            cd ..
            rm -rf sshpass sshpass.tar.gz
            sshpass -h
             if [ $? -eq 0 ];then
                #PRINT_LOG "INFO" "sshpass install pass"
                #fn_writeResultFile "${RESULT_FILE}" "sshpass_install" "pass"
                break
                else
                #PRINT_LOG "FATAL" "sshpass install fail"
                #fn_writeResultFile "${RESULT_FILE}" "sshpass_install" "fail"
                continue
            fi
        done
        sshpass -h
        if [ $? -ne 0 ]
        then
        fn_install_pkg "sshpass" 3
        fi
        sshpass -h
        if [ $? -eq 0 ]
        then
            PRINT_LOG "INFO" "sshpass install pass"
            return 0
        else
            PRINT_LOG "FATAL" "sshpass install fail"
            return 1
        fi

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
    sshpass -h
   if [ $? -ne 0 ]
   then
        for i in gcc make g++ gcc-c++
        do
        fn_install_pkg $i 3
        sleep 2
        done
       sshpas_compile
   fi
    #自定义测试预置条件检查实现部分：比如工具安装，检查多机互联情况，执行用户身份 
      #需要安装工具，使用公共函数install_deps，用法：install_deps "${pkgs}"
      #需要日志打印，使用公共函数PRINT_LOG，用法：PRINT_LOG "INFO|WARN|FATAL" "xxx"
}

#测试执行
function test_case()
{
    #测试步骤实现部分

    for ((i=1;i<=$testcount;i++))
    do
        file_transport_test 
    done

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
    rm -f /root/testfile*
    #$SSH root@$server_ip_10 "rm -f /root/testfile*"
	$SSH root@$tc_on_board_TP_20 "rm -f /root/testfile*"

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

