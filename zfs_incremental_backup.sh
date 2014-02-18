#!/bin/sh
pool="zones"
snapshot_prefix="daily"
backups_before_fresh_sync=14
last_backup_file="/opt/local/remote_backups/last_backup"

ssh_private_key="/opt/cfg/global/root/.ssh/id_rsa"
gpg_keyname="Some GPG Key Name"
gpg_private_key="/opt/local/remote_backups/private.gpg.key"
gzip_level=3
zfs_send_extra_flags="-v"

destination_user="backup"
destination_server="backups.yourdomain.com"
destination_backup_directory="/home/backup"

import_keys(){
    echo "Adding private ssh key just in case."
    ssh-add $ssh_private_key

    echo "Adding private gpg key just in case."
    gpg --import $gpg_private_key
}

send_snapshot(){
    target_snapshot_and_method=$1
    destination_filename=$2

    zfs send $zfs_send_extra_flags -R $target_snapshot_and_method | gzip -$gzip_level | gpg --encrypt --sign --recipient "$gpg_keyname" | ssh $destination_user@$destination_server "cat > $destination_backup_directory/$destination_filename"
}

delete_remote_snapshots(){
    ssh $destination_user@$destination_server "rm -r $destination_backup_directory/$pool@$snapshot_prefix*"
}

import_keys

latest_snapshot=`zfs list -t snapshot -H -o name | sort | grep "$pool@$snapshot_prefix" | tail -1`

if [[ ( -e $last_backup_file ) && ( -s $last_backup_file ) ]]; then
    last_backup=`cat $last_backup_file`
fi

echo "Counting existing incremental backups..."
incremental_backup_count=`ssh $destination_user@$destination_server ls -al $destination_backup_directory | grep $pool | wc -l`

echo "...found $incremental_backup_count existing incremental backups."

is_fresh_backup_required(){
    if [[ $incremental_backup_count -eq 0 ]]; then
        echo "No backup sets on remote system."
        return 1;
    fi

    if [[ -z "$last_backup_file" ]]; then
        delete_remote_snapshots

        echo "No documented existing backups on local system."
        return 1;
    fi

    if [[  $incremental_backup_count -ge $backups_before_fresh_sync ]]; then
        delete_remote_snapshots

        echo "Number of incremental backups is greater than the allowed $backups_before_fresh_sync."
        return 1;
    fi

    return 0;
}

is_fresh_backup_required
if [[ $ -eq 1 ]]; then
    echo "Sending fresh snapshot $latest_snapshot."
    send_snapshot $latest_snapshot "$latest_snapshot.zfs.gz.gpg"
else
    echo "Sending incremental backup $incremental_filename."
    send_snapshot "-i $last_backup $latest_snapshot" "$last_backup-$latest_snapshot"
fi

echo "Remembering latest backup snapshot is $latest_snapshot."
echo "$latest_snapshot" > $last_backup_file
