#!/bin/bash

#*****************************************************************************************
# *测试内容：长时间收发包测试
# *用例名称：NIC_PERFORMANCE_001
# *用例作者：lwx588815
# *完成时间：2019-1-22
# *前置条件：
#  1、已安装os,两块单板直连
#  2、系统启动后网络正常

# *测试步骤：
#    1、SUT端网口不断ping Server端网口，这个过程中过程中包长逐步递增
#        ping –c 10  –s  0  [Server IP]
#        ping –c 10  –s  256  [Server IP]
#        ping –c 10  –s  512  [Server IP]
#        ping –c 10  –s  777  [Server IP]
#        ping –c 10  –s  1024  [Server IP]
#        ping –c 10  –s  2048 [Server IP]
#        ping –c 10  –s  3478  [Server IP]
#        ping –c 10  –s  6800  [Server IP]
#        ping –c 10  –s  8972  [Server IP]
#        ping –c 10  –s  8973  [Server IP]
#        ping –c 10  –s  9000  [Server IP]
#    2、修改SUT和Server网卡MTU为9000。
#        ifconfig ethx mtu 9000
#    3、SUT 不断ping Server端网口，过程中包长逐步递增
#        ping –c 10  –s  8972  [Server IP]
#        ping –c 10  –s  9000  [Server IP]
#        ping –c 10  –s  10000  [Server IP]
#        ping –c 10  –s  20000  [Server IP]
#        ping –c 10  –s  50000  [Server IP]
#        ping –c 10  –s  60000 [Server IP]
#        ping –c 10  –s  65507  [Server IP]
#    4、SUT端所有网卡遍历以上测试

#测试用例_预期结果
#      1.ifconfig查看，ping包过程中没有丢包和错包
#*****************************************************************************************

#加载公共函数,具体看环境对应的位置修改
. ../../../../utils/error_code.inc
. ../../../../utils/test_case_common.inc
. ../../../../utils/sys_info.sh
. ../../../../utils/sh-test-lib
. ../../../../utils/env_parameter.inc

#获取脚本名称作为测试用例名称
test_name=$(basename $0 | sed -e 's/\.sh//')
#创建log目录
TMPDIR=./logs/temp
mkdir -p ${TMPDIR}
#存放脚本处理中间状态/值等
TMPFILE=${TMPDIR}/${test_name}.tmp
TMPFILE_error_drop="${TMPDIR}/${test_name}.error"
TMPFILE_error_drop1="${TMPDIR}/${test_name}.error1"
#存放每个测试步骤的执行结果
RESULT_FILE=${TMPDIR}/${test_name}.result
test_result="pass"

#************************************************************#
# Name        : distinguish_card                               #
# Description : 区分板载和标卡                              #
# Parameters  : 无                                           #
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
}

