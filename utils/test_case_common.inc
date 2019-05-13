#!/bin/bash

#=================================================
# Global variable
GLOBAL_BASH_PID=$$
SSH="timeout 1000 sshpass -p root ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
SCP="timeout 1000 sshpass -p root scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"


#=================================================

MODULE_NAME="`basename $0 | sed 's/\.sh$//g'`"
ABSOLUATELY_PATH=`pwd`

SCRIPT_PATH="`dirname $0`"
if [ "$SCRIPT_PATH" = "." ]
then
    SCRIPT_PATH=`pwd`
fi



HOME_PATH=`dirname ${SCRIPT_PATH}`
FILENAME=${0##*/}
DATE_PLUS_INFO="`date '+%Y%m%d%H%M%S'`"
RANDOM_INFO="${DATE_PLUS_INFO}${RANDOM}"
LOGPATH="${SCRIPT_PATH}/logs/${MODULE_NAME}"
THELOGFILE="${LOGPATH}/${MODULE_NAME}.log"

TMPDIR=${SCRIPT_PATH}/logs/temp
mkdir -p ${TMPDIR}
TMPFILE=${TMPDIR}/${FILENAME%%.*}.tmp
TMPCFG=${TMPDIR}/${FILENAME%%.*}.tmp_cfg
RESULT_FILE=${TMPDIR}/${FILENAME%%.*}.result

printf "%s %s %-50s %s\n" `date "+[%F %T]"` $0 ${LOGFILE:-${THELOGFILE}} >> /var/bash.trc
[ "`wc -l /var/bash.trc | awk '{ print $1 }'`" -gt 1200 ] && \
sed -i 1,200d  /var/bash.trc


#**************************************************************
# Name:        getSysTime                                     *
# Description: get the system time   2019-01-10 03:52:33      *
#**************************************************************
function fn_getSysTime()
{
    date "+%Y-%m-%d %T"
}


#**************************************************************
# Name:         LOG                                           *
# Description: record the message into the logfile            *
# Inout:  log message                                         *
#**************************************************************
function LOG()
{
    local strTime=`fn_getSysTime`
    local curSize
    local maxSize=10240
    local maxRecord=3
    local index=2
    local content="$*"
    

    if [ -z ${LOGFILE} ]
    then
        echo  -e "[${strTime}] [${GLOBAL_BASH_PID}] ${content}"
    elif [  -f ${LOGFILE} ]
    then
        curSize=`ls -lk ${LOGFILE} | awk -F" " '{print $5}'`
        if [ ${curSize} -ge ${maxSize} ]
        then
            while [ ${index} -gt 0 ]
            do
                if [ -f ${LOGFILE}.${index} ]
                then
                    mv ${LOGFILE}.${index} ${LOGFILE}.`expr ${index} + 1`

                fi
                let index--
            done
            mv ${LOGFILE} ${LOGFILE}.1
        fi
        echo -e  "[${strTime}] [${GLOBAL_BASH_PID}] ${content}" | tee -a ${LOGFILE}    
    else
        mkdir -p `dirname ${LOGFILE}`
        chmod 750 `dirname ${LOGFILE}`
        echo -e "[${strTime}] [${GLOBAL_BASH_PID}] ${content}" | tee -a ${LOGFILE}
    fi
}


#**************************************************************
# Name:        WARN                                           *
# Description: record the warning message into the logfile    *
# Inout:  warning message                                     *
#**************************************************************
function WARN()
{
    LOG "WARN: $*"
}


#**************************************************************
# Name:        ERROR                                          *
# Description: record the error message into the logfile      *
# Inout:  error message                                       *
#**************************************************************
function ERROR()
{
    LOG "ERROR: $*"
}


##*************************************************************
# Name        : PRINT_LOG                                     *
# Description : print log                                     *
# Parameters  : $1 the print level                            *
# Parameters  : $2 the log                                    *
#**************************************************************
function PRINT_LOG()
{
    local LOG_LEVEL=$1
    local LOG_INFO=$2

    if [ -z "${LOGFILE}" ]
    then
        LOGFILE="${THELOGFILE}"
    fi

    case ${LOG_LEVEL} in
        "INFO")
            LOG "${LOG_INFO}"
        ;;
        "WARN")
            WARN "${LOG_INFO}"
        ;;
        "FATAL")
            ERROR "[Line-${BASH_LINENO}] ${LOG_INFO}"
        ;;
        *)
            WARN " The LOG_LEVEL must be <INFO|WARN|FATAL>, it will be set to WARN by default.."
            WARN "${LOG_INFO}"
        ;;
    esac
}
#**************************************************************
# Name        : PRINT_FILE_TO_LOG                             *
# Description : print file content into log file              *
# Parameters  : $1 the file to be printed                     *
#**************************************************************
function PRINT_FILE_TO_LOG()
{
    local FILE_NAME=$1

    if [ -z "${LOGFILE}" ]
    then
        LOGFILE="${THELOGFILE}"
    fi

    if [ -f "${FILE_NAME}" ]
    then
        CHECK_CONTENT=`cat ${FILE_NAME}`
        if [ -z "${CHECK_CONTENT}" ]
        then
            LOG "This file FILE_NAME<${FILE_NAME}> is empty!!!"
            return ${ERR_FILEISNULL};
        else
            LOG "Print <${FILE_NAME}>"
            LOG "`cat \"${FILE_NAME}\" | sed 's/\r//g'`"
        fi
    else
        LOG "This file FILE_NAME<${FILE_NAME}> is not exist!!!"
        return ${ERR_FILEEXIST};
    fi
}


