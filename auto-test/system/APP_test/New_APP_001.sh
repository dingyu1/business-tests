#!/bin/bash

#*****************************************************************************************
# *用例名称：Spark测试                                                         
# *用例功能：                                                 
# *作者：swx562878                                                                       
# *完成时间：2019-3-25                                                                   
# *前置条件：                                                                            
#   1、已经安装系统，系统没有异常                                                                   
# *测试步骤：                                                                               
#   1、 安装spark，安装方法参考下面链接http://3ms.huawei.com/km/blogs/details/5475671                                                               
#   2、 运行$ ./spark-shell，然后输入以下信息，有结果A) 然后输入如下信息：                    
#       scala> val days = List("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday")
#		days: List[java.lang.String] = List(Sunday, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday)
#		scala> val daysRDD = sc.parallelize(days)
#		daysRDD: spark.RDD[java.lang.String] = ParallelCollectionRDD[0] at  parallelize at <console>:14
#		scala> daysRDD.count()
#	3、 运行以下Run脚本，有结果B)
#		$./bin/run-example org.apache.spark.examples.SparkPi 。      
# *测试结果：                                                                            
#   A)在经过一系列计算后，显示如下信息：
#	res0: Long = 7
#	B)计算结果如下：
#	Pi is roughly 3.1444                                                         
#*****************************************************************************************

#加载公共函数
. ../../../utils/test_case_common.inc
. ../../../utils/error_code.inc
. ../../../utils/sys_info.sh
. ../../../utils/sh-test-lib		

#获取脚本名称作为测试用例名称
test_name=$(basename $0 | sed -e 's/\.sh//')
#创建log目录

logpath=`pwd`
TMPDIR=${logpath}/logs/temp
mkdir -p ${TMPDIR}
#存放脚本处理中间状态/值等
TMPFILE=${TMPDIR}/${test_name}.tmp
#存放每个测试步骤的执行结果
RESULT_FILE=${TMPDIR}/${test_name}.result
test_result="pass"

#自定义变量区域（可选）
#var_name1="xxxx"
#var_name2="xxxx"
version='3.1.1'
testhome=/usr/local
localhost=$(ip addr |grep brd |grep inet |awk '{print $2}'|awk -F '/' '{print $1}'|grep "172.19")
spark=${testhome}/spark/spark-2.4.0-bin-hadoop3.1

#自定义函数区域（可选）
#function xxx()
#	{}

function install_jdk()
{
	if [ ! -d "/usr/lib/jvm/java-1.8.0-openjdk" ];then
		mkdir -p /usr/lib/jvm
		cd /usr/lib/jvm
		wget -c -q  --no-check-certificate  http://172.19.20.15:8083/perform_depends/test_dependent/spark/jdk-8u161-linux-arm64.tar.gz
		tar -xf jdk-8u161-linux-arm64.tar.gz
		mv /usr/lib/jvm/jdk1.8.0_161  /usr/lib/jvm/java-1.8.0-openjdk
		cd -
	else
		echo ""
	fi
	cp /etc/profile /etc/profile1
	sed -i "/JAVA_HOME/d" ~/.bashrc
    grep -rn "JAVA_HOME=" /etc/profile
    if [ $? == 1 ];then
        echo "JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk" >> /etc/profile
    else
        sed -i 's/JAVA_HOME=.*/JAVA_HOME=\/usr\/lib\/jvm\/java-1.8.0-openjdk/g' /etc/profile
    fi

    grep -rn "PATH=" /etc/profile
    if [ $? == 1 ];then
       echo "PATH=$PATH:$JAVA_HOME/bin" >> /etc/profile
    else
       sed -i 's/PATH=.*/PATH=$PATH:$JAVA_HOME\/bin/g' /etc/profile
    fi

    grep -rn "export" /etc/profile
    if [ $? == 1 ];then
       echo "export $JAVA_HOME $PATH" >> /etc/profile
    else
       sed -i 's/export.*/export $JAVA_HOME $PATH/g' /etc/profile
    fi

    source /etc/profile
    jps > /dev/null

}

