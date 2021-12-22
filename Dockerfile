FROM openjdk:11
MAINTAINER Avijit

ENV DEBIAN_FRONTEND noninteractive

# Refresh package lists
RUN apt-get update
RUN apt-get -qy dist-upgrade

RUN apt-get install -qy rsync curl openssh-server openssh-client vim nfs-common

RUN mkdir -p /data/hdfs-nfs/
RUN mkdir -p /opt
WORKDIR /opt

# Install Hadoop
RUN curl -L https://archive.apache.org/dist/hadoop/core/hadoop-3.3.1/hadoop-3.3.1.tar.gz -s -o - | tar -xzf -
RUN mv hadoop-3.3.1 hadoop

# Setup
WORKDIR /opt/hadoop
ENV PATH /opt/hadoop/bin:/opt/hadoop/sbin:$PATH
ENV JAVA_HOME /usr/local/openjdk-11
#RUN sed -e 's/${JAVA_HOME}\/usr/local/openjdk-11/g' etc/hadoop/hadoop-env.sh

RUN echo "\n export HDFS_NAMENODE_USER=root \n" >> etc/hadoop/hadoop-env.sh &&\
    echo "\n export HDFS_DATANODE_USER=root \n" >> etc/hadoop/hadoop-env.sh &&\
	echo "\n export HDFS_SECONDARYNAMENODE_USER=root \n" >> etc/hadoop/hadoop-env.sh &&\
	echo "\n export JAVA_HOME=/usr/local/openjdk-11 \n" >> etc/hadoop/hadoop-env.sh &&\
	echo "\n export HADOOP_HOME=/opt/hadoop \n" >> etc/hadoop/hadoop-env.sh
	
# Configure ssh client
RUN ssh-keygen -t dsa -P '' -f ~/.ssh/id_dsa && \
    cat ~/.ssh/id_dsa.pub >> ~/.ssh/authorized_keys && \
    chmod 0600 ~/.ssh/authorized_keys

RUN echo "\nHost *\n" >> ~/.ssh/config && \
    echo "   StrictHostKeyChecking no\n" >> ~/.ssh/config && \
    echo "   UserKnownHostsFile=/dev/null\n" >> ~/.ssh/config

# Disable sshd authentication
RUN echo "root:root" | chpasswd
RUN sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/' /etc/ssh/sshd_config
# SSH login fix. Otherwise user is kicked off after login
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd
# => Quick fix for enabling datanode connections
#    ssh -L 50010:localhost:50010 root@192.168.99.100 -p 22022 -o PreferredAuthentications=password

# Pseudo-Distributed Operation
COPY core-site.xml etc/hadoop/core-site.xml
COPY hdfs-site.xml etc/hadoop/hdfs-site.xml
RUN hdfs namenode -format

# SSH
EXPOSE 22
# hdfs://localhost:8020
EXPOSE 8020
# HDFS namenode
EXPOSE 50020
# HDFS Web browser
EXPOSE 50070
# HDFS datanodes
EXPOSE 50075
# HDFS secondary namenode
EXPOSE 50090

CMD service ssh start \
  && start-dfs.sh \
  && hadoop --daemon start namenode \
  && hadoop --daemon start datanode \
  && hadoop-daemon.sh start nfs3 \
  && bash