from django.conf import settings
import boto3


def s3_get_file_list(bucket, prefix):
    s3 = boto3.client('s3')
    paginator = s3.get_paginator('list_objects_v2')

    files = []
    for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
        files.extend(page.get('Contents', []))

    # Sort all files by LastModified date in descending order
    sorted_files = sorted(files, key=lambda obj: obj['LastModified'], reverse=True)
    return sorted_files

def s3_retrieve_file_local(bucket, latest_file, target_path):
    s3 = boto3.client('s3')
    file_path = f"{target_path}/{latest_file}"
    try:
        s3.download_file(bucket, latest_file, file_path)
        print(f"Downloaded '{latest_file}' to '{latest_file}'")
    except Exception as e:
        print(f"An error occurred while downloading the file: {e}")