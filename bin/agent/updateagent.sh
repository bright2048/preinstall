#!/bin/bash
rm -fr /root/agent/vxagent
wget -O /root/agent/vxagent http://www.youmijack.com/vxgateway/vxagent/vxagent
chmod 777 /root/agent/vxagent
rm -fr /root/agent/tmp
killall -9 vxagent
nohup /root/agent/vxagent > /dev/null 2>&1 &