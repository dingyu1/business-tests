#!/bin/bash

#=================================================
# Global variable
GLOBAL_BASH_PID=$$
SSH="timeout 1000 sshpass -p root ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
SCP="timeout 1000 sshpass -p root scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

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
    #cat ${tmp_file} | grep "No package * available"  || PRINT_LOG "WARN" "Some of package install fail "
    #PRINT_FILE_TO_LOG "${tmp_file}"
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


fn_install_pkg "gcc" 10
fn_install_pkg "automake" 10
fn_install_pkg "make" 10
fn_install_pkg "netperf" 10
#fn_install_pkg "sshpass" 10
#fn_install_pkg "git" 10


fn_get_os_type distro
#关闭防火墙
case "$distro" in
    centos|redhat)
		systemctl stop firewalld
		systemctl disable firewalld
		;;
	ubuntu|debian)
		apt install ufw -y
		ufw disable
		;;
	suse)
		zypper install -y firewalld
		systemctl stop  firewalld
		systemctl disable firewalld
		;;
esac

function install(){

		#wget http://htsat.vicp.cc:804/liubeijie/netperf-2.5.0.tar.gz;
		tar -zxvf /root/netperf-2.5.0.tar.gz;
		cd netperf-netperf-2.5.0;
		./configure -build=alpha;
		make;make install
		echo
}

#安装netperf
netperf -V || install 
netperf -V 
if [ $? -eq 0 ];then
	echo "pass install"
else
	echo "error install"
fi





