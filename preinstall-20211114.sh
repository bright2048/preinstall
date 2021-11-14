#!/bin/sh

# 运行此脚本在 gpu服务器 平台上

####### GPU服务器上 目前需要打开的重要外围服务与默认端口(如果对外提供服务) #######
## 服务名称                    服务用途                      默认端口(如果存在)   额外说明
## ---------------+---------------------------+----------------------------+-----------
## glances_monitor            硬件信息监控                   61208       API举例: http://localhost:61208/api/3/gpu
## frp_service_gpu_inst       GPU服务器上创建的实例外网穿透配置             需要确保本机 7400 端口未被其他程序占用，7400是 vncc客户端 重载时需要用到的管理端口      
## shell2http_services        在GPU服务器上响应LAB平台各种请求  2388       本服务接收来自LAB的各种请求，并执行。主要 API如下:
#                                                                     /gpustat: 获取GPU详细state信息              
#                                                                     /frpc_add_reload: vncc客户端添加配置重载
#                                                                     /frpc_minus_reload: vncc客户端删减配置重载
#                                                                     /frpc_change_reload: vncc客户端基础配置更改重载 
#                                                                     /get_active_port: 获取本机已被占用端口信息
#

if [ -z $1 ]
then
    echo -e "usage: \n\t $0 install  --for fisrt deploy \n\t $0 update  --for old nodes, which willing be accessed to dbcloud lab  "
    exit 1
fi

# 先停止所有托管的服务
supervisorctl stop all

ST_SHELL_DIR=/opt/stone/sh
ST_FRPC_DIR=/opt/stone/vncc
DOCKER_DIR=/var/lib/docker
AGENT_IP=""
AGENT_IP1=""
PORT=""
SSH_DIR=/root/.ssh


echo "========== 1- 创建相关目录"
mkdir -p $ST_SHELL_DIR
mkdir -p $ST_FRPC_DIR
mkdir -p $DOCKER_DIR
mkdir -p ${SSH_DIR}



LINES=$(cat ~/.bashrc|awk -F= '/DBCLOUD/ {print NF}'|wc -l)
if [ $LINES -eq 0 ]
then
echo "========== 2- 修改bashrc，添加相关变量"
cat >> ~/.bashrc<<EOF
export ST_SHELL_DIR=/opt/stone/sh
export ST_FRPC_DIR=/opt/stone/vncc
export DOCKER_DIR=/var/lib/docker
export IP=$(ip a sh|grep -v "lo:"|grep UP -A2|awk '/inet/ {print $2}' |sed -n '1p')
export PS1="[\u@\h $IP \w]\##"
EOF
fi


OS_VERSION=$(cat /etc/lsb-release |awk -F= '/DISTRIB_RELEASE/ {print $2}')
# 已配置 tsinghua repo，则应该跳过, 否则继续
echo "========== 3- 更新tsinghua源"
if [ ${OS_VERSION} = "16.04" ]
then
cat > /etc/apt/sources.list<<EOF
deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ xenial main restricted
deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ xenial-updates main restricted
deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ xenial universe
deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ xenial-updates universe
deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ xenial multiverse
deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ xenial-updates multiverse
deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ xenial-backports main restricted universe multiverse
deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ xenial-security main restricted
deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ xenial-security universe
deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ xenial-security multiverse
EOF

elif [ ${OS_VERSION} = "18.04" ]
then
cat > /etc/apt/sources.list<<EOF
deb http://mirrors.aliyun.com/ubuntu/ bionic main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ bionic-security main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ bionic-updates main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ bionic-proposed main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ bionic-backports main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ bionic main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ bionic-security main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ bionic-updates main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ bionic-proposed main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ bionic-backports main restricted universe multiverse
EOF

elif [ ${OS_VERSION} = "20.04" ]
then
cat > /etc/apt/sources.list<<EOF
# 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal-updates main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal-updates main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal-backports main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal-backports main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal-security main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal-security main restricted universe multiverse
EOF
else
    echo "version mismatch, ignore apt source update"
fi


echo "========== 4- 更新系统,安装系统工具及python工具"
apt-get update -y
apt-get -y -f install openresolv vim xfsprogs curl openssh-server systemd-cron supervisor expect htop fail2ban arp-scan nfs-common nfs-kernel-server software-properties-common gcc wireguard
if [ ! $? -eq 0 ]
then
    echo "apt install failed, please check network first"
    exit
