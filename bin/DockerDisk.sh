#!/bin/bash
mount_disk()
{
    echo "start mounting disk for docker directory"
    fdisk -l |grep "Disk /dev/sd"|sed  "s/Disk//g"|awk -F, '{print FNR,$1 }'|tr -d ":" |tee .tmp.diskinf
    read -p "which disk do you want to mount on /data directory? " DISK_INDEX
    DISK_NAME=$(sed -n "${DISK_INDEX}p" .tmp.diskinf|awk '{print $2}')
    CHECK=$(mount|grep $DISK_NAME|wc -l)
    if (( $CHECK > 0 )); then
        echo "Caution! This disk has already used and mounted, can't be formated!!!!"
        exit 123
    fi

    echo "Caution!! the content of ${DISK_NAME} will be erased and the disk will be formated"
    read -p "are you sure to continue? Y/n" FORMAT_FLAG
    if [ "$FORMAT_FLAG" = "Y" ]; then
        parted ${DISK_NAME} mklabel gpt
        parted ${DISK_NAME} print
        echo "Ignore" | parted $DISK_NAME "mkpart primary 0% 100%"
        mkfs.ext4 "$DISK_NAME"1
        mkdir -p /var/lib/docker 
        mount ${DISK_NAME}1 /var/lib/docker
        if [ $? == 0 ]
        then
            echo "disk /dev/"$DISK_NAME"1 mounted to /var/lib/docker successfully"
        else
            echo "mount failed ,please check the reason"
            exit 1
        fi
        echo "${DISK_NAME}1 /var/lib/docker ext4 defaults 0 0"  >> /etc/fstab
    else
        echo "please choose the correct disk "
        exit 124
    fi
}
mount_disk