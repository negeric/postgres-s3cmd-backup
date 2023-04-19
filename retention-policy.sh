#!/bin/bash

S3_CONFIG=${S3_CONFIG:-/s3cmd/s3cmd}
function get_date_diff {
  if [ "$(uname)" == "Darwin" ]; then #Mac
    start_ts=$(date -jf "%Y-%m-%d" "${1}" +%s)
    end_ts=$(date -jf "%Y-%m-%d" "${2}" +%s)    
    dateDiff=$(( (${start_ts} - ${end_ts}) / (24*3600) ))
  else #Linux
    dateDiff=$(( (`date -d $1 +%s` - `date -d $2 +%s`) / (24*3600) ))
  fi
}

if [ -z "${DAYS_TO_KEEP}" ]; then
    echo "$(date '+%F-%H%M%S') - No retention policy set.  Job is complete"
else
    echo "$(date '+%F-%H%M%S') - Retention policy configured.  Deleting backups older than ${DAYS_TO_KEEP} days"    
    s3cmd --config=${S3_CONFIG} ls s3://${BUCKET}/ --recursive | while read -r line
        do
            createDate=`echo $line | awk {'print $1'}`
            currentDate=`date +'%Y-%m-%d'`                        
            get_date_diff "${currentDate}" "${createDate}"
            if [[ $dateDiff -gt ${DAYS_TO_KEEP} ]]
            then 
                fileName=`echo $line|awk {'print $4'}`
                echo "$(date '+%F-%H%M%S') - $fileName is older than ${DAYS_TO_KEEP} days, deleting"
                s3cmd --config=${S3_CONFIG} del "$fileName"
            fi
        done;
fi