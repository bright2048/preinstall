#!/bin/sh
WORKDIR=$(dirname $0)
reinstall=$1
if [ -n "$reinstall" ]
then
    apt-get remove docker docker-engine docker-ce docker.io -y
    rm -rf /var/lib/docker
fi
sudo apt-get -y install apt-transport-https ca-certificates curl software-properties-common
sleep 3s
wget -O /root/gpg https://download.docker.com/linux/ubuntu/gpg
sudo apt-key add /root/gpg
sleep 3s
sudo add-apt-repository "deb [arch=amd64] https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/ubuntu $(lsb_release -cs) stable"
sleep 3s
wget -O /root/gpgkey https://nvidia.github.io/nvidia-docker/gpgkey
sudo apt-key add /root/gpgkey
sleep 3s
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
sleep 3s
wget -O /etc/apt/sources.list.d/nvidia-docker.list https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list
sleep 3s
sudo apt-get update
sudo apt-get -y install docker-ce
sudo apt-get install -y nvidia-docker2
service docker start
bash ${WORKDIR}/repo_registry.sh


