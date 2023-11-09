DESCRIPTION
This app is used to backup and restore a databases between: local / S3 / RDS


---------------
notes
so instead of doing it like that I'll just do it with different arguments
And all the credentials will be dictionaries in settings.py
---------------

STEP BY STEP INSTALLATION






PREREQUISITES
unzip / awscli must be installed in this instance: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
Have an EC2 instance, that is attached to the RDS database (I'm using Ubuntu here)
Instance must have SSM installed 
    sudo snap install amazon-ssm-agent --classic
    sudo systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service
    sudo systemctl status snap.amazon-ssm-agent.amazon-ssm-agent.service
Instance must have IAM permissions to use SSM

---------- NAMING CONVENTION ----------
db_<TIMESTAMP>.sql  - local to S3 to RDS
rdsbackup_<TIMESTAMP>.sql - for RDS backups 


---------- PLACES ---------- 
RDS       :   RDS instance
LOCAL     :   Database in local machine container
S3_LOCAL  :   S3 Folder that contains backups from LOCAL
S3_RDS    :   S3 Folder that contains backups from RDS 

---------- EXISTING FUNCTIONALITIES ---------- 
update-rds-test       :   S3_LOCAL > RDS TEST
update-rds-prod       :   RDS TEST > EC2 > RDS PROD
backup-rds            :   RDS > S3_RDS
get-rds               :   RDS > S3_RDS > LOCAL
get-s3                :   S3_LOCAL > LOCAL
update-local-rds      :   RDS > S3_RDS > LOCAL + RESTORE
update-local-s3       :   S3 > LOCAL + RESTORE
backup-local          :   LOCAL > S3_LOCAL
check-local-db        :   Checks if local db is empty

---------- COMING FUNCTIONALITIES ---------- 
Clean up routine - to clean up too much stuff in S3
Retrieve db from specific date
Logs
Send db to a test instance
DO THE DB TEST / WORK ON RDS AND ON S3


---------- REQUIRED ENVIRONMENT VARIABLES ----------
AWS_SECRETS_NAME        :   Name of the AWS Secrets Manager that contains the secrets
AWS_SECRETS_REGION      :   AWS Region where the secrets are stored
AWS_SECRET_ACCESS_KEY   :   AWS Secret Access Key


---------- REQUIRED SECRETS ----------
These secrets must be stored in AWS Secrets Manager with the following key/value pairs

---- BASTION EC2 INSTANCE ----
BASTION_INSTANCE_ID     :   Id of the bastion instance that will be used to connect to the RDS instance
BASTION_WORKPATH        :   Path where the bastion instance will store the files
LOCAL_WORKPATH          :   Absolute path where the local instance code is located (no trailing slash)
---- POSTGRES DATABASE ----
# Credentials for the different databases

PG_PASS_PROD
PG_PASS_TEST
PG_PASS_LOCAL

PG_USER_PROD
PG_USER_TEST
PG_USER_LOCAL

PG_NAME_PROD
PG_NAME_TEST
PG_NAME_LOCAL

PG_HOST_PROD
PG_HOST_TEST
PG_HOST_LOCAL

---- RDS ----
RDS_PASSWORD
RDS_ENDPOINT
RDS_USER
RDS_DBNAME
RDS_DB_IDENTIFIER
RDS_PROD_DB
RDS_TEST_DB

---- S3  ----
S3_BUCKET
S3_RDS_BACKUP_DIR
S3_LOCAL_BACKUP_DIR
S3_DB_PREFIX

LOCAL_USER
LOCAL_DBNAME
LOCAL_HOST