#**************************************************************
#Name         :FUNC_CLEAN_TMP_FILE                            *
#Description  :clean script product tmp_file                  *
#Parameters   :NO                                             *
#**************************************************************
function FUNC_CLEAN_TMP_FILE()
{
    [ -e "${TMP_CONFIG_FILE}" ] && rm -f "${TMP_CONFIG_FILE}" > /dev/null 2>&1
    [ -e "${TMP_CONTENT_FILE}" ]&& rm -f "${TMP_CONTENT_FILE}" > /dev/null 2>&1
    [ -d "${TMP_CONFIG_PATH}" ] && rm -rf "${TMP_CONFIG_PATH}"/tmp* > /dev/null 2>&1
    return 0
}


#*************************************************************
# Name        : fn_get_value                                 *
# Description : get the config from config file              *
# Parameters  : $1 the absoluately path of config file       *
# Parameter   : $2 the key name                              *
#*************************************************************
function fn_get_value()
{
    local TMP_CONFIG_FILE=$1
    local TMP_KEY_NAME=$2
    
    [ ! -f "${TMP_CONFIG_FILE}" ] && { ERROR "The file TMP_CONFIG_FILE<${TMP_CONFIG_FILE}> is not exist" &>/dev/null; return ${ERROR_PARAM}; }   
    cat "${TMP_CONFIG_FILE}" | grep -m1 "^${TMP_KEY_NAME}=" | awk 'BEGIN {FS="="}{print $2}'
    
}


