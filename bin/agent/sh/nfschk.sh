#!/bin/bash
NFSIP=`grep nfs /etc/fstab |awk -F: '{print $1}'`
NFS_SRC=`grep nfs /etc/fstab |awk  '{print $1}'`
NFS_DEST=`grep nfs /etc/fstab |awk  '{print $2}'`
while true
do
    if [ -z "$NFSIP" ]
    then
    else
        MOUNT_FLAG=`mount |grep ${NFSIP}|wc -l`
		if [ ${MOUNT_FLAG} -ne 1 ]
		then
		    echo "nfs umounted , try to mount again"
		    mount $NFS_SRC $NFS_DEST 
		    [ $? -ne 0 ] && echo "mount nfs server error, check network"
		else
		    echo "nfs mount is healthy!"
		fi
        sleep 30s
    fi
done