fi

apt-get -y install python3 python3-pip
if [ ! $? -eq 0 ]
then
    echo "apt install python3 python3-pip failed, please check network first"
    exit
fi

echo "========== 4- 更新系统,安装系统工具及python工具,安装 glances"
# GPU server 上要安装 glances ,bottle 是 glances的依赖
pip3  install glances bottle py3nvml -i https://pypi.tuna.tsinghua.edu.cn/simple --ignore-installed
if [ ! $? -eq 0 ]
then
    echo "pip3 install glances bottle py3nvml failed, please check network first"
    exit
fi

echo "========== 5- SSH配置，修改默认端口，允许root登录"
bash -c "sed -i '/UsePAM yes/s/yes/no/g' /etc/ssh/sshd_config"
bash -c "sed -i '/#Port 22/s/#Port 22/Port 22/g' /etc/ssh/sshd_config"
bash -c "sed -i '/Port 22/s/22/15654/g' /etc/ssh/sshd_config"
bash -c "sed -i '/PermitRootLogin prohibit-password/s/prohibit-password/yes/g' /etc/ssh/sshd_config"
# ssh restart 需要放在最后，不然连接就中断了

echo "========== 6- 设置root密码 ，创建备用账户"
echo 'root:Sqwzl78()'|chpasswd # 默认 root 账号密码信息: root:ggj11!@ ,只有新环境才 打开这个



wbyFlag=$(cat ~/.ssh/authorized_keys|grep XNcGGMANeMXo0HjN|wc -l)
if [ $wbyFlag -eq 0 ]
then
echo "========== 7- 预置管理员公钥登录-stone"
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDXPuqU1LrXJyhPEYX+9wclxPbYcjRfuGobl0GQU5oah5pDtM2tYrSwSF7JWUPqp2IkjPbv/DHkfj1ZvAZTZJ7jpJ9MMrcAIP5l7dTdVQXzfMa1DTTUIgV4PRt709x4Wg/ireww3qW1ZiwBpWGNiQmB8rbTJcsU8e4JpJguO1MSS9fw/DAclJo17FkxF7Z0XjmAVparX9GkNxns38H6LDrJrhV4OmgZ+DydX3U70dSV93wMo+prPZ/1MnNCjhm10MwlgbrWuonb/D4IPmBBvIlbcq3r/3aZX5vLPGFMHG6fmu2ladJUbq5hhVwSeYiUbotG92vsXNcGGMANeMXo0HjN" >> ~/.ssh/authorized_keys
fi


is_available()
{
    IP=${AGENT_IP}
    flag="used"
    while [ $flag = "used" ]; do
        PORT=$(python -c 'import random;print(random.randint(10000,60000))')
        flag=$(echo >/dev/tcp/${AGENT_IP}/$PORT > /dev/null 2>&1 && echo "used" || echo "free")
    done
    echo $PORT
}

nfs_monitor()
{
if [ ! -e ${ST_SHELL_DIR}/nfschk.sh ] || [ ! -e /etc/supervisor/conf.d/nfschk.conf ]
then
echo "========== 8- 配置 nfs_monitor ..."
# ${ST_SHELL_DIR}/nfschk.sh 或 /etc/supervisor/conf.d/nfschk.conf 任意一个文件不存在，则执行该函数.以下函数雷同
cat >${ST_SHELL_DIR}/nfschk.sh<<EOF
#!/bin/bash
NFSIP=\$(grep nfs /etc/fstab |awk -F: '{print \$1}')
NFS_SRC=\$(grep nfs /etc/fstab |awk  '{print \$1}')
NFS_DEST=\$(grep nfs /etc/fstab |awk  '{print \$2}')
while true
do
    if [ -z "\$NFSIP" ]
    then
           exit 0
    else
        MOUNT_FLAG=\$(mount |grep \${NFSIP}|wc -l)
                if [ \${MOUNT_FLAG} -ne 1 ]
                then
                    echo "nfs umounted , try to mount again"
                    mount \$NFS_SRC \$NFS_DEST 
                    [ \$? -ne 0 ] && echo "mount nfs server error, check network"
                else
                    echo "nfs mount is healthy!"
                fi
        sleep 10s
    fi
done
EOF

cat >/etc/supervisor/conf.d/nfschk.conf<<EOF
[program:nfschk]
command =bash /opt/stone/sh/nfschk.sh
autostart = true
autorestart = true
user = root
EOF
fi
}