function install_hadoop()
{
	if [ -d "$testhome/hadoop" ];then
		rm -rf ${testhome}/hadoop
		mkdir -p ${testhome}/hadoop
	else
		mkdir -p ${testhome}/hadoop
	fi
	
	cd ${testhome}/hadoop
	echo "download hadoop,Please wait... "
	wget -c -q -O hadoop-${version}.tar.gz --no-check-certificate  http://172.19.20.15:8083/perform_depends/test_dependent/spark/hadoop-${version}.tar.gz
	tar -xf hadoop-${version}.tar.gz
	
	pushd hadoop-${version}
	
	sed -i "s/\/home\/wuanjun\/installed\/java\/jdk1.8.0_161/\/usr\/lib\/jvm\/java-1.8.0-openjdk/g" etc/hadoop/hadoop-env.sh
	sed -i "s/\/home\/wuanjun\/installed/\/usr\/local/g" etc/hadoop/hadoop-env.sh
	sed -i "s/export HADOOP_PID_DIR=\/hadoop/export HADOOP_PID_DIR=\/data/g" etc/hadoop/hadoop-env.sh	
	
	grep HADOOP_HOME ~/.bashrc 
	if [ $? -eq 0 ];then
		sed -i "/HADOOP_HOME/d" ~/.bashrc	
	fi

	HADOOPHOME='/usr/local/hadoop/hadoop-3.1.1'
	grep -rn "HADOOP_HOME=" /etc/profile
	if [ $? == 1 ];then
	    echo "HADOOP_HOME=${HADOOPHOME}" >> /etc/profile
	else
		sed -i "s/HADOOP_HOME=.*/HADOOP_HOME=${HADOOPHOME}/g" /etc/profile
	fi

	grep -rn "PATH=" /etc/profile
	if [ $? == 1 ];then
	    echo "PATH=$PATH:$JAVA_HOME/bin:$HADOOP_HOME/bin" >> /etc/profile
	else
		sed -i 's/PATH=.*/PATH=$PATH:$JAVA_HOME\/bin:$HADOOP_HOME\/bin/g' /etc/profile
	fi

	grep -rn "export" /etc/profile
	if [ $? == 1 ];then
	    echo "export $JAVA_HOME $HADOOP_HOME $PATH" >> /etc/profile
	else
	    sed -i 's/export.*/export $JAVA_HOME $HADOOP_HOME $PATH/g' /etc/profile
	fi
	source /etc/profile

	popd	
	echo "[download] hadoop-${version}"

	#ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa
	cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
    	chmod 0600 ~/.ssh/authorized_keys
	echo  "StrictHostKeyChecking=no" >> ~/.ssh/config
	
	 pushd $HADOOP_HOME
    cp etc/hadoop/core-site.xml{,.bak}
    cat <<EOF >etc/hadoop/core-site.xml
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<!--
  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License. See accompanying LICENSE file.
-->

<!-- Put site-specific property overrides in this file. -->

	
<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://$localhost:9000</value>
    </property>
    <property>
        <name>hadoop.tmp.dir</name>
        <value>/data/sdb,/data/sdc,/data/sdd,/data/sde,/data/sdf,/data/sdg,/data/sdh,/data/sdi,/data/sdj,/data/sdk,/data/sdl</value>		
    </property>
</configuration>

EOF


    cp etc/hadoop/hdfs-site.xml{,.bak}
    cat <<EOF > etc/hadoop/hdfs-site.xml
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<!--
  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License. See accompanying LICENSE file.
-->

<!-- Put site-specific property overrides in this file. -->

<configuration>
    <property>
        <name>dfs.replication</name>
        <value>1</value>
    </property>
    <property>
		<name>dfs.datanode.data.dir</name>  
		<value>/data/sdb/dfs/data,/data/sdc/dfs/data,/data/sdd/dfs/data,/data/sde/dfs/data,/data/sdf/dfs/data,/data/sdg/dfs/data,/data/sdh/dfs/data,/data/sdi/dfs/data,/data/sdj/dfs/data,/data/sdk/dfs/data,/data/sdl/dfs/data</value>
		<description></description>
    </property>
	<property>
		<name>dfs.namenode.name.dir</name>  
		<value>/data/sdb/dfs/name,/data/sdc/dfs/name,/data/sdd/dfs/name,/data/sde/dfs/name,/data/sdf/dfs/name,/data/sdg/dfs/name,/data/sdh/dfs/name,/data/sdi/dfs/name,/data/sdj/dfs/name,/data/sdk/dfs/name,/data/sdl/dfs/name</value>
		<description></description>
    </property>
	<!-- SocketTimeoutException: 60000 millis timeout while waiting for channel to be ready for read -->
    <property>
        <name>dfs.client.socket-timeout</name>
        <value>600000</value>
    </property>

    <property>
        <name>dfs.datanode.handler.count</name>
        <value>20</value>
    </property>
    <property>
        <name>dfs.blocksize</name>
        <value>67108864</value>
    </property>
</configuration>
EOF
   
   
   
   
   
#cp  etc/hadoop/mapred-site.xml.template etc/hadoop/mapred-site.xml
cat > etc/hadoop/mapred-site.xml <<EOF
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<!--
  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License. See accompanying LICENSE file.
-->

<!-- Put site-specific property overrides in this file. -->

<configuration>
	<property>
        <name>mapreduce.framework.name</name>
        <value>yarn</value>
    </property>

    <property>
        <name>mapreduce.jobhistory.done-dir</name>
        <value>/user/history/done</value>
    </property>
    <property>
        <name>mapreduce.jobhistory.intermediate-done-dir</name>
        <value>/user/history/done_intermediate</value>
    </property>

    <!-- job history log -->
    <property>
        <name>mapreduce.jobhistory.webapp.address</name>
        <value>$localhost:19888</value>
        <description>MapReduce JobHistory Server Web UI host:port</description>
    </property>

    <property>
        <name>yarn.app.mapreduce.am.env</name>
        <value>HADOOP_MAPRED_HOME=$testhome/hadoop/hadoop-3.1.1</value>
    </property>

    <property>
        <name>mapreduce.map.env</name>
        <value>HADOOP_MAPRED_HOME=$testhome/hadoop/hadoop-3.1.1</value>
    </property>
    <property>
        <name>mapreduce.reduce.env</name>
        <value>HADOOP_MAPRED_HOME=$testhome/hadoop/hadoop-3.1.1</value>
    </property>

</configuration>
EOF


    mv etc/hadoop/yarn-site.xml etc/hadoop/yarn-site.bak.xml
	touch etc/hadoop/yarn-site.xml
cat <<EOF > etc/hadoop/yarn-site.xml
<?xml version="1.0"?>
	
<configuration>
	<property>
        <name>yarn.nodemanager.aux-services</name>
        <value>mapreduce_shuffle</value>
    </property>
    <property>
        <name>yarn.resourcemanager.hostname</name>
        <value>$localhost</value>
    </property>
    <property>
        <name>yarn.resourcemanager.scheduler.class</name>
        <value>org.apache.hadoop.yarn.server.resourcemanager.scheduler.fair.FairScheduler</value>
    </property>
    <property>
        <name>yarn.nodemanager.pmem-check-enabled</name>
        <value>false</value>
    </property>
    <property>
        <name>yarn.nodemanager.vmem-check-enabled</name>
        <value>false</value>
    </property>
    <property>
        <name>yarn.nodemanager.resource.memory-mb</name>
        <value>524288</value>
    </property>
    <property>
        <name>yarn.nodemanager.resource.cpu-vcores</name>
        <value>96</value>
    </property>
    <property>
        <name>yarn.scheduler.maximum-allocation-mb</name>
        <value>50000</value>
    </property>
    <property>
        <name>yarn.scheduler.maximum-allocation-vcores</name>
        <value>20</value>
    </property>
    <property>
        <name>yarn.log-aggregation-enable</name>
        <value>true</value>
    </property>
    <property>
        <name>yarn.log.server.url</name>
        <value>http://$localhost:19888/jobhistory/logs</value>
    </property>
    <property>
        <description>NM Webapp address.</description>
        <name>yarn.nodemanager.webapp.address</name>
        <value>$localhost:8042</value>
	</property>
	<property>
        <description></description>
        <name>yarn.nodemanager.local-dirs</name>
        <value>/data/sdb/nm-local-dir,/data/sdc/nm-local-dir,/data/sdd/nm-local-dir,/data/sde/nm-local-dir,/data/sdf/nm-local-dir,/data/sdg/nm-local-dir,/data/sdh/nm-local-dir,/data/sdi/nm-local-dir,/data/sdj/nm-local-dir,/data/sdk/nm-local-dir,/data/sdl/nm-local-dir</value>
	</property>
</configuration>

EOF
	
	pkill -9 java
	rm -rf /data
	
	for i in b c d e f g h i j k l;do
		mkdir -p /data/sd$i
		mkfs.xfs -f /dev/sd$i

		mount -t xfs /dev/sd$i /data/sd$i
	done
	
	
    /usr/bin/expect << EOF
  
   spawn $HADOOP_HOME/bin/hdfs namenode -format
   expect "Re-format filesystem in Storage Directory "
   send "Y\r"  
   expect eof
EOF
   

	$HADOOP_HOME/sbin/start-dfs.sh
	$HADOOP_HOME/sbin/start-yarn.sh
	$HADOOP_HOME/sbin/mr-jobhistory-daemon.sh start historyserver
	sleep 5
	jps
	
    popd 



}

