import boto3
import os
import re
from datetime import datetime
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)
formatter = logging.Formatter('%(asctime)s : %(name)s : %(levelname)s : %(message)s')
ch = logging.StreamHandler()
ch.setFormatter(formatter)
logger.addHandler(ch)

class PublicKey(object):
    def __init__(self,**kwargs):
        self.object_name = None
        self.file_name = None
        self.user_name = None
        self.limit_date = None
        self.__dict__.update(kwargs)
    
    def is_obsolete(self):
        return datetime.now()> self.limit_date

def main(event, context):
    s3_resource = boto3.resource('s3')
    bucket_url = os.environ.get('AWS_S3_BUCKET')
    bucket = s3_resource.Bucket(bucket_url)
    for item in bucket.objects.all():
        key = item.key
        if key.lower().endswith('readme.txt"):
            continue
        ssh_public_key = get_public_key(key)
        delete_object = False
        if not ssh_public_key:
            logger.info(f'Invalid public SSH key {key}, reason: invalid format')
            delete_object = True
        else:
            if ssh_public_key.is_obsolete():
                logger.info(f'Invalid public SSH key {key}, reason: obsolete')
                delete_object = True
            else:
                logger.info(f'Public SSH key {key} is valid')
        if delete_object:
            obj = s3_resource.Object(bucket_url, key)
            obj.delete()
            logger.info(f'Delete file {key}')

def to_datetime(data):
    try:
        return datetime.strptime(data, '%Y%m%d%H%M%S')
    except:
        return None

def get_public_key(object_name):
    data = next(reversed(list(object_name.split('/'))), '')
    pattern = '([a-zA-Z0-9_])+_(\\d{14})\\.pub'
    result = re.match(pattern, data)
    if result:
        limit_date = to_datetime(result.group(2))
        if limit_date:
            return PublicKey(
                object_name = object_name,
                file_name = data, 
                user_name = result.group(1), 
                limit_date = limit_date)
    return None
