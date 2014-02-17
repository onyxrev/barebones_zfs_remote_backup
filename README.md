Barebones ZFS Remote Backup
--------------------------

Remote, encrypted, incremental backups for zfs using only zfs send, gpg, gzip, and ssh.  I made this because software can't be (easily) installed on a SmartOS host and I wanted a backup solution that worked with the tools available on the platform.  I normally would use duplicity in lieu of this.

I'm no shell script wizard.  This script could definitely be better (better error handling, please?).  If you want to make it better, please do.

Some assumptions made here:

* you have daily snapshots roughly in the format pool@daily* with a timestamp at the end
* you have generated a passwordless gpg key that the server can use to encrypt its data
* your server's user has an ssh keypair and the backup machine's user has the public key in the authorized_keys file
