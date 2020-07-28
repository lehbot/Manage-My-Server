#!/usr/bin/env bash

# OK-API: Manage-My-Server --> multi-backup-ctrl.sh
# Copyright (c) 2020
# Author: Nico Schwarz
# Github Repository: ( https://github.com/OK-API/Manage-My-Server )
# OK-API : O.K.-Automated Procedures Initiative.
#
# Convenient multi source to multi target backup sync control.
#
# This file is copyright under the version 1.2 (only) of the EUPL.
# Please see the LICENSE file for your rights under this license.

#
# MUST BE EXECUTED WITH SUDO OR ROOT PERMISSION
#

################################################################################
# Help Section                                                                 #
################################################################################

showHelp() {
        # Display Help
        echo "This script is built to perform a backup of one or more source directories to one or more target directories."
        echo "It is designed to be run in a NAS System which has multiple backup disks which can be mounted in different paths."
        echo "Even though it might run on a large variety of NAS systems, it was made for being used with 'openmediavault'."
        echo "The configuration which source directory shall be backed up to which target directory is being read from a separate config file."
        echo "The script is built to be either executed with sudo or root permissions."
        echo
        echo "Syntax: doBackup.sh -f|--file file_path [-t|--test] [-h|--help]"
        echo "options:"
        echo "-f|--file     Mandatory parameter. Specifies the path of the config file which contains the source and target folders for the backup. "
        echo "-t|--test     Sets the test flag, which makes the script run without really performing the rsync backup."
        echo "-h|--help     Print this Help."
        echo
        echo "Example: ./doBackup.sh -f /tmp/myInputFile.txt"
        echo "Example: ./doBackup.sh -f /tmp/myInputFile.txt -t"
}

checkTrackingFile() {
        logdir=/var/log/doBackupLog/$timestamp
        trackingFile=/var/log/doBackupLog/trackingFile
       ##################
        # Checking if this script already ran in the past 24 hrs
        ##################
        # first check the existance of our tracking file
        if [[ -f $trackingFile ]]; then
                # Comparing modification epoch time with the actual epoch time.
                # If the difference is bigger than 86400 (24 hrs) then we do a backup.
                # We only want to do a backup once a day.
                # This could also have been done using the command:  find /var/log/trackingFile -mtime +0
                #       This checks if there is a file that has a modification date older than 24 hrs.
                #       But I wanted to make the logic more obvious by using this if clause, for others to read.
                #       In addition I wanted to react differently on a non existing file and on an existing file with a mtime diff of less than 24 hrs.
                trackingFileDate=$(stat -c %Y $trackingFile)
                currentTime=$(date +%s)
                timeDiff=$((currentTime - trackingFileDate))
                if ((timeDiff < 86400)); then
                        echo "trackingFile Date is smaller than 86400 seconds (24hrs). Nothing to do here. Age is " $timeDiff
                        # We consider this a successful execution of the script, assuming that it is being called regulary using e.g. a cronjob.
                        exit 0
                fi
        else
                # TODO: This should be part of an extra logging function
                mkdir -p "$logdir"
                echo "$timestamp" ": Tracking file " "$trackingFile" " not found. Assuming first or force run and starting backup." | tee -a "$logdir"/backLogOverview.log
        fi
}

startBackup() {
        # Initiating variables first
        timestamp=$(date +%Y%m%d-%H:%M:%S)
        mkdir -p /var/log/doBackupLog
        logdir=/var/log/doBackupLog/$timestamp
        trackingFile=/var/log/doBackupLog/trackingFile
  
        successVar="true"

        # The -p parameter creates all parent directories and does not throw an error if the folder already exists
        mkdir -p "$logdir"
        timestamp=$(date +%Y%m%d-%H:%M:%S)
        echo "$timestamp : Starting Backup." | tee -a "$logdir"/backLogOverview.log
        # Some thoughts about the following rsync command:
        #       --modify-window=1 rounds the timestamp to full seconds. NTFS timestamps have a resolution of 2 seconds, FAT/EXT filesystems use seconds.
        #       modify-window allows us to have a timestamp that differs by 1 second.
        #       As this script might sync from different filesystems, and the timestamp is being used for checking for changed files, 
        #       it must be able to match properly when using different file systems.
        #
        #       rsync parameter -z is not being used anymore. -z compresses the date before transferring it, 
        #       this is not required if you sync using sata/esata, of if you are having a fast network.
        #       In fact it might even slow things down, as it brings load on the cpu of your server (and only uses one core).
        #       If you need to sync over a small bandwidth WAN connection, you can add the -z paramater again.
        #
        #       --stats  Shows a comprehensive report at the end of transferring the data.
        #       -v      Flag for verbose output
        #       -h      Flag for human readable output

        # In a former version of this script, the rsync output has been piped to console as well as stdout usind tee: > > (tee -a $logdir/stdout.log) 2> >(tee -a $logdir/stderr.log >&2)
        # This is not necessary in this version.
        # Historical information: The first versionof this script was only using rsync -rtvh
        notification="$timestamp : Local Backup Run started."
        ((counter=0))
        for i in "${!sourceDirectoryArray[@]}"; do
                # Adding a blank line in notification to have it better formatted in output
                notification="$notification \n"
                timestamp=$(date +%Y%m%d-%H:%M:%S)
                # Following line is for debug purpose only
                #echo $timestamp ": Looping through index " $i | tee -a $logdir/backLogOverview.log
                echo"$timestamp : Backing up $i to target device ${targetDirectoryArray[$counter]}" | tee -a "$logdir"/backLogOverview.log
                if [ "$testflag" != "true" ]; then
                        # TODO: Add log entry
                        # Running the rsync. Redirecting output of stdin and stdout to a file and tee by splitting the pipe.
                        rsync -avh --modify-window=1 --stats "$i" "${targetDirectoryArray[$counter]}" > >(tee -a $logdir/stdout.log) 2> >(tee -a $logdir/stderr.log >&2)
                        # Getting the returncode of the first command in the pipe - the rsync.
                        out=${PIPESTATUS[0]}
                fi
                # uncomment following line for debugging purpose to test the if clause.
                # out=69
                timestamp=$(date +%Y%m%d-%H:%M:%S)
                echo "$timestamp : FINISHED $i with code  $out $(date)" | tee -a "$logdir"/backLogOverview.log
                if [ "$out" != 0 ]; then
                        successVar="false"
                        errmsg="$(cat "$logdir"/stderr.log)"
                        timestamp=$(date +%Y%m%d-%H:%M:%S)
                        notification="$notification \n$timestamp: Backup of  $i  to target device  ${targetDirectoryArray[$i]}  failed with output  $errmsg  and code  $out \n"
                        notification="$notification Repeating backLogOverview content: \n"
                        notification="${notification}$(cat "$logdir"/backLogOverview.log)  \n"
                        printf "%s" "$notification" | tee -a "$logdir"/backLogOverview.log
                        break
                fi
        done
        # Setting the new modification date on trackingFile
        touch $trackingFile
        echo "FINAL FINISH $(date)" >>"$logdir"/backLogOverview.log
}