function install_scala()
{
	scala -version
	if [ $? -eq 0 ] ;then
		echo -e "scala  already installed.\n"
	else
	   mkdir -p /usr/local/scala
	   cd /usr/local/scala
	   wget -c -q http://172.19.20.15:8083/perform_depends/test_dependent/scala-2.11.8.tgz
	   tar -zxf scala-2.11.8.tgz
	   cd -
	fi
	scalahome='/usr/local/scala'
	grep -rn "SCALA_HOME=" /etc/profile
	if [ $? == 1 ];then
	    echo "SCALA_HOME=$scalahome" >> /etc/profile
	else
	    sed -i "s/SCALA_HOME=.*/SCALA_HOME=${scalahome}/g" /etc/profile
	fi

	grep -rn "PATH=" /etc/profile
	if [ $? == 1 ];then
	    echo "PATH=$PATH:$JAVA_HOME/bin:$HADOOP_HOME/bin:$SCALA_HOME/bin" >> /etc/profile
	else
	    sed -i 's/PATH=.*/PATH=$PATH:$JAVA_HOME\/bin:$HADOOP_HOME\/bin:$SCALA_HOME\/bin/g' /etc/profile
	fi

	grep -rn "export" /etc/profile
	if [ $? == 1 ];then
            echo "export $JAVA_HOME $HADOOP_HOME $SCALA_HOME $PATH" >> /etc/profile
        else
            sed -i 's/export.*/export $JAVA_HOME $HADOOP_HOME $SCALA_HOME $PATH/g' /etc/profile
        fi
	source /etc/profile
}

