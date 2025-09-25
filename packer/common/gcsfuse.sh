#!/bin/bash


# mount GCS bucket using gcsfuse

# set these through environment variables
# BUCKET_ID="jkwng-llama-experiments"
# MODEL_ID=${MODEL_ID}
# BUCKET_PATH="vllm-cache"
# MOUNT_PATH="/mnt/gcs"

echo "Installing gcsfuse ..."
export GCSFUSE_REPO=gcsfuse-`lsb_release -c -s`
echo "deb [signed-by=/usr/share/keyrings/cloud.google.asc] https://packages.cloud.google.com/apt $GCSFUSE_REPO main" | sudo tee /etc/apt/sources.list.d/gcsfuse.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo tee /usr/share/keyrings/cloud.google.asc

sudo apt update
sudo apt install -y gcsfuse || true

echo "installing python and dependencies ..."
sudo apt install -y python3-dev || true

echo "mounting cache dir to ${MOUNT_PATH}/${CACHE_PREFIX} ..."
sudo mkdir -p ${MOUNT_PATH}/${CACHE_PREFIX}
sudo chmod a+w ${MOUNT_PATH}/${CACHE_PREFIX}
gcsfuse --only-dir ${CACHE_PREFIX} ${BUCKET_ID} ${MOUNT_PATH}/${CACHE_PREFIX}

# sudo mkdir -p ${CACHE_MOUNT_PATH}/${MODEL_ID}
# sudo chmod a+w ${CACHE_MOUNT_PATH}/${MODEL_ID}
