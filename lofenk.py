from django.conf import settings
import boto3
from utils.s3 import s3_get_file_list, s3_retrieve_file_local
'''
TO DO backup_list:       returns a list of the dbs in the backup


get_backup          STORAGE > LOCAL/BASTION/INSTANCE
                    
                    arg1: Origin database, the one we want to retrieve
                    arg2: Where the db is stored, S3 bucket or other means of backup
                    arg3: Where we want to dump it
                    
                    Retrieves the backup from storage and sends it to a computer or instance.                                    

'''

def lofenk (*args, **kwargs):
    #action, db_origin=None, db_target=None, backup_drive=None, bastion=None, restore=False):
    if args[0] == 'get-backup':
        origin_db, storage, target = args[1], args[2], args[3]

        if origin_db['type'] == 'pgdb' and storage['type'] == 's3' and target['type'] == 'local':
            #Make the target path where the dump will be downloaded
            target_path = target['path'] if target['path'] != None else settings.BASE_DIR

            #Make the s3 prefix
            prefix = f"{storage['dir_path']}{origin_db['name']}" if storage['dir_path'] 

            #Get the sorted files
            sorted_files = s3_get_file_list(storage['bucket'], prefix)

            #Get the latest - eventually allow to get any
            latest_file = sorted_files[0]['Key'].split('/')[-1]

            #Retrieve the file
            s3_retrieve_file_local(storage['bucket'], latest_file, target_path)








