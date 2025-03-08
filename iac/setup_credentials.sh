#!/bin/bash
#
# Updates credentails for AWS Account, AWS Profile, Access Key ID, Secret Access Key
# Written by Gerald Yong.
#
AWS_CREDENTIALS_FILE=~/.aws/credentials
TERRAFORM_VARS_FILE=terraform.tfvars

echo "Please provide the AWS Account ID: "
read ACCOUNT_ID

if [ "${ACCOUNT_ID}" = "" ]; then
  echo "CRITICAL: Account ID cannot be empty."
  exit 1
else
  # Update the Terraform variables file.
  sed -i '' "s/account_id = .*$/account_id = \"${ACCOUNT_ID}\"/" ${TERRAFORM_VARS_FILE}
fi

echo
echo "Please provide the AWS Profile to update: "
read AWS_PROFILE

if [ "${AWS_PROFILE}" = "" ]; then
  echo "CRITICAL: Profile cannot be empty."
  exit 1
fi

PROFILE_LINE=`grep -n ${AWS_PROFILE} ${AWS_CREDENTIALS_FILE} | cut -f1 -d':'`
NUM_LINES=`wc -l ${AWS_CREDENTIALS_FILE}  | awk '{ print $1 }'`
PROFILE_APPEND=no

if [ "${PROFILE_LINE}" = "" ]; then
  echo "WARNING: Cannot find profile. Will be adding to the file."
  PROFILE_APPEND=yes
else
  # Extract lines above the profile.
  LAST_LINES=$((NUM_LINES-PROFILE_LINE-2))
  head -n ${PROFILE_LINE} ${AWS_CREDENTIALS_FILE} > ${AWS_CREDENTIALS_FILE}.top

  if [ ${LAST_LINES} -eq 0 ]; then
    touch ${AWS_CREDENTIALS_FILE}.end
  else
    tail -n ${LAST_LINES} ${AWS_CREDENTIALS_FILE} > ${AWS_CREDENTIALS_FILE}.end
  fi
fi

# Update Terraform variables file.
sed -i '' "s/aws_profile = .*$/aws_profile = \"${AWS_PROFILE}\"/" ${TERRAFORM_VARS_FILE}

# Obtain the Access Key ID.
echo 
echo "Please provide the Access Key ID:"
read ACCESS_KEY_ID

if [ "${ACCESS_KEY_ID}" = "" ]; then
  echo "CRITICAL: No Access Key ID provided."
  rm -f ${AWS_CREDENTIALS_FILE}.top
  rm -f ${AWS_CREDENTIALS_FILE}.top
  exit 1
fi

# Obtain the Access Key Secret.
echo
echo "Please provide the Access Key Secret:"
read ACCESS_KEY_SECRET

if [ "${ACCESS_KEY_SECRET}" = "" ]; then
  echo "CRITICAL: No Access Key Secret provided."
  rm ${ACCESS_KEY_SECRET}.top
  exit 1
fi

# Update the AWS Credentials file.
if [ "${PROFILE_APPEND}" = "yes" ]; then
  echo "" >> ${AWS_CREDENTIALS_FILE}
  echo "[${AWS_PROFILE}]" >> ${AWS_CREDENTIALS_FILE}
  echo "aws_access_key_id = ${ACCESS_KEY_ID}" >> ${AWS_CREDENTIALS_FILE}
  echo "aws_secret_access_key = ${ACCESS_KEY_SECRET}" >> ${AWS_CREDENTIALS_FILE}
elif [ "${PROFILE_APPEND}" = "no" ]; then
  echo "aws_access_key_id = ${ACCESS_KEY_ID}" >> ${AWS_CREDENTIALS_FILE}.top
  echo "aws_secret_access_key = ${ACCESS_KEY_SECRET}" >> ${AWS_CREDENTIALS_FILE}.top
  cat ${AWS_CREDENTIALS_FILE}.top ${AWS_CREDENTIALS_FILE}.end > ${AWS_CREDENTIALS_FILE}
  rm -f ${AWS_CREDENTIALS_FILE}.top
  rm -f ${AWS_CREDENTIALS_FILE}.end
fi

echo
echo "INFO: Updated Terraform variables file ${TERRAFORM_VARS_FILE}."
echo "INFO: Updated AWS Credentials file ${AWS_CREDENTIALS_FILE}."