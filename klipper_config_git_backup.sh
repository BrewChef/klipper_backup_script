#!/bin/bash

## Opening manual
if [[ "$1" = "-h" || "$1" = "--help" ]]
then
        less /home/pi/scripts/klipper_backup_script/manual
        exit 1
elif [[ -n "$1" ]]
then
        echo "Try -h, or --help for the manual"
        exit 2
fi

configfile='/home/pi/scripts/klipper_backup_script/backup.cfg'
configfile_secured='/home/pi/scripts/klipper_backup_script/sec_backup.cfg'

## Check if the file contains malicious code
if egrep -q -v '^#|^[^ ]*=[^;]*' "$configfile"
then
        echo "Config file is unclean, cleaning it..." >&2
        ## Filter the original to a new file
        egrep '^#|^[^ ]*=[^;&]*'  "$configfile" > "$configfile_secured"
        configfile="$configfile_secured"
fi

## Importing the config
source "$configfile"

## Calculating days to keep the logs
DEL=$((($(date '+%s') - $(date -d "$RETENTION months ago" '+%s')) / 86400))

## Calculating which backups should be done
BACKUP=$((10*$CLOUD + $GIT))

## Backing up
case $BACKUP in
	0)
		## None specified
		echo "No backups configured" | tee /home/pi/backup_log/$(date +%F).log
		echo "Exiting" | tee /home/pi/backup_log/$(date +%F).log
		;;
	1)
		## GitHub
		echo "Backing up to GitHub" | tee /home/pi/backup_log/$(date +%F).log
		echo "Adding changes to push" | tee -a /home/pi/backup_log/$(date +%F).log
		git -C /home/pi/klipper_config add .
		echo "Committing to GitHub repository" | tee -a /home/pi/backup_log/$(date +%F).log
		git -C /home/pi/klipper_config commit -m "backup $(date +%F)" | tee -a /home/pi/backup_log/$(date +%F).log
		echo "Pushing" | tee -a /home/pi/backup_log/$(date +%F).log
		git -C /home/pi/klipper_config push -u origin master | tee -a /home/pi/backup_log/$(date +%F).log
		;;
	10)
		## Google Drive
		echo "Backing up to Cloud storage provider" | tee /home/pi/backup_log/$(date +%F).log
		rclone sync /home/pi/klipper_config "$REMOTE":"$FOLDER" --exclude "/.git/**" --transfers=1 --log-file=/home/pi/backup_log/"$(date +%F)".log --log-level=INFO
		;;
	11)
		## GitHub and Google Drive
		echo "Backing up to GitHub" | tee /home/pi/backup_log/$(date +%F).log
                echo "Adding changes to push" | tee -a /home/pi/backup_log/$(date +%F).log
                git -C /home/pi/klipper_config add .
                echo "Committing to GitHub repository" | tee -a /home/pi/backup_log/$(date +%F).log
                git -C /home/pi/klipper_config commit -m "backup $(date +%F)" | tee -a /home/pi/backup_log/$(date +%F).log
                echo "Pushing" | tee -a /home/pi/backup_log/$(date +%F).log
                git -C /home/pi/klipper_config push -u origin master | tee -a /home/pi/backup_log/$(date +%F).log
		echo "Backing up to Cloud storage provider" | tee /home/pi/backup_log/$(date +%F).log
                rclone sync /home/pi/klipper_config "$REMOTE":"$FOLDER" --exclude "/.git/**" --transfers=1 --log-file=/home/pi/backup_log/"$(date +%F)".log --log-level=INFO
                ;;
	*)
		## Config error
		echo "No valid backup configuration" | tee -a /home/pi/backup_log/$(date +%F).log
		echo "Please check the config file!" | tee -a /home/pi/backup_log/$(date +%F).log
		;;
esac

## Log rotation
case $ROTATION in
	0)
		## No action taken
		echo "Log rotation is disabled" | tee -a /home/pi/backup_log/$(date +%F).log
		;;
	1)
		## Delete old logs
		find /home/pi/backup_log -mindepth 1 -mtime +$DEL -delete
		;;
	*)
		## Config error
		echo "No valid log rotation configuration" | tee -a /home/pi/backup_log/$(date +%F).log
		echo "Please check the config file!" | tee -a /home/pi/backup_log/$(date +%F).log
		;;
esac
