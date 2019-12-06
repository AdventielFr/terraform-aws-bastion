import boto3
import pytest
import os
import mock
from moto import mock_s3
from datetime import datetime
from datetime import timedelta

from lambda_handler import main

BUCKET_NAME = 'some-bucket'

@mock.patch.dict(os.environ,{'AWS_S3_BUCKET':BUCKET_NAME})
def test_invalid_ssh_public_key_handler():
    with mock_s3():
        # Create the bucket
        conn = boto3.resource('s3')
        conn.create_bucket(Bucket=BUCKET_NAME)
        # Add a file
        boto3.client('s3').put_object(Bucket=BUCKET_NAME, Key="public-keys/sample", Body="")
        
        main(None, None)

        bucket = conn.Bucket(BUCKET_NAME)
        count = 0 
        for b in bucket.objects.all(): count+=1
        assert count==0

@mock.patch.dict(os.environ,{'AWS_S3_BUCKET':BUCKET_NAME})
def test_invalid_format_ssh_public_key_handler():
    with mock_s3():
        # Create the bucket
        conn = boto3.resource('s3')
        conn.create_bucket(Bucket=BUCKET_NAME)
        # Add a file
        boto3.client('s3').put_object(Bucket=BUCKET_NAME, Key="public-keys/sample_20190101340000.pub", Body="")
        
        main(None, None)

        bucket = conn.Bucket(BUCKET_NAME)
        count = 0 
        for b in bucket.objects.all(): count+=1
        assert count==0


@mock.patch.dict(os.environ,{'AWS_S3_BUCKET':BUCKET_NAME})
def test_obsolete_ssh_public_key_handler():
    with mock_s3():
        # Create the bucket
        conn = boto3.resource('s3')
        conn.create_bucket(Bucket=BUCKET_NAME)
        date_limit=(datetime.now()- timedelta(hours=1)).strftime('%Y%m%d%H%M%S')

        # Add a file
        boto3.client('s3').put_object(Bucket=BUCKET_NAME, Key=f"public-keys/sample_{date_limit}.pub", Body="")
        
        main(None, None)

        bucket = conn.Bucket(BUCKET_NAME)
        count = 0 
        for b in bucket.objects.all(): count+=1
        assert count==0

@mock.patch.dict(os.environ,{'AWS_S3_BUCKET':BUCKET_NAME})
def test_valid_ssh_public_key_handler():
    with mock_s3():
        # Create the bucket
        conn = boto3.resource('s3')
        conn.create_bucket(Bucket=BUCKET_NAME)
        date_limit=(datetime.now()+ timedelta(hours=1)).strftime('%Y%m%d%H%M%S')

        # Add a file
        boto3.client('s3').put_object(Bucket=BUCKET_NAME, Key=f"public-keys/sample_{date_limit}.pub", Body="")
        
        main(None, None)

        bucket = conn.Bucket(BUCKET_NAME)
        count = 0 
        for b in bucket.objects.all(): count+=1
        assert count==1
