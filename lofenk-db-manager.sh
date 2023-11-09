#!/bin/bash

# ERROR HANDLING
# Commented out the exit because psql throws some non critical errors that have the effect of stopping the script
# One of those errors being an indexing error related to Cities Light
# set -e  # Stop the script on the first error
trap 'catchError $?' ERR

catchError() {
  local exit_code=$1
  echo "An error occurred. Exit code: $exit_code"
  echo "The command that failed was: $(history | tail -n2 | head -n1 | sed 's/^ *//;s/ *$//')"
  # exit $exit_code
}

# VALIDATES ARGUMENTS
valid_commands=("setup-secrets" "setup-local" "setup-bastion" "setup-rds" "setup-s3" "update-rds-test" "update-rds-prod" "backup-rds" "get-rds" "get-s3" "update-local-rds" "update-local-s3" "backup-local" "get-rds" "get-s3" "check-local-db")
found=0
command=$1
for valid_command in "${valid_commands[@]}"; do
    if [[ "${valid_command}" == "${command}" ]]; then
        found=1
        break
    fi
done




if [[ "${found}" -eq 0 ]]; then
    echo "Invalid argument use one of the following:"
    echo "setup-secrets         :   tests and sets up secrets manager"
    echo "setup-local           :   tests and sets up local db"
    echo "setup-bastion         :   tests and sets up the bastion EC2 instance"
    echo "setup-rds             :   tests and sets up the RDS instance"
    echo "setup-s3              :   tests and sets up the S3 bucket"
    echo "update-rds-test       :   S3_LOCAL > RDS TEST RESTORE"
    echo "update-rds-PROD       :   S3_LOCAL > RDS PROD RESTORE"
    echo "update-local-rds      :   RDS > S3_RDS > LOCAL RESTORE"
    echo "update-local-s3       :   RDS > S3_RDS > LOCAL RESTORE"
    echo "backup-local          :   LOCAL > S3_LOCAL SAVE"
    echo "get-rds               :   RDS > S3_RDS > LOCAL SAVE"
    echo "get-s3                :   S3_LOCAL > LOCAL SAVE"
    echo "check-local-db        :   checks if local-db is empty"
    exit 1
fi

#INSTEAD OF ALL THIS - JUST DO IT ONE AT THE TIME, START WITH JUST UPLOADING TO S3
# AND RETRIEVING FROM S3 - I CAN JUST WRITE A QUICK FUNCTION THAT GETS THE CREDENTIALS FROM 
# SETTINGS.PY, AND SO DO S3 FIRST, THEN LITTLE BY LITTLE DO THE OTHER FUNCTIONS

# # RETRIEVING ALL SECRETS
# credentials=$(python aws_get_secret.py $AWS_SECRETS_NAME $AWS_SECRETS_REGION)
# db_credentials=$(echo "$credentials" | tr -d '\n')

# # BASTION
# BASTION_INSTANCE_ID=$(echo "$db_credentials" | jq -r '.BASTION_INSTANCE_ID')
# BASTION_WORKPATH=$(echo "$db_credentials" | jq -r '.BASTION_WORKPATH')

# # LOCAL
# LOCAL_WORKPATH=$(echo "$db_credentials" | jq -r '.LOCAL_WORKPATH')

# # POSTGRES
# PG_PASS_PROD=$(echo "$db_credentials" | jq -r '.PG_PASS_PROD')
# PG_PASS_TEST=$(echo "$db_credentials" | jq -r '.PG_PASS_TEST')
# PG_PASS_LOCAL=$(echo "$db_credentials" | jq -r '.PG_PASS_LOCAL')

# PG_USER_PROD=$(echo "$db_credentials" | jq -r '.PG_USER_PROD')
# PG_USER_TEST=$(echo "$db_credentials" | jq -r '.PG_USER_TEST')
# PG_USER_LOCAL=$(echo "$db_credentials" | jq -r '.PG_USER_LOCAL')

# PG_SUPERUSER_PROD=$(echo "$db_credentials" | jq -r '.PG_SUPERUSER_PROD')
# PG_SUPERUSER_TEST=$(echo "$db_credentials" | jq -r '.PG_SUPERUSER_TEST')
# PG_SUPERUSER_LOCAL=$(echo "$db_credentials" | jq -r '.PG_SUPERUSER_LOCAL')

