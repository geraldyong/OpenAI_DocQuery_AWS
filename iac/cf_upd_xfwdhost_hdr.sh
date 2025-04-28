#!/bin/bash

# Updates the origin headers.

CF_ID=$1
CF_XFWDH=$2
DIST_CFG_FILE=.dist_cfg.tmp

# Extract the distribution config file.
aws cloudfront get-distribution-config  --id ${CF_ID} > ${DIST_CFG_FILE}

# Extract the ETag.
CF_ETAG=`grep ETag ${DIST_CFG_FILE} | cut -f4 -d'"'`

# Delete non-required lines.
if [ `uname` = "Darwin" ]; then
  sed -i '' -e "/ETag/d" ${DIST_CFG_FILE}
  sed -i '' -e "/DistributionConfig/d" ${DIST_CFG_FILE}
  sed -i '' '$d' ${DIST_CFG_FILE}

  # Replace the X-Forwarded-Host header with the new host.
  sed -i '' "s/\*\.cloudfront\.net/${CF_XFWDH}/" ${DIST_CFG_FILE}
else
  sed -i -e "/ETag/d" ${DIST_CFG_FILE}
  sed -i -e "/DistributionConfig/d" ${DIST_CFG_FILE}
  sed -i '$d' ${DIST_CFG_FILE}

  # Replace the X-Forwarded-Host header with the new host.
  sed -i "s/\*\.cloudfront\.net/${CF_XFWDH}/" ${DIST_CFG_FILE}
fi

# Update the distribution config file.
aws cloudfront update-distribution --id ${CF_ID} --if-match ${CF_ETAG} --no-cli-pager --distribution-config file://${DIST_CFG_FILE}

# Clean up.
rm -f ${DIST_CFG_FILE}
