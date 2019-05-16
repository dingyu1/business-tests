#!/bin/bash

distro=""
sys_info=$(cat /etc/os-release | grep PRETTY_NAME)
if [ "$(echo $sys_info |grep -E 'UBUNTU|Ubuntu|ubuntu')"x != ""x ]; then
    distro="ubuntu"
elif [ "$(echo $sys_info |grep -E 'cent|CentOS|centos')"x != ""x ]; then
    distro="centos"
elif [ "$(echo $sys_info |grep -E 'fed|Fedora|fedora')"x != ""x ]; then
    distro="fedora"
elif [ "$(echo $sys_info |grep -E 'DEB|Deb|deb')"x != ""x ]; then
    distro="debian"
elif [ "$(echo $sys_info |grep -E 'SUSE|OpenSuse|opensuse|openSUSE')"x != ""x ]; then
    distro="suse"
elif [ "$(echo $sys_info|grep -E 'redhat|Red')"x != ""x ]; then
    distro="redhat"
else
    distro="ubuntu"
fi

#关闭防火墙
case "$distro" in
    centos|redhat)
		yum install wget gcc automake make sshpass -y
		systemctl stop firewalld
		;;
	ubuntu|debian)
		apt install wget gcc g++ automake make sshpass -y
		apt install ufw -y
		ufw disable
		;;
	suse)
		zypper install -y wget gcc gcc-c++ automake make sshpass 
		zypper install -y firewalld
		systemctl stop  firewalld
		;;
esac

#安装netperf
if [ ! -n "$(which netperf)" ]
then
		
        wget  ${ci_http_addr}/test_dependents/netperf.tar.gz
        tar -zxf netperf.tar.gz && rm -rf netperf.tar.gz
        cd netperf
        ./install_netperf.sh
        cd ../
else
		netper -V
        echo "netperf has been installed"

fi
