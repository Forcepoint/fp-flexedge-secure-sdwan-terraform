#!/usr/bin/env bash
set -e
# Check whether primary server has already been provisioned.
mgmt_provisioning=$(aws ec2 --region "$1" describe-instances --instance-ids "$2" | \
  jq '.Reservations[0].Instances[0].Tags[] | select(.Key | contains("mgmt_provisioning")) | .Value' | \
  tr -d '"')
if [ "$mgmt_provisioning" = "ready" ]; then
  echo "SMC primary server is ready."
  exit 0
fi
# Primary server is not yet ready. Wait until it sends a message to queue.
while : ; do
  echo "Waiting for SMC primary server to be ready..."
  status=$(aws sqs --region "$1" receive-message --queue-url "$3" \
             --wait-time-seconds 20 | jq '.Messages')
  if [ "$status" ]; then
    break
  fi
done
echo "SMC primary server is ready."
