#!/bin/sh
pool="zones"
snapshot_prefix="daily"
backups_before_fresh_sync=14

ssh_private_key="/opt/cfg/global/root/.ssh/id_rsa"
gpg_keyname="Some GPG Key Name"
gpg_private_key="/opt/local/remote_backups/private.gpg.key"
gzip_level=3
zfs_send_extra_flags="-v"

destination_user="backup"
destination_server="backups.yourdomain.com"
destination_backup_directory="/home/backup"

import_keys(){
    echo "Adding private ssh key $ssh_private_key just in case."
    ssh-add $ssh_private_key

    echo "Adding private gpg key $gpg_private_key just in case."
    gpg --import $gpg_private_key
}

send_snapshot(){
    target_snapshot_and_method=$1
    destination_filename=$2

    echo $destination_filename

    zfs send $zfs_send_extra_flags -R $target_snapshot_and_method | gzip -$gzip_level | gpg --encrypt --sign --trust-model always --recipient "$gpg_keyname" | ssh -i $ssh_private_key $destination_user@$destination_server "cat > $destination_backup_directory/$destination_filename"
}

delete_remote_snapshots(){
    ssh -i $ssh_private_key $destination_user@$destination_server "rm -r $destination_backup_directory/$pool@$snapshot_prefix*"
}

import_keys

latest_snapshot=`zfs list -t snapshot -H -o name | sort | grep "$pool@$snapshot_prefix" | tail -1`

# this is definitely a bit ghetto but I don't have awesome sed regexp skills
last_backup=`ssh -i $ssh_private_key $destination_user@$destination_server "ls -al | grep --regexp '$pool' | tail -n 1 | sed -e 's/.* $pool/$pool/' | sed -e 's/.*-....-..-..-//' | sed -e 's/.zfs.gz.gpg//'"`

echo "Counting existing incremental backups..."
incremental_backup_count=`ssh -i $ssh_private_key $destination_user@$destination_server ls -al $destination_backup_directory | grep $pool | wc -l`

echo "...found $incremental_backup_count existing incremental backups."

is_fresh_backup_required(){
    if [[ $incremental_backup_count -eq 0 ]]; then
        echo 1
        return
    fi

    if [[  $incremental_backup_count -ge $backups_before_fresh_sync ]]; then
        delete_remote_snapshots

        echo 1
        return
    fi

    echo 0
}

if [[ $(is_fresh_backup_required) -eq 1 ]]; then
    echo "Sending fresh snapshot $latest_snapshot."
    send_snapshot $latest_snapshot "$latest_snapshot.zfs.gz.gpg"
else
    incremental_filename="$last_backup-$latest_snapshot.zfs.gz.gpg"
    echo "Sending incremental backup $incremental_filename."
    send_snapshot "-i $last_backup $latest_snapshot" $incremental_filename
fi
