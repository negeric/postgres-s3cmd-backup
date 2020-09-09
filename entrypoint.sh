#!/bin/bash
# Check preconditions
[ -z "${DB_USER}" ] && echo "DB_USER not set!" && exit 1;
[ -z "${DB_PASS}" ] && echo "DB_PASS not set!" && exit 1;
[ -z "${DB_HOST}" ] && echo "DB_HOST not set!" && exit 1;
[ -z "${BUCKET}" ] && echo "BUCKET not set!" && exit 1;
[ -z "${DATABASE}" ] && echo "DATABASE not set.  Comma separated accepted" && exit 1
DB_PORT="${DB_PORT:-5432}"
DB_USE_SSL="${DB_USE_SSL:-true}"

export PGPASSWORD=${DB_PASS}

## Start the backup
if [[ "${DATABASE}" == *","* ]]; then
    echo "$(date '+%F-%H%M%S') - Multiple databases defined"
    DATABASES=$(echo ${DATABASE} | tr "," "\n")
    for DB in ${DATABASES}; do
        echo "$(date '+%F-%H%M%S') - Backing up database (${DB})"
        TIMESTAMP=$(date '+%F-%H%M%S')
        BACKUP_FILE="${DB}_${TIMESTAMP}"
        pg_dump -h ${DB_HOST} -p ${DB_PORT} -U ${DB_USER} ${DB} > ${BACKUP_FILE}
        if [ $? -eq 0 ]; then
            tar -czvf ${BACKUP_FILE}.tar.gz $BACKUP_FILE
            if [ ! -z "${ENCRYPT_BACKUPS}" ]; then                
                cat /etc/enc-key/key | gpg --passphrase-fd 0 --batch --quiet --yes -c -o ${BACKUP_FILE}.tar.gz.gpg ${BACKUP_FILE}.tar.gz        
                echo "$(date '+%F-%H%M%S') - Encrypted Database Backup (ok)"          
                s3cmd --config=/s3cmd/s3cmd put "${BACKUP_FILE}.tar.gz.gpg" s3://${BUCKET}/${BACKUP_FILE}.tar.gz.gpg --no-mime-magic                    
                echo "$(date '+%F-%H%M%S') - Uploaded Database Backup (ok)"    
            else
                s3cmd --config=/s3cmd/s3cmd put "${BACKUP_FILE}.tar.gz" s3://${BUCKET}/${BACKUP_FILE}.tar.gz --no-mime-magic
                echo "$(date '+%F-%H%M%S') - Database Backup Succeeded"                
            fi
        else 
            echo "$(date '+%F-%H%M%S') - Database Backup Failed"
            exit 1
        fi
    done
else
    echo "$(date '+%F-%H%M%S') - Backing up database (${DATABASE})"
    TIMESTAMP=$(date '+%F-%H%M%S')
    BACKUP_FILE="${DATABASE}_${TIMESTAMP}"
    pg_dump -h ${DB_HOST} -p ${DB_PORT} -U ${DB_USER} ${DB} > ${BACKUP_FILE}
    if [ $? -eq 0 ]; then
        tar -czvf ${BACKUP_FILE}.tar.gz $BACKUP_FILE
        if [ ! -z "${ENCRYPT_BACKUPS}" ]; then
            cat /etc/enc-key/key | gpg --passphrase-fd 0 --batch --quiet --yes -c -o ${BACKUP_FILE}.tar.gz.gpg ${BACKUP_FILE}.tar.gz      
            echo "$(date '+%F-%H%M%S') - Encrypted Database Backup (ok)"       
            s3cmd --config=/s3cmd/s3cmd put "${BACKUP_FILE}.tar.gz.gpg" s3://${BUCKET}/${BACKUP_FILE}.tar.gz.gpg --no-mime-magic                
            echo "$(date '+%F-%H%M%S') - Uploaded Database Backup (ok)"   
        else
            s3cmd --config=/s3cmd/s3cmd put "${BACKUP_FILE}.tar.gz" s3://${BUCKET}/${BACKUP_FILE}.tar.gz --no-mime-magic
            echo "$(date '+%F-%H%M%S') - Database Backup Succeeded"
        fi
    else 
        echo "$(date '+%F-%H%M%S') - Database Backup Failed"
        exit 1
    fi
fi

## Perform retention policy
if [ -z "${DAYS_TO_KEEP}" ]; then
    echo "$(date '+%F-%H%M%S') - No retention policy set.  Job is complete"
else
    echo "$(date '+%F-%H%M%S') - Retention policy configured.  Deleting backups older than ${DAYS_TO_KEEP} days"
    s3cmd --config=/s3cmd/s3cmd ls s3://${BUCKET} | grep " DIR " -v | while read -r line
        do
            createDate=`echo $line | awk {'print $1'}`
            currentDate=`date +'%Y-%m-%d'`            
            dateDiff=$(( (`date -d $currentDate +%s` - `date -d $createDate +%s`) / (24*3600) ))
            if [[ $dateDiff -gt ${DAYS_TO_KEEP} ]]
            then 
                fileName=`echo $line|awk {'print $4'}`
                echo "$(date '+%F-%H%M%S') - $fileName is older than ${DAYS_TO_KEEP} days, deleting"
                s3cmd --config=/s3cmd/s3cmd del "$fileName"
            fi
        done;
fi
