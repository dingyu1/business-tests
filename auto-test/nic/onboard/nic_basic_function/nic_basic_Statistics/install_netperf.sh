#!/bin/bash

source ../../../../../utils/sys_info.sh
source ../../../../../utils/sh-test-lib

#安装依赖包
install_deps "wget gcc automake make sshpass"

#关闭防火墙
case "$distro" in
    centos|redhat)
		systemctl stop firewalld
		;;
	ubuntu|debian)
		apt install ufw -y
		ufw disable
		;;
	suse)
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
