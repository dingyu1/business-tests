#!/bin/bash

#*****************************************************************************************
# *用例名称：Performance2_026                                                    
# *用例功能：Mellanox 25G网卡二光口小包（10G）                                                 
# *作者：mwx612683                                                                       
# *完成时间：2019-2-27                                                                   
# *前置条件：                                                                            
#1 两台物理机host1和host2，分别用作TAS端和SUT端
#2 两台物理机Mellanox 25G网卡二光口使用10G光模块连接同交换机
#                                                                  
# *测试步骤：                                                                               
#1、在TAS端执行命令netserver
#2、在SUT端执行如下命令，记录测试结果：
#pkt_length取10240/60140 
#netperf -H <Server IP> -t UDP_STREAM –l 30 -- -m pkt_length –M pkt_length
#     
# *测试结果：                                                                            
#使用ifconfig ethx 和ethtool –S ethx查看网卡统计没有丢包和错包，测试结果数据在正常范围内：
#10000M网卡吞吐量高于8000Mb/s"
#                                                         
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
TMPFILE_error_drop="${TMPDIR}/${test_name}.error"
TMPFILE_error_drop1="${TMPDIR}/${test_name}.error1"
TMPFILE_netperf_log="${TMPDIR}/${test_name}.log"
TMPFILE_netperf_log1="${TMPDIR}/${test_name}.log1"
standard=8000
time=60
netperf="../../../../utils/tools/netperf-2.5.0.tar.gz"
env_parameter="../../../../utils/env_parameter.inc"
netperf_sh="netperf.sh"

#存放每个测试步骤的执行结果
RESULT_FILE=${TMPDIR}/${test_name}.result

#自定义变量区域（可选）
#var_name1="xxxx"
#var_name2="xxxx"
test_result="pass"

#sut_ip_172=$env_sut_on_board_fiber_0
#tc_ip_172=$env_tc_on_board_fiber_0

