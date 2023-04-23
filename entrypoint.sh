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
    echo "$(date '+%F-%H:%M:%S') - Multiple databases defined"
    DATABASES=$(echo ${DATABASE} | tr "," "\n")
    for DB in ${DATABASES}; do
        echo "$(date '+%F-%H:%M:%S') - Backing up database (${DB})"
        TIMESTAMP=$(date '+%F-%H%M%S')
        BACKUP_FILE="${DB}_${TIMESTAMP}"
        if [ "${FOLDER_PER_DB+true}" = "true" ] && [ "${FOLDER_PER_DB}" = true ]; then 
            S3_PATH="s3://${BUCKET}/${DB}/"
        else
            S3_PATH="s3://${BUCKET}/"
        fi
        pg_dump -h ${DB_HOST} -p ${DB_PORT} -U ${DB_USER} ${DB} > ${BACKUP_FILE}
        if [ $? -eq 0 ]; then
            if [ "${DATE_SUBFOLDERS+true}" = "true" ] && [ "${DATE_SUBFOLDERS}" = true ]; then
                S3_PATH="${S3_PATH}$(date +'%Y')/$(date +'%m')/$(date +'%d')"
                echo "$(date '+%F-%H:%M:%S') - Using sub folders ${S3_PATH}"
            fi
            tar -czvf ${BACKUP_FILE}.tar.gz $BACKUP_FILE
            if [ ! -z "${ENCRYPT_BACKUPS}" ]; then                
                cat /etc/enc-key/key | gpg --passphrase-fd 0 --batch --quiet --yes -c -o ${BACKUP_FILE}.tar.gz.gpg ${BACKUP_FILE}.tar.gz        
                echo "$(date '+%F-%H:%M:%S') - Encrypted Database Backup (ok)"          
                s3cmd --config=/s3cmd/s3cmd put "${BACKUP_FILE}.tar.gz.gpg" ${S3_PATH}/${BACKUP_FILE}.tar.gz.gpg --no-mime-magic                    
                echo "$(date '+%F-%H:%M:%S') - Uploaded Database Backup (ok)"    
            else
                s3cmd --config=/s3cmd/s3cmd put "${BACKUP_FILE}.tar.gz" ${S3_PATH}/${BACKUP_FILE}.tar.gz --no-mime-magic
                echo "$(date '+%F-%H:%M:%S') - Database Backup Succeeded"                
            fi
        else 
            echo "$(date '+%F-%H:%M:%S') - Database Backup Failed"
            exit 1
        fi
    done
else
    echo "$(date '+%F-%H:%M:%S') - Backing up database (${DATABASE})"
    TIMESTAMP=$(date '+%F-%H%M%S')
    BACKUP_FILE="${DATABASE}_${TIMESTAMP}"
    if [ "${FOLDER_PER_DB+true}" = "true" ] && [ "${FOLDER_PER_DB}" = true ]; then 
        S3_PATH="s3://${BUCKET}/${DATABASE}/"
    else
        S3_PATH="s3://${BUCKET}/"
    fi
    pg_dump -h ${DB_HOST} -p ${DB_PORT} -U ${DB_USER} ${DATABASE} > ${BACKUP_FILE}
    if [ $? -eq 0 ]; then
        if [ "${DATE_SUBFOLDERS+true}" = "true" ] && [ "${DATE_SUBFOLDERS}" = true ]; then       
            S3_PATH="${S3_PATH}$(date +'%Y')/$(date +'%m')/$(date +'%d')/"
            echo "$(date '+%F-%H:%M:%S') - Using sub folders ${S3_PATH}"
        fi
        tar -czvf ${BACKUP_FILE}.tar.gz $BACKUP_FILE
        if [ "${ENCRYPT_BACKUPS+true}" = "true" ] && [ "${ENCRYPT_BACKUPS}" = true ]; then
            cat /etc/enc-key/key | gpg --passphrase-fd 0 --batch --quiet --yes -c -o ${BACKUP_FILE}.tar.gz.gpg ${BACKUP_FILE}.tar.gz      
            echo "$(date '+%F-%H:%M:%S') - Encrypted Database Backup (ok)"       
            s3cmd --config=/s3cmd/s3cmd put "${BACKUP_FILE}.tar.gz.gpg" ${S3_PATH}${BACKUP_FILE}.tar.gz.gpg --no-mime-magic                
            echo "$(date '+%F-%H:%M:%S') - Uploaded Database Backup (ok)"   
        else
            s3cmd --config=/s3cmd/s3cmd put "${BACKUP_FILE}.tar.gz" ${S3_PATH}${BACKUP_FILE}.tar.gz --no-mime-magic
            echo "$(date '+%F-%H:%M:%S') - Database Backup Succeeded"
        fi
    else 
        echo "$(date '+%F-%H:%M:%S') - Database Backup Failed"
        exit 1
    fi
fi

## Perform retention policy
./retention-policy.sh