function install_spark()
{
	ls -l ${testhome}/spark
	if [ $? -eq 0 ];then
	   echo "spark exists"
	   rm -rf ${testhome}/spark
	   mkdir -p ${testhome}/spark
	else
	   mkdir -p  ${testhome}/spark
	fi
    cd ${testhome}/spark
    echo "download spark ,Please wait..."
    wget -c -q http://172.19.20.15:8083/perform_depends/test_dependent/spark/spark-2.4.0numa.tar.gz
    tar -zxf spark-2.4.0numa.tar.gz 
	mv spark-2.4.0numa spark-2.4.0-bin-hadoop3.1
	
	hdfs dfs -mkdir -p /tmp/spark/events
	
	sed -i "s/\/home\/wuanjun\/installed\/java\/jdk1.8.0_161/\/usr\/lib\/jvm\/java-1.8.0-openjdk/g" ${spark}/conf/spark-env.sh
	sed -i "s/\/home\/wuanjun\/installed/\/usr\/local/g" ${spark}/conf/spark-env.sh
	sed -i 's/172.19.22.15/'"$localhost"'/g' ${spark}/conf/spark-env.sh
	sed -i 's/export SPARK_PID_DIR=\/hadoop/export SPARK_PID_DIR=\/data/g' ${spark}/conf/spark-env.sh
	sed -i 's/\/hadoop\/data1\/,\/hadoop\/data2\/,\/hadoop\/data3\/,\/hadoop\/data4\/,\/hadoop\/data5\/,\/hadoop\/data6\/,\/hadoop\/data7\/,\/hadoop\/data8\//\/data\/sdb,\/data\/sdc,\/data\/sdd,\/data\/sde,\/data\/sdf,\/data\/sdg,\/data\/sdh,\/data\/sdi,\/data\/sdj,\/data\/sdk,\/data\/sdl/g' ${spark}/conf/spark-env.sh	
	sed -i 's/172.19.22.15/'"$localhost"'/g' ${spark}/conf/spark-defaults.conf
	

	sparkhome='/usr/local/spark/spark-2.4.0-bin-hadoop3.1'
	grep -rn "SPARK_HOME=" /etc/profile
	if [ $? == 1 ];then
	    echo "SPARK_HOME=$sparkhome" >> /etc/profile
	else
	    sed -i "s/SPARK_HOME=.*/SPARK_HOME=${sparkhome}/g" /etc/profile
	fi

	grep -rn "PATH=" /etc/profile
	if [ $? == 1 ];then
	    echo "PATH=$PATH:$JAVA_HOME/bin:$HADOOP_HOME\/bin:$SCALA_HOME/bin:$SPARK_HOME/bin" >> /etc/profile
	else
	    sed '/PATH=*'d /etc/profile
	    echo "PATH=$PATH:$JAVA_HOME/bin:$HADOOP_HOME\/bin:$SCALA_HOME/bin:$SPARK_HOME/bin" >> /etc/profile
    	fi

	grep -rn "export" /etc/profile
	if [ $? == 1 ];then
            echo "export $JAVA_HOME $HADOOP_HOME $SCALA_HOME $SPARK_HOME $PATH" >> /etc/profile
        else
            sed -i 's/export.*/export $JAVA_HOME $HADOOP_HOME $SCALA_HOME $SPARK_HOME $PATH/g' /etc/profile
        fi



	source /etc/profile 


	cd ${spark}/sbin
	./start-all.sh
	./start-history-server.sh
	jps


}