#************************************************************#
# Name        : get_tc_ip                               #
# Description : 获取对端ip                               #
# Parameters  : $1=网口
# return value：无              #
#************************************************************#
function get_tc_ip(){
	network=$1
	IP_table=`cat ../../../../../utils/env_parameter.inc`

	debug=false
	if [ $debug = true ];then
	cat << EOF > IP_table.txt
	client_ip_10=192.168.1.3
	client_ip_20=192.168.10.3
	client_ip_30=192.168.20.3
	client_ip_40=192.168.30.3
	#client_ip_50=192.168.50.11
	
	server_ip_10=192.168.1.6
	server_ip_20=192.168.10.6
	server_ip_30=192.168.20.6
	server_ip_40=192.168.30.6
	#server_ip_50=192.168.50.12
EOF
		IP_table=`cat IP_table.txt`
	fi
	
	sut_ip=`ip address show $network |  grep -w inet | awk -F'[ /]+' '{print $3}'`
	tc_ip=`echo $IP_table | sed 's/ /\n/g' | grep -w ${sut_ip%.*} | grep -v $sut_ip | awk -F = '{print $2}'`
	echo $tc_ip
}
#************************************************************#
# Name        : check_error_drop                               #
# Description : 获取对端ip                             #
# Parameters  : $1网口 $2 文件
# return value：ip             #
#************************************************************#
function check_error_drop(){
	net=$1
	file=$2
	ethtool=`ethtool -S $net | egrep "dropped|error" | awk -F : '{print $2}'`
	ip=`ip -s link show $net| egrep -i "rx|tx" -A 1| egrep -iv "rx|tx" | awk '{print $3,$4}'`
	echo $ethtool $ip > $file
}
#************************************************************#
# Name        : ping_test                               #
# Description : ping测试                              #
# Parameters  : $1=网口
# return value：无              #
#************************************************************#
function ping_test(){
	sut_name=$1
	mtu_value=$2
	mtu_9000="8972 9000 10000 20000 50000 60000 65507"
	mtu_1500="0 256 512 777 1024 2048 3478 6800 8972 8973 9000"
	
	tc_ip=$(get_tc_ip $sut_name)
	ping $tc_ip -c 5
	if [ $? -eq 0 ];then
		PRINT_LOG "INFO" "$tc_ip connect properly."
		fn_writeResultFile "${RESULT_FILE}" "${tc_ip}_connect" "pass"
		ip link set dev $sut_name mtu $mtu_value
		sleep 5
		sut_mtu=`cat /sys/class/net/${sut_name}/mtu`
		
		tc_name=`${SSH} root@${tc_ip} ip a | grep $tc_ip | awk '{print $NF}'`
		$SSH root@${tc_ip} ip link set dev $tc_name mtu $mtu_value
		sleep 5
		tc_mtu=`$SSH root@${tc_ip} cat /sys/class/net/${tc_name}/mtu`
		if [ $sut_mtu -eq $tc_mtu ];then
			PRINT_LOG "INFO" "sut mtu is $sut_mtu"
			PRINT_LOG "INFO" "tc mtu is $tc_mtu"
			fn_writeResultFile "${RESULT_FILE}" "${sut_name}_mtu_equal" "pass"
			
			check_error_drop $sut_name $TMPFILE_error_drop
			if [ $mtu_value -eq 9000 ];then
				for i in ${mtu_9000[@]}
				do
					ping ${tc_ip} -c 10 -s $i
					sleep 5
				done
			elif [ $mtu_value -eq 1500 ];then
				for i in ${mtu_1500[@]}
				do
					ping ${tc_ip} -c 10 -s $i
					sleep 5
				done
			else
				PRINT_LOG "INFO" "invalid mtu value"
				return 1
			fi
			check_error_drop $sut_name $TMPFILE_error_drop1
			diff $TMPFILE_error_drop $TMPFILE_error_drop1
			if [ $? -eq 0 ];then
				PRINT_LOG "INFO" "packet normal"
				fn_writeResultFile "${RESULT_FILE}" "check_error_drop" "pass"
				return 1
			else
				PRINT_LOG "FATAL" "packet drop or error"
				fn_writeResultFile "${RESULT_FILE}" "check_error_drop" "fail"
				return 1
			fi
		else
			PRINT_LOG "INFO" "The tc mtu value is not equal to sut"
			fn_writeResultFile "${RESULT_FILE}" "${sut_name}_mtu_equal" "fail"
			return 1
		fi
	else
		PRINT_LOG "FATAL" "$tc_ip connect is not normal."
		fn_writeResultFile "${RESULT_FILE}" "${tc_ip}_connect" "fail"
		return 1
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
	ethtool --version || fn_install_pkg "ethtool" 10
	sshpass -h || fn_install_pkg "sshpass" 10
	distinguish_card
	#board_card=(enp125s0f2)
}




#测试执行
function test_case()
{
	for net in ${board_card[@]}
	do
		ping_test $net 9000
		ping_test $net 1500
	done
	
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
        [ "${test_result}" = "pass" ] || return 1
}

main $@
ret=$?
#LAVA平台上报结果接口，勿修改
lava-test-case "$test_name" --result ${test_result}
exit ${ret}

