#!/bin/bash
path=$(dirname $0)
while true
do
count=`ps -ef|grep "/root/agent/vxagent"|grep -v grep|wc -l`
if [ $count -eq 0 ]
then
    /root/agent/vxagent
fi
sleep 10s
done