#预置条件
function init_env()
{
    #检查结果文件是否存在，创建结果文件：
	fn_checkResultFile ${RESULT_FILE}
    #自定义测试预置条件检查实现部分：比如工具安装，检查多机互联情况，执行用户身份 
	  #需要安装工具，使用公共函数install_deps，用法：install_deps "${pkgs}"
	  #需要日志打印，使用公共函数PRINT_LOG，用法：PRINT_LOG "INFO|WARN|FATAL" "xxx"
	

	fn_install_pkg "bc  wget expect python2.7 python-minimal numactl sysstat" 2
	if [ $? -eq 0 ];then
		fn_writeResultFile "${RESULT_FILE}" "install_deps" "pass"
	else
		fn_writeResultFile "${RESULT_FILE}" "install_deps" "fail"
	fi
	install_jdk
	if [ $? -eq 0 ];then
                fn_writeResultFile "${RESULT_FILE}" "install_jdk" "pass"
        else
                fn_writeResultFile "${RESULT_FILE}" "install_jdk" "fail"
        fi

	install_hadoop
	if [ $? -eq 0 ];then
                fn_writeResultFile "${RESULT_FILE}" "install_hadoop" "pass"
        else
                fn_writeResultFile "${RESULT_FILE}" "install_hadoop" "fail"
        fi

	install_scala
	if [ $? -eq 0 ];then
                fn_writeResultFile "${RESULT_FILE}" "install_scala" "pass"
        else
                fn_writeResultFile "${RESULT_FILE}" "install_scala" "fail"
        fi

	install_spark
	if [ $? -eq 0 ];then
                fn_writeResultFile "${RESULT_FILE}" "install_spark" "pass"
        else
                fn_writeResultFile "${RESULT_FILE}" "install_spark" "fail"
        fi

}