# PG_NAME_PROD=$(echo "$db_credentials" | jq -r '.PG_NAME_PROD')
# PG_NAME_TEST=$(echo "$db_credentials" | jq -r '.PG_NAME_TEST')
# PG_NAME_LOCAL=$(echo "$db_credentials" | jq -r '.PG_NAME_LOCAL')


# # RDS
# RDS_PASSWORD=$(echo "$db_credentials" | jq -r '.RDS_PASSWORD')
# RDS_ENDPOINT=$(echo "$db_credentials" | jq -r '.RDS_ENDPOINT')
# RDS_USER=$(echo "$db_credentials" | jq -r '.RDS_USER')
# RDS_DBNAME=$(echo "$db_credentials" | jq -r '.RDS_DBNAME')
# RDS_IDENTIFIER=$(echo "$db_credentials" | jq -r '.RDS_DB_IDENTIFIER')

# # S3
# S3_BUCKET=$(echo "$db_credentials" | jq -r '.S3_BUCKET')
# S3_RDS_BACKUP_DIR=$(echo "$db_credentials" | jq -r '.S3_RDS_BACKUP_DIR')
# S3_LOCAL_BACKUP_DIR=$(echo "$db_credentials" | jq -r '.S3_LOCAL_BACKUP_DIR')
# S3_DB_PREFIX=$(echo "$db_credentials" | jq -r '.S3_DB_PREFIX')


# POLL FUNCTION -- Retrieves and prints the output
function poll_for_result() {
    local instance_id=$1
    local command_id=$2

    while true; do
        # Get the command's status
        result=$(aws ssm list-command-invocations --instance-id $instance_id --command-id $command_id --details)
        status=$(echo $result | jq -r .CommandInvocations[0].Status)

        # Check if the command has completed
        if [[ "$status" == "Success" ]]; then
            # Retrieve and print the output
            output=$(echo $result | jq -r .CommandInvocations[0].CommandPlugins[0].Output)
            echo $output
            break
        elif [[ "$status" == "Failed" || "$status" == "Cancelled" || "$status" == "TimedOut" ]]; then
            echo "Command failed with status $status"
            
            # Extract and print the error content
            error_content=$(echo $result | jq -r '.CommandInvocations[0].CommandPlugins[0].StandardErrorContent')
            echo "Error Details: $error_content"
            
            break
        fi

        # Wait for a short period before checking again
        sleep 5
    done
}

# EXECUTE_COMMAND FUNCTION - Sends a bash command to EC2 instance via Systems Manager (SSM) (This assumes you have SSM Agent installed on your EC2 and necessary IAM permissions) 
function execute_command() {
    local command="$1"
    local response=$(aws ssm send-command \
        --instance-ids $BASTION_INSTANCE_ID \
        --document-name "AWS-RunShellScript" \
        --parameters commands=["$command"])
    # Print the output
    local command_id=$(echo $response | jq -r .Command.CommandId)
    # Print the command_id for debugging
    poll_for_result $BASTION_INSTANCE_ID $command_id
}

# WAIT FOR SSM FUNCTION - Waits for SSM to boot before sending SSM commands
function wait_for_ssm_agent() {
    local instance_id=$1
    echo "Waiting for SSM Agent on instance $instance_id to be online..."

    while true; do
        # Check the status of the SSM agent
        agent_status=$(aws ssm describe-instance-information --filters "Key=InstanceIds,Values=$instance_id" --query 'InstanceInformationList[0].PingStatus' --output text)

        if [[ "$agent_status" == "Online" ]]; then
            echo "SSM Agent is online."
            break
        else
            echo "SSM Agent status: $agent_status. Waiting..."
            sleep 10
        fi
    done
}

#GET LATEST FILE IN DIR - Receives a directory and gets the latest database_dump in that dir
function get_latest_dump_file() {
    local dir_path="$1"
    local latest_file=$(aws s3 ls "s3://${S3_BUCKET}/${dir_path}/${S3_DB_PREFIX}" | sort -t_ -k2 -n | tail -1)
    echo "$latest_file"
}