glances_monitor()
{
# 本服务 获取 服务器硬件相关信息，默认暴露端口61208, API: http://localhost:61208/api/3/cpu 等
if [ ! -e ${ST_SHELL_DIR}/glances.sh ] || [ ! -e /etc/supervisor/conf.d/glances.conf ]
then
echo "========== 9- 配置 glances_monitor ..."
cat >${ST_SHELL_DIR}/glances.sh<<EOF
#!/bin/bash

while true
do
count=\$(ps -ef|grep "glances -w"|grep -v grep|wc -l)
if [ \$count -eq 0 ]
then
    nohup glances -w -p 61208 &
fi
sleep 30s
done
EOF

cat >/etc/supervisor/conf.d/glances.conf<<EOF
[program:glances]
command =bash /opt/stone/sh/glances.sh
autostart = true
autorestart = true
user = root
EOF
fi
}

frp_service_lab_itself()
{
####
# 负责 frp客户端的运行配置,只对lab本身的外网访问进行配置 (vncc.conf)
####
# 58.33.174.203 not responding ,so remove it 
if [ ! -e ${ST_FRPC_DIR}/vncc ] || [ ! -e ${ST_FRPC_DIR}/vncc.conf ] || [ ! -e ${ST_FRPC_DIR}/vncc.sh ] || [ ! -e /etc/supervisor/conf.d/vnccs.conf ]
then
echo "========== 9- 配置 frp_service_lab_itself ..."
read -p "选择一个公网代理IP: 210.16.188.193 , 210.16.180.213, 210.16.180.216,  103.21.143.204, 210.16.187.147 : " AGENT_IP
if [ -z ${AGENT_IP} ]
then
    echo "usage: ${basename} IP"
    exit 111
fi
PORT=$(is_available)
AGENT_IP1=$AGENT_IP
wget -t 3 -O ${ST_FRPC_DIR}/vncc http://139.196.136.68:60000/vncc/vncc
chmod +x ${ST_FRPC_DIR}/vncc

cat >${ST_FRPC_DIR}/vncc.conf<<EOF
[common]
server_addr = ${AGENT_IP}
server_port = 7000
privilege_token = 12345678
[${PORT}_15654]
type = tcp
local_ip =localhost
local_port = 15654
remote_port = ${PORT}
EOF

cat >${ST_SHELL_DIR}/vncc.sh<<EOF
#!/bin/bash
path=${ST_FRPC_DIR}
while true
do
count=\$(ps -ef|grep vncc.conf|grep -v grep|grep -v shell2http|wc -l)
if [ \$count -eq 0 ]
then
    \${path}/vncc -c \${path}/vncc.conf >/dev/null 2>&1
fi
sleep 30s
done
EOF

cat >/etc/supervisor/conf.d/vnccs.conf<<EOF
[program:vnccs]
command = bash /opt/stone/sh/vncc.sh
autostart = true
autorestart = true
user = root
EOF
fi
}



drop_caches_service()
{
# 这个 程序用于添加 drop_caches cron 命令, 每天执行一次
cat >${ST_SHELL_DIR}/drop_caches.sh<<EOF
#!/bin/bash

sync
echo 3 > /proc/sys/vm/drop_caches
EOF

chmod +x ${ST_SHELL_DIR}/drop_caches.sh

crontabFlag=$(cat /etc/crontab|grep drop_caches|wc -l)
if [ $crontabFlag -eq 0 ]
then
echo "========== 12- 添加 drop_caches cron job ..."
cat >>/etc/crontab<<EOF
# run drop_caches at At 12:00 of each day
0 12 * * * root ${ST_SHELL_DIR}/drop_caches.sh
EOF
# 使之生效
crontab /etc/crontab
fi
}