#测试执行
function test_case()
{
	#测试步骤实现部分
	#如果执行的命令分系统，请使用distro变量来区分OS类型
	#需要日志打印，使用公共函数PRINT_LOG，用法：PRINT_LOG "INFO|WARN|FATAL" "xxx"
	  #记录每项测试结果，使用公共函数fn_writeResultFile，用法：fn_writeResultFile "${RESULT_FILE}" "test_item_name" "pass|fail"
	
	echo '/usr/bin/expect << EOF
	spawn /usr/local/spark/spark-2.4.0-bin-hadoop3.1/bin/spark-shell
	expect "scala>"
	send "val days = List(\"Sunday\", \"Monday\", \"Tuesday\", \"Wednesday\", \"Thursday\", \"Friday\", \"Saturday\")\r"
	send " val daysRDD = sc.parallelize(days)\r"
	send "daysRDD.count()\r"
	expect eof
EOF' > /root/test.sh
	chmod +x /root/test.sh
	/root/test.sh > ${TMPFILE}
	sleep 40
	sed -i 's/\r//g' ${TMPFILE}
	num=$(cat ${TMPFILE} |grep res0: |awk -F '=' '{print $2}' |awk '{sub("^ *","");sub(" *$","");print}')
	if [[ ${num} -eq 7 ]];then
		fn_writeResultFile "${RESULT_FILE}" "check_num" "pass"
	else
		fn_writeResultFile "${RESULT_FILE}" "check_num" "fail"
	fi
	${spark}/bin/run-example org.apache.spark.examples.SparkPi  >> ${TMPFILE}
	sleep 50	
	pi=$(cat ${TMPFILE} |grep roughly |awk '{print $NF}' |awk -F '.' '{print $2}')
	pi_2=${pi:0:2}
	if [[ $pi_2 -gt 12 ]] && [[ $pi_2 -lt 15 ]];then
		fn_writeResultFile "${RESULT_FILE}" "check_pi" "pass"
	else
		fn_writeResultFile "${RESULT_FILE}" "check_pi" "fail"
	fi
	#检查结果文件，根据测试选项结果，有一项为fail则修改test_result值为fail
	check_result ${RESULT_FILE}
}

#恢复环境
function clean_env()
{
	#清除临时文件
	FUNC_CLEAN_TMP_FILE
	#自定义环境恢复实现部分,工具安装不建议恢复
	#需要日志打印，使用公共函数PRINT_LOG，用法：PRINT_LOG "INFO|WARN|FATAL" "xxx"
	rm -rf test.sh
	${testhome}/spark/spark-2.4.0-bin-hadoop3.1/sbin/stop-history-server.sh
	${testhome}/spark/spark-2.4.0-bin-hadoop3.1/sbin/stop-all.sh
	${testhome}/hadoop/hadoop-3.1.1/sbin/stop-all.sh
	sleep 10
	rm -rf /data/*
	rm -rf /usr/local/spark
        rm -rf /usr/local/scala
        rm -rf /usr/local/hadoop
	pkill -9 java
	mv /etc/profile1 /etc/profile
	source /etc/profile
}


function main()
{
	init_env || test_result="fail"
	if [ ${test_result} = "pass" ];then
		test_case || test_result="fail"
	fi
	clean_env || test_result="fail"
}


main $@
ret=$?
#LAVA平台上报结果接口，勿修改
lava-test-case "$test_name" --result ${test_result}
exit ${ret}