#RDS -> S3 Backup : Backup the RDS to S3
function backup_RDS() {
    #Gets "s3" or "local" as argument
    local destination="$1"
    #Get the file and download it to EC2
    rdsbackup=rdsbackup_$(date +%s).sql
    echo "RDS Backup File: $rdsbackup"
    execute_command "export PGPASSWORD=$RDS_PASSWORD; pg_dump -h $RDS_ENDPOINT -U $RDS_USER -d $PG_NAME_PROD -w -b -f $$BASTION_WORKPATH/$rdsbackup"
    # Send the file to S3
    execute_command "aws s3 cp $$BASTION_WORKPATH/$rdsbackup s3://$S3_BUCKET/$S3_RDS_BACKUP_DIR/$rdsbackup"

    # Send the file locally
    if [[ "$destination" == "local" || "$destination" == "local-restore" ]]; then
        aws s3 cp s3://$S3_BUCKET/$S3_RDS_BACKUP_DIR/$rdsbackup $LOCAL_WORKPATH/$rdsbackup    
    fi
    if [ "$destination" == "local-restore" ]; then
        restore_local $rdsbackup
    fi


    execute_command "rm $$BASTION_WORKPATH/$rdsbackup"
}

function backup_local() {
    localbackup=db_$(date +%s).sql
    PGPASSWORD=$PG_PASS_LOCAL pg_dump -U $PG_USER_LOCAL -h $PG_HOST_LOCAL -w $PG_NAME_LOCAL > $LOCAL_WORKPATH/$localbackup
    aws s3 cp $LOCAL_WORKPATH/$localbackup s3://$S3_BUCKET/$S3_LOCAL_BACKUP_DIR/$localbackup
    rm $LOCAL_WORKPATH/$localbackup
}

function restore_local() {
    backupfilename=$1 
    PGPASSWORD=$PG_PASS_LOCAL psql -h $PG_HOST_LOCAL -U $PG_USER_LOCAL -d $PG_SUPERUSER_LOCAL -w -c "DROP DATABASE IF EXISTS $PG_NAME_LOCAL;"
    PGPASSWORD=$PG_PASS_LOCAL psql -h $PG_HOST_LOCAL -U $PG_USER_LOCAL -d $PG_SUPERUSER_LOCAL -w -c "CREATE DATABASE $PG_NAME_LOCAL;"
    PGPASSWORD=$PG_PASS_LOCAL psql -h $PG_HOST_LOCAL -U $PG_USER_LOCAL -d $PG_SUPERUSER_LOCAL -w -c "GRANT ALL PRIVILEGES ON DATABASE $PG_NAME_LOCAL TO $PG_USER_LOCAL;"
    PGPASSWORD=$PG_PASS_LOCAL psql -h $PG_HOST_LOCAL -U $PG_USER_LOCAL -d $PG_SUPERUSER_LOCAL -w -c "ALTER DATABASE $PG_NAME_LOCAL OWNER TO $PG_USER_LOCAL;"
    PGPASSWORD=$PG_PASS_LOCAL psql -h $PG_HOST_LOCAL -U $PG_USER_LOCAL -d $PG_NAME_LOCAL -w -a -f $LOCAL_WORKPATH/$backupfilename
    rm $backupfilename
}