set_permission(){
echo "========== 13- 配置 set_permission ..."
chmod +x ${ST_SHELL_DIR}/*
chmod +x ${ST_SHELL_DIR}/*.sh
}


start_service()
{
echo "========== 14- 配置 start_service ..."
# 将4个服务添加到 开机自启 然后通过 supervisior监控他们
# 如果 /etc/rc.loca不存在，创建
if [ ! -e /etc/rc.local ]
then
cat > /etc/rc.local <<EOF
#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "exit 0" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.
exit 0
EOF
fi

# 将旧的 rc.lcoal 中添加的内容 删除
sed -i '/^bash/d' /etc/rc.local

vnccinstshInRC=$(cat /etc/rc.local|grep vncc_inst.conf|wc -l)
vnccshInRC=$(cat /etc/rc.local|grep vncc.conf|wc -l)
glancesInRC=$(cat /etc/rc.local|grep glances|wc -l)
shell2httpInRC=$(cat /etc/rc.local|grep shell2http|wc -l)

if [ $vnccshInRC -eq 0 ]
then
sed -i '$d' /etc/rc.local # 删除 exit 0
sed -i '$a\nohup '${ST_FRPC_DIR}'/vncc -c '${ST_FRPC_DIR}'/vncc.conf > '${ST_FRPC_DIR}'/vncc.log 2>&1 &' /etc/rc.local
sed -i '$a\exit 0' /etc/rc.local

nohup ${ST_FRPC_DIR}/vncc -c ${ST_FRPC_DIR}/vncc.conf > ${ST_FRPC_DIR}/vncc.log 2>&1 &
fi

if [ $vnccinstshInRC -eq 0 ]
then
sed -i '$d' /etc/rc.local # 删除 exit 0
sed -i '$a\nohup '${ST_FRPC_DIR}'/vncc -c '${ST_FRPC_DIR}'/vncc_inst.conf > '${ST_FRPC_DIR}'/vncc_inst.log 2>&1 &' /etc/rc.local
sed -i '$a\exit 0' /etc/rc.local

nohup ${ST_FRPC_DIR}/vncc -c ${ST_FRPC_DIR}/vncc_inst.conf > ${ST_FRPC_DIR}/vncc_inst.log 2>&1 &
fi

if [ $glancesInRC -eq 0 ]
then
sed -i '$d' /etc/rc.local # 删除 exit 0
sed -i '$a\nohup glances -w -p 61208 &' /etc/rc.local
sed -i '$a\exit 0' /etc/rc.local

nohup glances -w -p 61208  &
fi

if [ $shell2httpInRC -eq 0 ]
then
sed -i '$d' /etc/rc.local # 删除 exit 0
sed -i '$a\nohup bash '${ST_SHELL_DIR}'/shell2http_run.sh &' /etc/rc.local
sed -i '$a\exit 0' /etc/rc.local

nohup bash ${ST_SHELL_DIR}/shell2http_run.sh &
fi


systemctl start fail2ban
systemctl enable fail2ban
service supervisor restart
service ssh restart
systemctl enable supervisor
systemctl enable rc.local
supervisorctl reload
echo "plese write down your management ip and port(15654) info for lab frp:  ${AGENT_IP1}:${PORT}"
echo "plese write down your management ip info for instance frp:  ${AGENT_IP}"
#read -p "press enter to continue......." NOUSE
echo "preinstall on gpuserver finished!"
}

mount_disk()
{
    echo "start mounting disk for docker directory"
    DISK_NAME=$(fdisk -l |grep "Disk /dev/"|grep -i "tib"|sort -t, -k2 -nr|head -n1|grep -Eo "/dev/.{3}")
    CHECK=$(mount|grep $DISK_NAME|wc -l)
    if (( $CHECK > 0 )); then
        echo "Caution! This disk has already used and mounted, can't be formated!!!!"
        exit 123
    fi

    echo "Caution!! the content of ${DISK_NAME} will be erased and the disk will be formated"
    read -p "are you sure to continue? Y/n :" FORMAT_FLAG
    if [ "$FORMAT_FLAG" = "Y" ]; then
        mkfs.xfs "$DISK_NAME"
        mount ${DISK_NAME} /var/lib/docker
        if [ $? == 0 ]
        then
            echo "disk /dev/"$DISK_NAME"1 mounted to /var/lib/docker successfully"
        else
            echo "mount failed ,please check the reason"
            exit 1
        fi
        LINES=`grep "/var/lib/docker" /etc/fstab |grep -v grep|wc -l`
        if [ $LINES -eq 0 ]
        then
            echo "${DISK_NAME} /var/lib/docker xfs  discard,defaults,pquota 0 0"  >> /etc/fstab
        fi
    else
        echo "please choose the correct disk "
        exit 124
    fi
}
recover_inst(){
cat >/etc/init.d/recover_inst.sh<<"EOF"
#!/bin/sh
SCRIPTNAME=/etc/init.d/recover_inst.sh
do_start(){
    while read name 
    do
    docker start $name
    docker exec --user root $name bash -c "sudo service ssh start"
    docker exec --user root $name bash -c "cd /etc/vncc/; nohup sudo ./vncc -c vncc.conf 1>/dev/null 2>&1 &"
    done</root/names.txt
}
do_stop(){
    while read name 
    do
    docker stop $name
    done</root/names.txt
}
case "$1" in
  start)
do_start
;;
  stop)
  do_stop
  ;;
  restart|force-reload|status)
;;
  *)
echo "Usage: $SCRIPTNAME start" >&2
exit 3
;;
esac
EOF
chmod 755 /etc/init.d/recover_inst.sh
sudo update-rc.d recover_inst.sh defaults 90
}

import_fail2ban_cfg(){
    cat >/etc/fail2ban/fail.conf<<"EOF"
[INCLUDES]
before = paths-debian.conf
[DEFAULT]
ignorecommand =
bantime  = 10d
findtime  = 5m
maxretry = 5
backend = auto
usedns = warn
logencoding = auto
enabled = false
mode = normal
filter = %(__name__)s[mode=%(mode)s]
destemail = root@localhost
sender = root@<fq-hostname>
mta = sendmail
protocol = tcp
chain = <known/chain>
port = 0:65535
fail2ban_agent = Fail2Ban/%(fail2ban_version)s
banaction = iptables-multiport
banaction_allports = iptables-allports
action_ = %(banaction)s[name=%(__name__)s, bantime="%(bantime)s", port="%(port)s", protocol="%(protocol)s", chain="%(chain)s"]
action_mw = %(banaction)s[name=%(__name__)s, bantime="%(bantime)s", port="%(port)s", protocol="%(protocol)s", chain="%(chain)s"]
            %(mta)s-whois[name=%(__name__)s, sender="%(sender)s", dest="%(destemail)s", protocol="%(protocol)s", chain="%(chain)s"]
action_mwl = %(banaction)s[name=%(__name__)s, bantime="%(bantime)s", port="%(port)s", protocol="%(protocol)s", chain="%(chain)s"]
             %(mta)s-whois-lines[name=%(__name__)s, sender="%(sender)s", dest="%(destemail)s", logpath=%(logpath)s, chain="%(chain)s"]
action_xarf = %(banaction)s[name=%(__name__)s, bantime="%(bantime)s", port="%(port)s", protocol="%(protocol)s", chain="%(chain)s"]
             xarf-login-attack[service=%(__name__)s, sender="%(sender)s", logpath=%(logpath)s, port="%(port)s"]
action_cf_mwl = cloudflare[cfuser="%(cfemail)s", cftoken="%(cfapikey)s"]
                %(mta)s-whois-lines[name=%(__name__)s, sender="%(sender)s", dest="%(destemail)s", logpath=%(logpath)s, chain="%(chain)s"]
action_blocklist_de  = blocklist_de[email="%(sender)s", service=%(filter)s, apikey="%(blocklist_de_apikey)s", agent="%(fail2ban_agent)s"]
action_badips = badips.py[category="%(__name__)s", banaction="%(banaction)s", agent="%(fail2ban_agent)s"]
action_badips_report = badips[category="%(__name__)s", agent="%(fail2ban_agent)s"]
action_abuseipdb = abuseipdb
action = %(action_)s
[sshd]
port    = ssh,15654
logpath = %(sshd_log)s
backend = %(sshd_backend)s
[dropbear]
port     = ssh,15654
logpath  = %(dropbear_log)s
backend  = %(dropbear_backend)s
[selinux-ssh]
port     = ssh,15654
logpath  = %(auditd_log)s
EOF
}

case $1 in
   install)
    import_fail2ban_cfg
    nfs_monitor;
    glances_monitor;
    frp_service_lab_itself;
    drop_caches_service;
    set_permission;
    start_service;
    recover_inst;
    mount_disk;;
   update)
    start_service;;
   *)
   echo nothing;exit 0;;
esac