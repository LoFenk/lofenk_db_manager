

lofenk_dbs = {
    'drive1':
        {
            'type': 's3', #Only s3 buckets available for now for backup drives
            'bucket': None,
            'dir_path': '/', #needs a trailing slash
        },

    'db1':
        {
        'type': 'pgdb',
        'name': None,
        'user': None,
        'pass': None,
        'host': None,
        'superuser': None,
        'superuser_pass': None,
        'instance_identifier': None,
        },

    'bastion1':
        {
        'type': 'bastion',
        'path': None,
        },

    'local':
        {
        'type': 'local',
        'path': None,
        }
    }


# # BASTION
# BASTION_INSTANCE_ID = getattr(settings, 'BASTION_INSTANCE_ID', None)
# BASTION_WORKPATH = getattr(settings, 'BASTION_WORKPATH', None)

# # LOCAL
# LOCAL_WORKPATH = getattr(settings, 'LOCAL_WORKPATH', None)

# # POSTGRES
# PG_PASS_PROD = getattr(settings, 'PG_PASS_PROD', None)
# PG_PASS_TEST = getattr(settings, 'PG_PASS_TEST', None)
# PG_PASS_DEV = getattr(settings, 'PG_PASS_DEV', None)

# PG_USER_PROD = getattr(settings, 'PG_USER_PROD', None)
# PG_USER_TEST = getattr(settings, 'PG_USER_TEST', None)
# PG_USER_DEV = getattr(settings, 'PG_USER_DEV', None)

# PG_SUPERUSER_PROD = getattr(settings, 'PG_SUPERUSER_PROD', None)
# PG_SUPERUSER_TEST = getattr(settings, 'PG_SUPERUSER_TEST', None)
# PG_SUPERUSER_DEV = getattr(settings, 'PG_SUPERUSER_DEV', None)

# PG_NAME_PROD = getattr(settings, 'PG_NAME_PROD', None)
# PG_NAME_TEST = getattr(settings, 'PG_NAME_TEST', None)
# PG_NAME_DEV = getattr(settings, 'PG_NAME_DEV', None)


# # RDS
# RDS_PASSWORD = getattr(settings, 'RDS_PASSWORD', None)
# RDS_ENDPOINT = getattr(settings, 'RDS_ENDPOINT', None)
# RDS_USER = getattr(settings, 'RDS_USER', None)
# RDS_DBNAME = getattr(settings, 'RDS_DBNAME', None)
# RDS_IDENTIFIER = getattr(settings, 'RDS_DB_IDENTIFIER', None)

# # S3
# S3_BUCKET = getattr(settings, 'S3_BUCKET', None)
# S3_RDS_BACKUP_DIR = getattr(settings, 'S3_RDS_BACKUP_DIR', None)
# S3_DEV_BACKUP_DIR = getattr(settings, 'S3_DEV_BACKUP_DIR', None)
# S3_DB_PREFIX = getattr(settings, 'S3_DB_PREFIX', None)