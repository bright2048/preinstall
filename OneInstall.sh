#!/bin/bash
#V3.2
#fix bugs of running preinstall
#optimize the code contruct
#import nvidia driver 450.66 to match customer requirement
#V3.0 Created by Bright 18th-Aug-2020

INTERVAL=3
source ~/.bashrc
menuList ()
{
    echo "----------------------------------"
    echo "please enter your choice:"
    echo "(0) Hard disk prepare for docker installation"
    echo "(1) run preinstall shell"
    echo "(2) get mapping IP and Port"
    echo "(3) run ndriver install shell"
    echo "(4) run nvd shell"
    echo "(5) image pull"
    echo "(6) update API"
    echo "(7) (GW only) config NFS service"
    echo "(8) Add to monitor Platform"
    echo "(9) Exit Menu"
    echo "----------------------------------"
}


while true
do
menuList
read input
case $input in
    0)
        echo "Start format the large hard disk for docker"
        sleep ${INTERVAL}
        bash ./bin/DockerDisk.sh;;
    1)
        read -p "input the control GW ip:" CONTROL_GW
        echo "Start running preinstall.sh"
        sleep ${INTERVAL}
        if [ -z ${CONTROL_GW} ]
        then
            echo "should provide crontol gateway IP."
            exit 101
        fi
        bash ./bin/preinstall.sh ${CONTROL_GW};;
    2)
        echo "Start mapping IP and Port"
        sleep ${INTERVAL}
        serverip=$(sed -n '2p' /root/vncc/vncc.conf)
        serverssh=$(sed -n '9p' /root/vncc/vncc.conf)
        gpu_server="${serverip#*= }":"${serverssh#*= }" 
        echo -e "host mapped ip&port:\t"${gpu_server}
    ;;
    3)
        echo "Start installing nvidia driver"
        sleep ${INTERVAL}
        bash ./bin/ndriver.sh;;
    4)
        echo "Start deploying docker and nvidia-docker"
        sleep ${INTERVAL}
        bash ./bin/nvd.sh;;
    5)
        echo "Start importing base docker image"
        sleep ${INTERVAL}
        bash ./bin/dockerImport.sh;;
    6)
        echo "Start updating API"
        sleep ${INTERVAL}
        curl localhost:7777/?C=updatepnmlab;;
        updatepnmlab::MS42
    8)
        echo "add to monitoring system"
        sleep ${INTERVAL}
        bash ./bin/add2admin.sh;;
    9)
    exit;;
esac
done