getFileContent() {
        # Reading information from file
        ((counter=0))
        while IFS= read -r line; do
                fieldsArray=($(echo "$line" | cut -d' ' -f1-))
                # First checking if we have read a valid number of fields.
                # As there are only pairs allowed in the input file, we should have an even number of fields now.
                if [ ${#fieldsArray[@]} -ne 2 ]; then
                        timestamp=$(date +%Y%m%d-%H:%M:%S)
                        notification="$timestamp: ERROR - Invalid format of input file content. Every line needs to contain a pair of folders, separated by one blank. Example: /home/myUser/myFolder /mnt/myTargetMount/targetFolder"
                        printf "%s" "$notification" | tee -a "$logdir"/backLogOverview.log
                        exit 1
                fi
                # Filling the directory array which will be used to iterate and fill the rsync command later.
                # for i in "${!fieldsArray[@]}"; do
                        sourceDirectoryArray[$counter]="${fieldsArray[0]}"
                        targetDirectoryArray[$counter]="${fieldsArray[1]}"
                        ((++counter))
              #  done
        done <"$filepath"

        # Checking and validating input
        # Now checking if the source paths exist
        # We only check the source paths. Non existant target paths will be created later anyway.
        for i in "${sourceDirectoryArray[@]}"; do
                timestamp=$(date +%Y%m%d-%H:%M:%S)
                echo "i is $i"
                # TODO: Delete following line
                #directory=${directoryArray[$i]}
                if [ -d "$i" ]; then
                        echo "$timestamp : Successfully checked existence of input folder: $i."
                else
                        notification="$timestamp: ERROR - Directory $i does not exist. Please check your input file. Specifying an input file with correct source and target folders is mandatory. \n" >&2
                        printf "%s" "$notification" | tee -a "$logdir"/backLogOverview.log
                        exit 1
                fi
        done
}

# Reading input parameters one by one, and parsing it.
# In this while loop we only read the parameters, and validate input.
# We only start the backup later, if 
fileCheckFlag=false
declare -a sourceDirectoryArray
declare -a targetDirectoryArray
while [[ $# -gt 0 ]]; do
        key="$1"
        case $key in
        # todo: Maybe add a force parameter, which forces the script to continue even if a single backup job failed.
        -h | --help)
                showHelp
                exit 0
                ;;
        -f | --file) # specifies input file path
                filepath="$2"
                # First we check if the file exists
                if [[ -f "$filepath" ]]; then
                        echo "Filepath validated."
                        # Then we get the content and validate the content if it is properly formatted
                        getFileContent
                else
                        printf "The filepath '%s' specified with the -f|--file parameter does not exist.\n" "$filepath" >&2
                        exit 1
                fi
                fileCheckFlag=true
                shift # past argument
                shift # past value
                ;;
        -t | --test) # specifies the testflag
                testflag=true
                shift # past argument
                ;;
        *) # unknown option
                printf "Unknown input parameter %s. \nUsage: \n" "$1" >&2
                showHelp
                exit 1
                ;;
        esac
done

# Of course we only start the backup if the proper flag is present,
# proving that the proper parameter has been set, and the input has been validated.
# In addition this allows the while loop to finish and properly parse all input parameters, before we take action.
if [ "$fileCheckFlag" = true ]; then
        # Performing check if there has been a backup in the last 24 hrs.
        # The check will exit with rc 0 if there has been a check, so the backup is not started.
        checkTrackingFile
        startBackup
fi

