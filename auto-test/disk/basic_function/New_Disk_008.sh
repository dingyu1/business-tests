#!/bin/bash

#*****************************************************************************************
# *用例名称：New_Disk_008                                                        
# *用例功能：硬盘读写文件系统测试-SAS HDD盘                                         
# *作者：fwx654472                                                                       
# *完成时间：2019-1-21                                                                   
# *前置条件：                                                                            
#   硬盘直通状态，硬盘SAS HDD满配 
# *测试步骤：                                                                               
#	1、OS正常运行的情况下，通过fdisk命令将硬盘分区，创建一个非系统分区，文件系统ext4，有结果A)
#	2、使用fio分别对该非系统分区进行读写，有结果B)
# *测试结果：                                                                            
#	A)分区创建成功
#	B)OS正常运行，dmesg中无报错，硬盘可以正常读写                                                 
#*****************************************************************************************

#加载公共函数
. ../../../utils/error_code.inc
. ../../../utils/test_case_common.inc
. ../../../utils/sys_info.sh
. ../../../utils/sh-test-lib     
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
TMPCFG=${TMPDIR}/${test_name}.tmp_cfg
test_result="pass"


cat << EOF > ${TMPCFG}
disk_nums=12
disk_type=sas
cpi_sequence=74:02.0
case_name=New_Disk_008
EOF


fn_del_parttion()
{
    get_disk=$1
    cat <<EOF >${TMPFILE}
d
1


w
EOF
    cat ${TMPFILE} | fdisk ${get_disk}
	
}

fn_new_parttion()
{
    get_disk=$1

cat <<EOF >${TMPFILE}
n
p
1

+50G


w
EOF

    cat ${TMPFILE} | fdisk ${get_disk}
	
}


#预置条件
function init_env()
{
    #检查结果文件是否存在，创建结果文件：
    PRINT_LOG "INFO" "*************************start to run test case<${test_name}>**********************************"
    fn_checkResultFile ${RESULT_FILE}
    fio -h || fn_install_pkg fio 3
    cp ../../../utils/tools/fio ./. || PRINT_LOG "INFO" "cp fio is fail"
    dmesg --clear
}



#测试执行
function test_case()
{
    #测试步骤实现部分
    cpi_sequence=`fn_get_value ${TMPCFG} cpi_sequence`
    dmidecode -t system | grep "Product" | grep "D06"
    if [ $? -eq 0 ]
    then
        lspci -s ${cpi_sequence} -vvv | grep "MSI.*Enable"
        if [ $? -eq 0 ]
        then
            PRINT_LOG "INFO" "Check out MSI Enable lab."
            fn_writeResultFile "${RESULT_FILE}" "MSI" "pass"
        else
            PRINT_LOG "FATAL" "Can not check MSI Enable lab,check it fail"
            fn_writeResultFile "${RESULT_FILE}" "MSI" "fail"
        fi
    else
        PRINT_LOG "INFO" "env is D05 ,skip it test MSI"
    fi


    blk_list=`lsblk -d| grep "disk"| awk '{print $1}'`
    PRINT_LOG "INFO" "blk list is $blk_list"
    
    declare -a bare_disk_list
    j=0
    for i in $blk_list
    do
        lsblk -a  | grep "/" | grep $i
        if [ $? -ne 0 ]
        then
            echo "$i is not system parttion"
            bare_disk_list[j]=$i
            let j++
        else
            echo "$i is used for system parttion "
        fi
    
    done

    
    
    for blk in ${bare_disk_list[@]}
    do
    
        disk=/dev/${blk}
        fn_del_parttion "${disk}"
        fn_new_parttion "${disk}"
        
        fio -filename=${disk} -ioengine=sync -direct=1 -iodepth=128 -rw=randread -bs=4k -size=1G -numjobs=8 -runtime=10 -group_reporting -name=fio_test || ./fio -filename=${disk} -ioengine=sync -direct=1 -iodepth=128 -rw=randread -bs=4k -size=1G -numjobs=8 -runtime=10 -group_reporting -name=fio_test
        if [ $? -eq 0 ]
        then
            PRINT_LOG "INFO" "exec <fio -filename=${disk}> is ok "
             fn_writeResultFile "${RESULT_FILE}" "${disk}" "pass"
        else
            PRINT_LOG "FATAL" "exec <fio -filename=${disk}> is fail"
            fn_writeResultFile "${RESULT_FILE}" "${disk}" "fail"
        fi
        
        tmp_dmesg=$TMPFILE.dmesg
        dmesg > ${tmp_dmesg}
        cat ${tmp_dmesg}| egrep -iw "fail|error|fatal"
        if [ $? -eq 0 ]
        then
            PRINT_LOG "INFO" "exec fio common ,has some issue"
            fn_writeResultFile "${RESULT_FILE}" "${blk}_msg" "fail"
            PRINT_FILE_TO_LOG "${tmp_dmesg}"
        else    
            PRINT_LOG "INFO" "exec fio commond is ok,no exception info "
        fi
        fn_del_parttion "${disk}"
        dmesg --clear        
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
    dmesg --clear
    PRINT_LOG "INFO" "*************************end of running test case<${test_name}>**********************************"
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



