# Manage-My-Server
This Readme contains basic information about how to install and run the programs of this project.
For more detailed information, tipps, FAQs, etc. please see the OK-API/Documenation Project, which contains more details about all projects and programs.

The Manage-My-Server project contains a collection of scripts for more convenient server management.  

[Link to the OK-API Documentation Project](!../../../../../../Documentation/README.md)

## multi-backup-ctrl.sh
This script is built to control a sync of multiple source directories to multiple target directories. The correlation, which source directory shall be synced to which target directory, is provided using an input file. The script is built to keep track of when the last sync job was executed, to make sure there are at least 24 hrs between the last sync and the actual one.
### Setup
The source and target directories must be mounted first. Mounting disks or paths is not in the scope of this script.

1. Copy the script to your server in your preferred directory, either using `git clone` or just copying it. 

2. Place one or more input files at your preferred location. Every line in this file must contain the source directory first, followed by the target directory, both separated by a blank. Using directories with blanks in their name is not tested.  
\
    Input file example:
    ```
    /mnt/d/doBackupSource/subdir1/ /mnt/f/doBackupTarget/
    /mnt/d/doBackupSource/subdir2/ /mnt/f/doBackupTarget/foodir/
    ```

3. Configure a cron job for regular execution or run the script manually. By using multiple input files for multiple calls you can realize more complex sync scenarios. 
The script is built and tested for execution with `sudo` or `root` permission, as it is assumed that the source and target directories for the backups, as well as the logging directories, have different permissions. If you do not want to use `sudo` or `root`, you must make sure that all permissions match the user used to execute the script.

|:warning: ATTENTION: The script uses the file `/var/log/multiBackupLog/trackingfile` to keep track of its last execution time, and make sure there are at least 24 hrs between the last sync run and the actual one. It uses the modify date of the file for this. If you want to execute it more regularly make sure to remove or modify the trackingfile first. This feature exists to support environments which are not up and running 24/7 and need to handle their backup syncs locally and asynchronously.|
| --- |


### Usage
```
Usage: multi-backup-ctrl.sh [OPTIONS]

This script is built to perform a backup of one or more source directories to one or more target directories. It is designed to be run in a NAS System which has multiple backup disks which can be mounted in different paths.
Even though it might run on a large variety of NAS systems, it was made for being used with 'openmediavault'.
The configuration which source directory shall be backed up to which target directory is being read from a separate config file.
The script is built to be either executed with sudo or root permissions.

Syntax: multi-backup-ctrl.sh -p|--path file_path [-t|--test] [-h|--help]

Options:
-p|--path     Mandatory parameter. Specifies the path of the config file which contains the source and target folders for the backup.
-t|--test     Sets the test flag, which makes the script run without really performing the rsync backup.
-h|--help     Print this Help.

Example usage: ./multi-backup-ctrl.sh -p /tmp/myInputFile.txt
Example usage: ./multi-backup-ctrl.sh -p /tmp/myInputFile.txt -t

The input file must contain a pair of source directory and target directory in each line, separated by a blank.
The required format is: '<sourceDir> <targetDir>'

Example input file:
/mnt/d/doBackupSource/subdir1/ /mnt/f/doBackupTarget/
/mnt/d/doBackupSource/subdir2/ /mnt/f/doBackupTarget/foodir/

Exit codes:
0         if execution successful.
1         if preparation fails, which can be malformed input or problems with logging environment.
2         if the rsync based backup itself failed for some reason.
```
### Logging
By default all logs are written to log files in the folder `/var/log/multiBackupLog`.
The file `executionLog.log` contains logs about the script run itself, like logs about input parameter parsing, sanity checks of input files, etc.
The file `backup.log` contains the logs about the sync itself. It contains information about the start and end of the sync as well as the complete rsync output.

The two log files have been separated, in order to provide a better overview about the times this script has been run and not clutter it with all the detailed rsync output.
