#!/bin/bash

#*****************************************************************************************
#用例名称：NIC_ADVANCED_VLAN_003
#用例功能：VLAN配置测试-板载网卡
#作者：qwx655884
#完成时间：20190510
#前置条件
#  需要下载vconfig源码编译
#测试步骤
#  1、 使用vconfig命令配置vlan 在HiNIC0接口上配置两个VLAN 
#  vconfig add HiNIC0 100 
#  vconfig add HiNIC0 200 
#  2、 给HiNIC0接口的两个VLAN配置IP
#  ifconfig HiNIC0.100 192.168.100.50 netmask 255.255.255.0 up 
#  ifconfig HiNIC0.200 192.168.200.50 netmask 255.255.255.0 up 
#  3、 删除VLAN命令 
#  vconfig rem eth0.100 
#  vconfig rem eth0.200 
#  4、遍历所有网口，有结果A)
#测试结果
#  A) VLAN能正常配置。
#*****************************************************************************************

#加载公共函数,具体看环境对应的位置修改
. ../../../../../utils/error_code.inc
. ../../../../../utils/test_case_common.inc
. ../../../../../utils/sys_info.sh
. ../../../../../utils/sh-test-lib
. ../../../../../utils/env_parameter.inc

#. ./error_code.inc
#. ./test_case_common.inc

#获取脚本名称作为测试用例名称
test_name=$(basename $0 | sed -e 's/\.sh//')
#创建log目录
TMPDIR=./logs/temp
mkdir -p ${TMPDIR}
#存放脚本处理中间状态/值等
TMPFILE=${TMPDIR}/${test_name}.tmp
TMPFILE1=${TMPDIR}/${test_name}.tmp
TMPFILE2=${TMPDIR}/${test_name}.tmp
TMPFILE3=${TMPDIR}/${test_name}.tmp
TMPFILE4=${TMPDIR}/${test_name}.tmp
TMPFILE5=${TMPDIR}/${test_name}.tmp
TMPFILE6=${TMPDIR}/${test_name}.tmp
#存放每个测试步骤的执行结果
RESULT_FILE=${TMPDIR}/${test_name}.result

#自定义变量区域（可选）
#var_name1="xxxx"
#var_name2="xxxx"
test_result="pass"


#************************************************************#
# Name        : distinguish_card                               #
# Description : 区分板载和标卡                               #
# Parameters  : 无
# return value：onboard_fibre_card[]   standard_card[]              #
#************************************************************#
function distinguish_card(){
    #查找所有物理网卡
	fn_get_physical_network_card total_network_cards
	total_network_cards=(`echo ${total_network_cards[@]}`)
    for ((i=0;i<${#total_network_cards[@]};i++))
    do
        driver=`ethtool -i ${total_network_cards[i]} | grep driver | awk '{print $2}'`
        if [ "$driver" == "hns" -o "$driver" == "hns3" ];then
            board_card[i]=${total_network_cards[i]}
            board_card=(`echo ${board_card[@]}`)
        else
            standard_card[i]=${total_network_cards[i]}
            standard_card=(`echo ${standard_card[@]}`)
        fi
    done
    echo ${board_card[@]}
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
       distinguish_card
  
}

#测试执行
function test_case()
{   vlan_ip1=192.168.20.13
    vlan_ip2=192.168.30.13 
 for net in ${board_card[@]}
    do
	 #添加第一个vlan
       ip link add dev ${net}.10 link $net type vlan id 10 >$TMPFILE1 2>&1
       if [ $? -eq 0 ];then
	     ip a|grep ${net}.10
		  if [ $? -eq 0 ];then
         PRINT_LOG "INFO" "${net}.10 add success"
         fn_writeResultFile "${RESULT_FILE}" "${net}.10 add vlan first" "pass"
       else
         a=`cat $TMPFILE1`
         PRINT_LOG "FATAL" "$a"
         fn_writeResultFile "${RESULT_FILE}" "${net}.10 add vlan first" "fail"
		  fi
       fi
	  #给第一个vlan添加ip
	  ifconfig ${net}.10 $vlan_ip1 netmask 255.255.255.0 up >$TMPFILE2 2>&1
       if [ $? -eq 0 ];then
	     ip a|grep $vlan_ip1
		  if [ $? -eq 0 ];then
         PRINT_LOG "INFO" "${net}.10 add ip success"
         fn_writeResultFile "${RESULT_FILE}" "${net}.10 add ip first" "pass"
       else
         b=`cat $TMPFILE2`
         PRINT_LOG "FATAL" "$b"
         fn_writeResultFile "${RESULT_FILE}" "${net}.10 add ip first" "fail"
		  fi
       fi  
	  #添加第二个vlan
         ip link add dev ${net}.20 link $net type vlan id 20 >$TMPFILE3 2>&1
       if [ $? -eq 0 ];then
	     ip a|grep ${net}.10
		  if [ $? -eq 0 ];then
         PRINT_LOG "INFO" "${net}.20 add success"
         fn_writeResultFile "${RESULT_FILE}" "${net}.20 add vlan second" "pass"
       else
         c=`cat $TMPFILE3`
         PRINT_LOG "FATAL" "$c"
         fn_writeResultFile "${RESULT_FILE}" "${net}.20 add vlan second" "fail"
		  fi
       fi
	  #给第二个vlan添加ip
	  ifconfig ${net}.20 $vlan_ip2 netmask 255.255.255.0 up >$TMPFILE4 2>&1
       if [ $? -eq 0 ];then
	     ip a|grep $vlan_ip2
		  if [ $? -eq 0 ];then
         PRINT_LOG "INFO" "${net}.20 add ip success"
         fn_writeResultFile "${RESULT_FILE}" "${net}.20 add ip second" "pass"
       else
         d=`cat $TMPFILE4`
         PRINT_LOG "FATAL" "$d"
         fn_writeResultFile "${RESULT_FILE}" "${net}.20 add ip second" "fail"
		  fi
       fi
	 #删除第一个vlan
	  ip link del dev ${net}.10 >$TMPFILE5 2>&1
       if [ $? -eq 0 ];then
         PRINT_LOG "INFO" "${net}.10 del success"
         fn_writeResultFile "${RESULT_FILE}" "${net}.10 del vlan first" "pass"
       else
         e=`cat $TMPFILE5`
         PRINT_LOG "FATAL" "$e"
         fn_writeResultFile "${RESULT_FILE}" "${net}.10 del vlan first" "fail"
       fi
	 #删除第二个vlan
	  ip link del dev ${net}.20 >$TMPFILE6 2>&1
       if [ $? -eq 0 ];then
         PRINT_LOG "INFO" "${net}.20 del success"
         fn_writeResultFile "${RESULT_FILE}" "${net}.20 del vlan second" "pass"
       else
         f=`cat $TMPFILE6`
         PRINT_LOG "FATAL" "$f"
         fn_writeResultFile "${RESULT_FILE}" "${net}.20 del vlan second" "fail"
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