#*************************************************************
# Name        : fn_writeResultFile                           *
# Description : write result to result file                  *
# Parameters  : $1 result file                               *
# Parameter   : $2 the key                                   *
# Parameter   : $3 the value                                 *
#*************************************************************
function fn_writeResultFile()
{
    local RESULT_FILE=$1
    local RESULT_NAME=$2
    local RESULT_VALUE=$3

    if [ $# -ne 3 ]
    then
        ERROR "[fn_writeResultFile]Parameter number is correct."
    fi

    echo -e  "${RESULT_NAME}=${RESULT_VALUE}" | tee -a ${RESULT_FILE}
    if [ $? -ne 0 ]
    then
        ERROR "Failed to write \"${RESULT_NAME}=${RESULT_VALUE}\" to ${RESULT_FILE}."
        return ${ERR_EXECSYS}
    else
        LOG "Success to write \"${RESULT_NAME}=${RESULT_VALUE}\" to ${RESULT_FILE}."
        return 0;
    fi
}

#*************************************************************
# Name        : fn_writeResultFile                           *
# Description : create result file                           *
# Parameters  : $1 result file                               *
#*************************************************************
function fn_checkResultFile()
{
    local RESULT_FILE=$1
    local RESULT_PATH

    if [ ! -f "${RESULT_FILE}" ]
    then
        RESULT_PATH=`dirname "${RESULT_FILE}"`
        if [ ! -d "${RESULT_PATH}" ]
        then
            mkdir -p "${RESULT_PATH}"
        fi
    fi

    rm -f "${RESULT_FILE}"
    touch "${RESULT_FILE}"
    if [ $? -ne 0 ]
    then
        ERROR "FUNC:fn_checkResultFile execute touch command fail."
        return ${ERR_EXECSYS}
    fi

    LOG "Success to create ${RESULT_FILE} file"
    return 0
}


#*************************************************************
#Name         :check result                                  *
#Description  :check test case items result                  *
#Parameters   :result file                                   *
#*************************************************************
function check_result()
{
    result_file=$1
    PRINT_FILE_TO_LOG "${result_file}"
    cat ${result_file} | awk -F"=" '{print $2}' | egrep -v pass
    if [ $? -eq 0 ]
    then
        PRINT_LOG "FATAL" "Test case <${test_name}>  is fail ,please check it !"
        return 1
    else
        PRINT_LOG "INFO" "Test case <${test_name}> is success."
        return 0
    fi
}

#*************************************************************
#Name         :clean tmp file                                *
#Description  :clean script product tmp_file                 *
#Parameters   :NO                                            *
#*************************************************************
function clean_tmp_file()
{
    [ -e "${TMPFILE}" ] && rm -f "${TMPFILE}" > /dev/null 2>&1
    [ -e "${TMPCFG}" ]&& rm -f "${TMPCFG}" > /dev/null 2>&1
    [ -d "${TMPDIR}" ] && rm -rf "${TMPDIR}"/tmp* > /dev/null 2>&1
    return 0
}

#*************************************************************
# Name        : fn_install_pkg                           *
# Description : install different distribution package                  *
# Parameters  : $1 packages                               *
# Parameter   : $2 times                               *
#*************************************************************
fn_install_pkg()
{
    pkgs=$1
    exec_times=$2
    tmp_file=${TMPDIR}/tmp.file
    [ -f ${tmp_file} ] && :>${tmp_file}
    
    os_type=`cat /etc/os-release | grep -w ID | awk -F"=" '{print $2}' | tr '[:upper:]' '[:lower:]'`   
    if [ ${os_type} = \"suse\" ] || [ ${os_type} = "suse" ] || [ ${os_type} = \"sles\" ] || [ ${os_type} = "sles" ]
    then
        os_type=suse
    elif [ ${os_type} = \"ubuntu\" ] || [ ${os_type} = "ubuntu" ]
    then
        os_type=ubuntu
    elif [ ${os_type} = \"redhat\" ] || [ ${os_type} = "redhat" ] || [ ${os_type} = \"rhel\" ] || [ ${os_type} = "rhel" ]
    then
        os_type=redhat
    elif [ ${os_type} = \"centos\" ] || [ ${os_type} = "centos" ] 
    then
        os_type=centos
    elif [ ${os_type} = \"debian\" ] || [ ${os_type} = "debian" ]
    then
        os_type=debian
    fi
    
    echo "os_type=$os_type"
    case "${os_type}" in    
        debian|ubuntu)
        cmd="apt-get install -q -y ${pkgs}"
        fn_exec_times "${cmd}" "${exec_times}" "${tmp_file}"
        ;;
        centos|redhat)
        cmd="yum -e 0 -y install ${pkgs}" 
        fn_exec_times "${cmd}" "${exec_times}" "${tmp_file}"
        ;;
        fedora)
        cmd="dnf -e 0 -y install ${pkgs}"
        fn_exec_times "${cmd}" "${exec_times}" "${tmp_file}"
        ;;
        opensuse|suse)
        cmd="zypper install -y ${pkgs}"
        fn_exec_times "${cmd}" "${exec_times}" "${tmp_file}"
        ;;
        *)
         PRINT_LOG "INFO" "Can not install ${pkg}"
        #echo "Can not install ${pkg}"
        ;;
    esac
    cat ${tmp_file} | grep "No package * available"  || PRINT_LOG "WARN" "Some of package install fail "
    PRINT_FILE_TO_LOG "${tmp_file}"
}

function fn_exec_times()
{
    cmd=$1
    exec_times=$2
    tmp_file=$3
    for i in $( seq $exec_times )
    do
        eval $cmd >> ${tmp_file} 2>&1 && break
    done
    
}

#*************************************************************
# Name        : fn_get_os_type                               *
# Description : get distribution os type                     *
# Parameters  : $1 get os pramater type                      *                            
#*************************************************************
function fn_get_os_type()
{
    os_type=$1
    [ -n "${os_type}" ] || PRINT_LOG "WARN" "Useage:fn_get_os_type os_type "
    os_type=`cat /etc/os-release | grep -w ID | awk -F"=" '{print $2}' | tr '[:upper:]' '[:lower:]'`
    
    if [ ${os_type} = \"suse\" ] || [ ${os_type} = "suse" ] || [ ${os_type} = \"sles\" ] || [ ${os_type} = "sles" ]
    then
        os_type=suse
    elif [ ${os_type} = \"ubuntu\" ] || [ ${os_type} = "ubuntu" ]
    then
        os_type=ubuntu
    elif [ ${os_type} = \"redhat\" ] || [ ${os_type} = "redhat" ] || [ ${os_type} = \"rhel\" ] || [ ${os_type} = "rhel" ]
    then
        os_type=redhat
    elif [ ${os_type} = \"centos\" ] || [ ${os_type} = "centos" ] 
    then
        os_type=centos
    elif [ ${os_type} = \"debian\" ] || [ ${os_type} = "debian" ]
    then
        os_type=debian
    fi
    #echo "os_type=$os_type"
    eval  $1=$os_type
}

#获取插网线的网口
function fn_get_physical_network_card() 
{

    [ -n "$1" ] || PRINT_LOG "Usage:parameter 1 is not none .eg: fn_get_physical_network_card physical_network_interface_list"
    declare -a physical_network_card
    
    network_interface_list=`ip a | grep ^[[:digit:]] | egrep -v "lo|vi|br" | awk -F":" '{print $2}'`
    j=0
    for i in ${network_interface_list}
    do
        ip link set dev ${i} up
        status=`ethtool ${i} | grep "Link detected" | awk -F":" '{print $2}'`
        if [ ${status} = yes ]
        then
            physical_network_card[j]=$i
            let j++
            PRINT_LOG "INFO" "physical_network_card[$j]=$i"
        else
            PRINT_LOG "WARN" "$i status is down"
        fi    
    done
    
    eval $1='${physical_network_card[@]}'

}


