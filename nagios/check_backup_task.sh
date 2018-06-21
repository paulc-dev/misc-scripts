#!/bin/bash
# A separate backup script runs an "aws s3 sync" command to backup files to an AWS S3 bucket. 
# Whenever that script runs, it outputs the date ran and also writes a line either the string
# SUCCESS or FAILURE along with the return code (0, 1 or 2) of the aws s3 sync command.
# This Nagios check reads that log file to check if the task ran within the past 2 days and 
# also check for the the word SUCCESS or FAILURE and return code.

LOG_PATH=/scripts/logs/
log=document_backup_task.log

two_days_ago=$(date --date='2 days ago'  +%s)
run_date=`sed '1q;d' $LOG_PATH$log`
run_time=$(date --date=$run_date +%s)
run_status=`sed '2q;d' $LOG_PATH$log`

if [ "$run_time" -ge "$two_days_ago" ]; then
   if [[ $run_status = *"SUCCESS 0"* ]]; then
      echo Job completing successfully
      exit 0
   elif [[ $run_status = *"FAILURE 1"* ]]; then
      echo The backup job returned error code 1 - the S3 sync failed
      exit 2
   elif [[ $run_status = *"FAILURE 2"* ]]; then
      echo The backup job returned error code 2 - the S3 sync failed
      exit 2
   else
      echo Unknown status - check backup task log
      exit 3
   fi
else
   echo Job has not run in the last two days
   exit 2
fi
