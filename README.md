# PostgreSQL Backups to S3 Storage

This tool was created to quickly deploy a cronjob backup PostgreSQL in Kubernetes.  I created this tool for my personal use and do not provide any support, warranty or guarantee.  

## Setup
### PGP Encryption
For the best security, create an encryption key for PGP
```
openssl rand -base64 32
```

Create the `backup-encryption-key` secret

```
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  name: backup-encryption-key
data:
  key: ${KEY_FROM_ABOVE_STEP}
```

Replace `${KEY_FROM_ABOVE_STEP}` with the output of `openssl rand -base64 32` then apply to create the secret.

### Application Secret

The main secret is used by the tool 

```
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  labels:
    app.kubernetes.io/name: psql-backups
  name: psql-backups
stringData:
  backup-password: ${BACKUP_USER_PASSWORD}
  backup-user: ${BACKUP_USER}
  bucket: ${S3_BUCKER}
  databases: ${CSV_OF_DATABASES_TO_BACKUP}
  db-host: ${SVC_URL_OF_DATABASE}
  db-port: ${DB_PORT}
  enable-encryption: ${TRUE_OR_FALSE}
  retention: ${STRING_RETENTION_DAYS}
  use-ssl: ${USE_SSL_TO_CONNECT_TO_DB|TRUE_OR_FALSE}
```
Replace the values above with your values

| Key | Description | Values |
|-----|-------------|--------|
|backup-password| Password for the backup user on postgres.  Must have permissions to backup provided databases| String|
|backup-user| Database user with permissions to backup provided databases| String|
|bucket| S3 Bucket to store your backups.  Can contain multiple folders | String |
|databases| Comma separated string of database names to backup|users,photos,contacts|
|db-host|URL to postgres host|URL|
|db-port|Port that postgres is running on|Integer|
|enable-encryption|Encrypt backups with gpg.  Must have backup-encryption-key secret set|Bool (true\|false)|
|retention|Number of days to keep backups.  Remove this value to keep backups forever|Integer|
|use-ssl|Enable SSL on the postgresql connection|Bool (true\false)|

### S3CMD Config Secret
This app will mount the secret `s3cmd-config` for the s3cmd tool to use.  This document will not cover the creation of API Tokens for S3.

```
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  labels:
    app.kubernetes.io/name: s3cmd-config
  name: s3cmd-config
stringData:
  s3cmd: [default]
access_key = ${S3_ACCESS_KEY}
secret_key = ${S3_SECRET_KEY}
host_base = s3.amazonaws.com
host_bucket = %(bucket)s.s3.amazonaws.com
```

Important - There is no indentation on the lines below `s3cmd: [default]`

## Apply the CronJob
The default schedule for this cronjob is every night at midnight.  You can change that by updating the `schedule` on line 92.

```
kubectl apply -f cronjob.yaml
```

## Testing
You can manually run the cronjob by creating a one-time job from it

```
kubectl create job --from=cronjob/database-backup
```