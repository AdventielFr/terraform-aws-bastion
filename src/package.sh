#!/bin/sh

#----------------------------
# build and package lambda
#----------------------------

rm -rf .serverless/ || true
sls plugin install --name serverless-iam-roles-per-function
sls plugin install --name serverless-plugin-log-retention
sls plugin install --name serverless-python-requirements
sls plugin install --name serverless-python-requirements
sls plugin install --name serverless-pseudo-parameters
sls plugin install --name serverless-plugin-existing-s3
sls package --name lambda_function_payload
rm ../bastion-find-and-remove-expired-ssh-keys.zip || true
mv .serverless/bastion-find-and-remove-expired-ssh-keys.zip ../
rm -rf .serverless/