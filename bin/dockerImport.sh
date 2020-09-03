#!/bin/bash
mkdir -p /mnt/dockerimgs
read -p "please input the local GW ip:" gwip
echo "checking the connection to ${gwip}......"
sleep 3
ping -c 5 ${gwip}
if [ $? ! -eq 0 ]; then
    echo "failed to connect GW , check the reason"
    exit 111
fi
mount -t nfs ${gwip}:/data /mnt/dockerimgs
if [ $? ! -eq 0 ]; then
    echo "mount GW nfs failed , check the reason"
    exit 112
fi
echo "begin to rsync images to local"
sleep 3
rysnc -avzP /mnt/dockerimgs/baseimg.tar /root/
if [ $? ! -eq 0 ]; then
    echo "rsync  failed , please check the reason"
    exit 113
fi
echo "start importing images,it may take about 10mins,please be patient!"
docker load -i /root/baseimg.tar