# Takes S3 backup and restores it on RDS
function restore_RDS() {

    environment_type="$1"
    # RDS TEST > EC2 > RDS WORK
    if [[ "$environment_type" == "prod" ]]; then
        RDS_DB_TO_RESTORE=$RDS_NAME_PROD
        execute_command "export PGPASSWORD=$RDS_PASSWORD; pg_dump -h $RDS_ENDPOINT -U $RDS_USER -d $PG_NAME_TEST -w -b -f $$BASTION_WORKPATH/dbbackup.sql"

    # S3 > RDS
    elif [[ "$environment_type" == "test" ]]; then
        RDS_DB_TO_RESTORE=$RDS_NAME_TEST
        # S3 -> EC2 : Find latest S3 backup fro local, download to EC2
        db_latest=$(get_latest_dump_file "$S3_LOCAL_BACKUP_DIR")    
        echo "Latest dump file is: $db_latest"
        db_latest=${db_latest##* }
        echo $db_latest
        execute_command "aws s3 cp s3://$S3_BUCKET/$S3_LOCAL_BACKUP_DIR/$db_latest $$BASTION_WORKPATH/dbbackup.sql"

    fi




    
    # EC2 -> RDS : Delete RDS DB, initialize new one, restore from EC2
    # execute_command "\"export PGPASSWORD=$RDS_PASSWORD; psql -h $RDS_ENDPOINT -U $RDS_USER -d $RDS_DBNAME -c \\\"DROP DATABASE IF EXISTS $RDS_DB_TO_RESTORE;\\\"\""
    # execute_command "\"export PGPASSWORD=$RDS_PASSWORD; psql -h $RDS_ENDPOINT -U $RDS_USER -d $RDS_DBNAME -c \\\"CREATE DATABASE $RDS_DB_TO_RESTORE;\\\"\""
    execute_command "\"export PGPASSWORD=$RDS_PASSWORD; psql -h $RDS_ENDPOINT -U $RDS_USER -d $RDS_DBNAME -c \\\"DROP DATABASE IF EXISTS $RDS_DB_TO_RESTORE;\\\"\""
    execute_command "\"export PGPASSWORD=$RDS_PASSWORD; psql -h $RDS_ENDPOINT -U $RDS_USER -d $RDS_DBNAME -c \\\"CREATE DATABASE $RDS_DB_TO_RESTORE;\\\"\""
    execute_command "export PGPASSWORD=$RDS_PASSWORD; psql -h $RDS_ENDPOINT -U $RDS_USER -d $RDS_DB_TO_RESTORE -a -f $$BASTION_WORKPATH/dbbackup.sql"

    # Cleanup: Delete from EC2
    execute_command "sudo rm $$BASTION_WORKPATH/dbbackup.sql"

}

function retrieve_s3() {
    destination=$1
    db_latest=$(get_latest_dump_file "$S3_LOCAL_BACKUP_DIR")
    db_latest=${db_latest##* }
    aws s3 cp s3://$S3_BUCKET/$S3_LOCAL_BACKUP_DIR/$db_latest $LOCAL_WORKPATH/$db_latest
    if [ "$destination" == "local-restore" ]; then
        restore_local $db_latest
    fi


}


# START INSTANCE IF STOPPED
function ec2_start(){
    echo "-----------------------------------------------------"
    INSTANCE_STATE=$(aws ec2 describe-instances --instance-ids $BASTION_INSTANCE_ID --region us-east-1 --query 'Reservations[0].Instances[0].State.Name' --output text)
    if [[ "$INSTANCE_STATE" == "stopped" ]]; then
        echo "Starting instance $BASTION_INSTANCE_ID..."
        aws ec2 start-instances --instance-ids $BASTION_INSTANCE_ID
        # Wait for the EC2 instance to be running (this )
        aws ec2 wait instance-running --instance-ids $BASTION_INSTANCE_ID
        # Send a simple echo command via SSM to ensure the instance is ready for further commands
        wait_for_ssm_agent $BASTION_INSTANCE_ID
        execute_command "ls"
    elif [[ "$INSTANCE_STATE" == "running" ]]; then
        echo "Instance $BASTION_INSTANCE_ID is already running."
    else
        echo "Warning: Instance $INSTANCE_STATE is in state $INSTANCE_STATE. Please wait or check the instance manually."
        exit 1
    fi
}

# # UPDATE EC2 PACKAGES
function ec2_update(){
    echo "-----------------------------------------------------"
    echo '|| apt-get update'
    execute_command "sudo apt-get update -y"
    echo '|| apt-get upgrade'
    execute_command "sudo apt-get upgrade -y"
    echo '|| apt-get install unzip'
    echo 'DONE: apt-get update'
}

# COMPARE SQL VERSIONS BETWEEN EC2 & RDS
function ec2_compare_psql() {
    echo "-----------------------------------------------------"
    echo 'GETTING: RDS & LOCAL psql versions'
    # Get RDS version
    RDS_VERSION=$(aws rds describe-db-instances --db-instance-identifier $RDS_IDENTIFIER --query 'DBInstances[0].EngineVersion')
    RDS_MAJOR_VERSION=$(echo "$RDS_VERSION" | tr -d '"' | cut -d'.' -f1)
    # Get EC2 version
    EC2_VERSION=$(execute_command "psql --version")
    EC2_MAJOR_VERSION=$(echo "$EC2_VERSION" | grep -oP '\b\d+' | head -1)
    # Print results
    echo "RDS VERSION: $RDS_MAJOR_VERSION -- ($RDS_VERSION)"
    echo "EC2 VERSION: $EC2_MAJOR_VERSION -- ($EC2_VERSION)"
    # Compare results - and update if need be
    if (( "$RDS_MAJOR_VERSION" > "$EC2_MAJOR_VERSION" )); then
        echo "RDS MAJOR VERSION IS AHEAD, UPDATING EC2 VERSION"
        execute_command "sudo apt-get install -y postgresql-client-$RDS_MAJOR_VERSION"
    elif (( "$RDS_MAJOR_VERSION" < "$EC2_MAJOR_VERSION" )); then
        echo "RDS MAJOR VERSION IS BEHIND EC2, PLEASE UPDATE RDS VERSION"
    else
        echo "PSQLVERSIONS MATCH, ALL GOOD!"
    fi
}

function ec2_shutdown {
    echo "-----------------------------------------------------"
    echo 'SHUTTING DOWN INSTANCE!'
    INSTANCE_STATE=$(aws ec2 describe-instances --instance-ids $BASTION_INSTANCE_ID --region us-east-1 --query 'Reservations[0].Instances[0].State.Name' --output text)
    if [[ "$INSTANCE_STATE" == "running" ]]; then
        echo "Stopping instance $BASTION_INSTANCE_ID..."
        aws ec2 stop-instances --instance-ids $BASTION_INSTANCE_ID
        # Wait for the EC2 instance to be stopped
        aws ec2 wait instance-stopped --instance-ids $BASTION_INSTANCE_ID
    elif [[ "$INSTANCE_STATE" == "stopped" ]]; then
        echo "Instance $BASTION_INSTANCE_ID is already stopped."
    elif [[ "$INSTANCE_STATE" == "terminated" ]]; then
        echo "Error: Instance $BASTION_INSTANCE_ID has been terminated and cannot be stopped."
        exit 1
    else
        echo "Warning: Instance $BASTION_INSTANCE_ID is in state $INSTANCE_STATE. Please wait or check the instance manually."
        exit 1
    fi
}




# START INSTANCE, RUN UPDATES AND SQL COMPARES - IF EC2 IS REQUIRED
do_not_require_ec2=("get-s3" "backup-local" "update-local-s3" "check-local-db")
command=$1
ec2required=0
for unrequired in "${do_not_require_ec2[@]}"; do
    if [[ "${unrequired}" == "${command}" ]]; then
        ec2required=1
        break
    fi
done


if [[ "${ec2required}" -eq 0 ]]; then
    ec2_start
    ec2_update
    ec2_compare_psql
fi


# ----------------- MAIN ------------------------
if ! [ "$1" == "check-local-db" ]; then
    echo "-----------------------------------------------------"
    echo "RUNNING OPTION: $1!"
fi

# update-rds-test:   S3_LOCAL > RDS TEST
if [ "$1" == "update-rds-test" ]; then
    restore_RDS "test"
# update-rds-prod:   RDS TESt > RDS PROD
elif [ "$1" == "update-rds-prod" ]; then
    backup_RDS "s3"
    restore_RDS "prod"
# backup-rds    :   RDS > S3_RDS
elif [ "$1" == "backup-rds" ]; then
    backup_RDS "s3"
# update-local  :   RDS > S3_RDS > LOCAL + RESTORE
elif [ "$1" == "update-local-rds" ]; then
    backup_RDS "local-restore"
# update-local  :   S3 > LOCAL + RESTORE
elif [ "$1" == "update-local-s3" ]; then
    retrieve_s3 "local-restore"
# backup-local  :   LOCAL > S3_LOCAL
elif [ "$1" == "backup-local" ]; then
    backup_local
# get-rds       :   RDS > S3_RDS > LOCAL
elif [ "$1" == "get-rds" ]; then
    backup_RDS "local"
# get-s3        :   S3_LOCAL > LOCAL
elif [ "$1" == "get-s3" ]; then
    retrieve_s3
# check-local-db:   Checks if local db is empty
elif [ "$1" == "check-local-db" ]; then
    TABLE_COUNT=$(PGPASSWORD=$PG_PASS_LOCAL psql -h $PG_HOST_LOCAL -U $PG_USER_LOCAL -d $PG_NAME_LOCAL -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';")
    if [[ "$TABLE_COUNT" -eq 0 ]]; then
        # Exit 2 if it's empty
        echo "empty"
    else
        # Exit 3 if it's not empty
        echo "not empty"
    fi    
fi

#STOP INSTANCE - IF EC2 IS REQUIRED
if [[ "${ec2required}" -eq 0 ]]; then
    ec2_shutdown
fi
