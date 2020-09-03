#!/bin/bash
#!demo: add2admin.sh test 210.16.188.193 20222 20277 fengrui
#.inst_env:
#server_addr=210.16.187.147
#ssh_port=10122
#api_port=10177
#mac=LSDJOFIJEWFLK
WORKDIR=$(dirname $0)
echo ${WORKDIR}
ENV_VAR=.inst_env
source ${ENV_VAR}
read -p "input lab name:" LAB
if [[ -z ${mac} ]] || [[ -z ${server_addr} ]] || [[ -z ${ssh_port} ]]|| [[ -z ${api_port} ]]|| [[ -z ${LAB} ]]
then
    echo "essential parameter is empty , please check and try again"
    exit 111
fi
NODE_NAME=$mac
NODE_IP=$server_addr
SSH_PORT=$ssh_port
API_PORT=$api_port
curl -H "Content-Type: application/x-www-form-urlencoded" -X POST -d 'NODE_NAME=$NODE_NAME&IP=$NODE_IP&SSH_PORT=$SSH_PORT&API_PORT=$API_PORT&ADMIN_USER=admin&ADMIN_PASSWD=123456&NOTE=&NOTE2=&NOTE3=&ACTION=new' "http://101.226.241.19:30081/node/$LAB/pserver_node.php"


#curl -H "Content-Type: application/x-www-form-urlencoded" -X POST -d 'NODE_NAME=shkjdx001&IP=210.16.188.193&SSH_PORT=13222&API_PORT=13277&ADMIN_USER=admin&ADMIN_PASSWD=123456&NOTE=&NOTE2=&NOTE3=&ACTION=new' "http://101.226.241.19:30081/node/zhuzheng/pserver_node.php"
#curl -H "Content-Type: application/x-www-form-urlencoded" -X POST -d 'NODE_NAME=dbcloud001&IP=222.73.22.191&SSH_PORT=31022&API_PORT=31077&ADMIN_USER=admin&ADMIN_PASSWD=123456&NOTE=&NOTE2=&NOTE3=&ACTION=new' "http://101.226.241.19:30081/node/zhuzheng/pserver_node.php"
#curl -H "Content-Type: application/x-www-form-urlencoded" -X POST -d 'NODE_NAME=dbcloud002&IP=103.21.143.145&SSH_PORT=13222&API_PORT=13277&ADMIN_USER=admin&ADMIN_PASSWD=123456&NOTE=&NOTE2=&NOTE3=&ACTION=new' "http://101.226.241.19:30081/node/zhuzheng/pserver_node.php"