#************************************************************#
# Name        : distinguish_card                               #
# Description : 区分板载和标卡                               #
# Parameters  : 无
# return value：mellanox网卡名              #
#************************************************************#
function distinguish_card(){
   fn_get_physical_network_card total_network_cards
   total_network_cards=(`echo ${total_network_cards[@]}`)
   num=${#total_network_cards[i]}
   speed="10000"
   driver="mlx5"

   for ((i=0;i<${#total_network_cards[@]};i++))
    do
        #driver=`ethtool -i ${total_network_cards[i]} | grep driver | awk '{print $2}'`
		ethtool -i ${total_network_cards[i]} | grep -i "driver" | grep $driver
        #if [ "$driver" == "mlx5_core" ];then
		if [ $? -eq 0 ];then
			ethtool ${total_network_cards[i]} | grep -i "Speed" | grep $speed
			if [ $? -eq 0 ];then
				mellanox_card[i]=${total_network_cards[i]}
				mellanox_card=(`echo ${mellanox_card[@]}`)
			else
				PRINT_LOG "FATAL" "This ${total_network_cards[i]} speed is not $speed, skip test"
				exit 1
			fi
        else
            PRINT_LOG "INFO" "This ${total_network_cards[i]} is not Mellanox"
        fi
    done

	#if [ -z  ${mellanox_card[@]}  ];then
	#	PRINT_LOG "FATAL" "This environment not have Mellanox card, skip test"
	#	exit 1
	#fi
	
	network=${mellanox_card[1]}
	echo ---------
	echo "network name" $network
	echo ---------
}
#************************************************************#
# Name        : net_prepare                               #
# Description : 绑中断                               #
# Parameters  : 无
# return value：start_cpu   end_cpu            #
#************************************************************#
function net_prepare(){
	net=$1
	systemctl stop irqbalance
	systemctl disable irqbalance
	numactl -H || fn_install_pkg "numactl" 10
	bus=`ethtool -i $net | grep bus-info | awk '{print $2}'`
	numa_node=`lspci -s $bus -vv | grep "NUMA node" | awk '{print $NF}'`	
	cpu=`numactl -H|grep cpus | grep "node $numa_node"|awk -F ':' '{print $2 }'`
	
	a=`echo $cpu | awk '{print $1}'`
	start_cpu=$a
	b=`echo $cpu | awk '{print $NF}'`
	end_cpu=$b

	#cat /proc/interrupts| awk '{print $1,$NF}'|grep -i $net | cut -d ":" -f 1
	interrupts=(`cat /proc/interrupts| awk '{print $1,$NF}'|grep -i $net | cut -d ":" -f 1`)
	for k in ${interrupts[@]}
	do
		echo $k
		echo "$a" > /proc/irq/$k/smp_affinity_list
		cat /proc/irq/$k/smp_affinity_list
		if [ $a -eq $b ];then
			a=$start_cpu
		else
			let a++
		fi
	done
	echo ---------
	echo "start cpu" $start_cpu
	echo "end cpu" $end_cpu
	echo ---------
}
#************************************************************#
# Name        : get_remote_ip                               #
# Description : 获取对端ip                             #
# Parameters  : $1 网口名
# return value：local_ip   remote_ip           #
#************************************************************#
function get_remote_ip(){
	net=$1
	IP_table=`cat $env_parameter`

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
	
	local_ip=`ip address show $net |  grep -w inet | awk -F'[ /]+' '{print $3}'`
	remote_ip=`echo $IP_table | sed 's/ /\n/g' | grep -w ${local_ip%.*} | grep -v $local_ip | awk -F = '{print $2}'`
	ping $remote_ip -c 5
	sleep 5
	echo ---------
	echo "local ip" $local_ip
	echo "remote ip" $remote_ip
	echo ---------
}


#判断有无错包，丢包，两次查询检查差值
#服务端使用ethtool -S检查丢包或错包
#服务端使用ifconfig检查丢包或错包
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

#预置条件
function init_env()
{
  #检查结果文件是否存在，创建结果文件：
	fn_checkResultFile ${RESULT_FILE}
	#自定义测试预置条件检查实现部分：比如工具安装，检查多机互联情况，执行用户身份 
	  #需要安装工具，使用公共函数install_deps，用法：install_deps "${pkgs}"
	  #需要日志打印，使用公共函数PRINT_LOG，用法：PRINT_LOG "INFO|WARN|FATAL" "xxx"
	#...
    #root用户执行
    if [ `whoami` != 'root' ]
    then
        PRINT_LOG "WARN" " You must be root user " 
        return 1
    fi

	ethtool -h || fn_install_pkg "ethtool" 10
	sshpass -h || fn_install_pkg "sshpass" 10
	cp $netperf /root/
	bash $netperf_sh | grep pass
	if [ $? -eq 0 ];then
		PRINT_LOG "INFO" "sut prot netserver insatll pass"
		fn_writeResultFile "${RESULT_FILE}" "sut_netperf_install" "pass"
	else
		PRINT_LOG "INFO" "sut prot netserver insatll pass"
		fn_writeResultFile "${RESULT_FILE}" "sut_netperf_install" "pass"
	fi
	
	distinguish_card
	#network=enp125s0f1
	net_prepare $network
	get_remote_ip $network
	#local_ip=192.168.10.3
	#remote_ip=192.168.10.6
	
	
	$SCP $netperf root@$remote_ip:/root/
	$SSH root@$remote_ip "ls /root/${netperf##*\/}"
	if [ $? -eq 0 ];then
		PRINT_LOG "INFO" "transport netperf.tar.gz success"
		fn_writeResultFile "${RESULT_FILE}" "transport_netperf_tar" "pass"
		$SCP $netperf_sh root@$remote_ip:/root/
		$SSH root@$remote_ip "ls /root/$netperf_sh"
		if [ $? -eq 0 ];then
			PRINT_LOG "INFO" "transport netperf.sh success"
			fn_writeResultFile "${RESULT_FILE}" "transport_netperf_sh" "pass"
			$SSH root@$remote_ip "bash /root/$netperf_sh" | grep pass 
			if [ $? -eq 0 ];then
				PRINT_LOG "INFO" "tc prot netserver insatll pass"
				fn_writeResultFile "${RESULT_FILE}" "tc_netperf_install" "pass"
				$SSH root@$remote_ip "pkill netserver; netserver"
				$SSH  root@$remote_ip  ps -ef | grep -v "grep --color=auto" | grep netserver
				if [ $? -eq 0 ];then
					PRINT_LOG "INFO" "tc prot netserver start pass"
					fn_writeResultFile "${RESULT_FILE}" "tc_netserver_start" "pass"
				else
					PRINT_LOG "FATAL" "tc port netserver start fail"
					fn_writeResultFile "${RESULT_FILE}" "tc_netserver_start" "pass"
				fi
			else
				PRINT_LOG "INFO" "tc prot netserver insatll pass"
				fn_writeResultFile "${RESULT_FILE}" "tc_netperf_install" "pass"
			fi
		else
			PRINT_LOG "INFO" "transport netperf.sh fail"
			fn_writeResultFile "${RESULT_FILE}" "transport_netperf_sh" "pass"
		fi
	else
		PRINT_LOG "INFO" "transport netperf.tar.gz success"
		fn_writeResultFile "${RESULT_FILE}" "transport_netperf_tar" "pass"
	fi
}

#测试执行
function test_case()
{
	#测试步骤实现部分
    #需要日志打印，使用公共函数PRINT_LOG，用法：PRINT_LOG "INFO|WARN|FATAL" "xxx"
	  #记录每项测试结果，使用公共函数fn_writeResultFile，用法：fn_writeResultFile "${RESULT_FILE}" "test_item_name" "pass|fail"
	#...
	#检查结果文件，根据测试选项结果，有一项为fail则修改test_result值为fail，
	
	# *测试步骤：                                                                               
#1、在TAS端执行命令netserver
#2、在SUT端执行如下命令，记录测试结果：
#pkt_length取10240/60140 
#netperf -H <Server IP> -t UDP_STREAM –l 30 -- -m pkt_length –M pkt_length
#     
# *测试结果：                                                                            
#使用ifconfig ethx 和ethtool –S ethx查看网卡统计没有丢包和错包，测试结果数据在正常范围内：
#10000M网卡吞吐量高于8000Mb/s"


#numa节点1

	check_error_drop $network $TMPFILE_error_drop
	taskset -c `expr $end_cpu + 1` netperf -H $remote_ip -L $local_ip -t UDP_STREAM -l $time -- -m 10240 | tee $TMPFILE_netperf_log  &
	taskset -c `expr $end_cpu + 2` netperf -H $remote_ip -L $local_ip -t UDP_STREAM -l $time -- -m 10240 | tee $TMPFILE_netperf_log1 &
	sleep $time
	sleep 5
	check_error_drop $network $TMPFILE_error_drop1
	diff $TMPFILE_error_drop $TMPFILE_error_drop1
	if [ $? -eq 0 ];then
		PRINT_LOG "INFO" "packet normal"
		fn_writeResultFile "${RESULT_FILE}" "check_error_drop" "pass"
	else
		PRINT_LOG "FATAL" "packet drop or error"
		fn_writeResultFile "${RESULT_FILE}" "check_error_drop" "fail"
		return 1
	fi
	
	result=`cat $TMPFILE_netperf_log | sed -n '6p' | awk '{print $NF}'`
	result1=`cat $TMPFILE_netperf_log1 | sed -n '6p' | awk '{print $NF}'`
	echo ---------
	echo "netperf test result" $result
	echo "netperf test result1" $result1
	echo ---------
	#sum=`echo $result + $result1 | bc`
	if [ `echo $result + $result1 | bc` \> ${standard} ];then
		PRINT_LOG "INFO" "Throughput up to standard "
		fn_writeResultFile "${RESULT_FILE}" "${network}_Throughput_${standard}" "pass"
	else
		PRINT_LOG "FATAL" "Throughput is below standard "
		fn_writeResultFile "${RESULT_FILE}" "${network}_Throughput_${standard}" "fail"
	fi
	
	check_result ${RESULT_FILE}
}

#恢复环境
function clean_env()
{
	#清除临时文件
	FUNC_CLEAN_TMP_FILE
	#自定义环境恢复实现部分,工具安装不建议恢复
	  #需要日志打印，使用公共函数PRINT_LOG，用法：PRINT_LOG "INFO|WARN|FATAL" "xxx"
	#...
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
