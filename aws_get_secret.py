# import sys
# import boto3
# from botocore.exceptions import ClientError

# if __name__ == '__main__':
#     secret_name = sys.argv[1]
#     region_name = sys.argv[2]
#     secret = get_secret(secret_name, region_name)
#     if secret:
#         print(secret)
#     else:
#         sys.exit(1)


# # SECRETS MANAGER - GET SECRET
# def get_secret(secret_name, region_name):

#     # Create a Secrets Manager client
#     session = boto3.session.Session()
#     client = session.client(
#         service_name='secretsmanager',
#         region_name=region_name
#     )

#     try:
#         get_secret_value_response = client.get_secret_value(SecretId=secret_name)
#     except ClientError as e:
#         raise e

#     # Decrypts secret using the associated KMS key.
#     secret = get_secret_value_response['SecretString']
#     return secret

