#!/bin/bash

DISK_NAME=model-data
MOUNT_PATH=/mnt/disks/${DISK_NAME}
MODEL_ID=google/gemma-3-4b-it


echo "installing python and dependencies ..."
sudo apt install -y python3-pip python3.11-venv
python3 -mvenv .venv
source .venv/bin/activate

echo "installing huggingface CLI ..."
pip install huggingface-hub[cli]

export HF_TOKEN=$(gcloud secrets versions access latest --secret=hf_token --project=jkwng-vertex-playground)

echo "downloading model to ${MOUNT_PATH}/models ..."
sudo mkdir -p ${MOUNT_PATH}/models
sudo chmod a+w ${MOUNT_PATH}/models
mkdir -p ${MOUNT_PATH}/models/${MODEL_ID}
hf download ${MODEL_ID} --local-dir ${MOUNT_PATH}/models/${MODEL_ID}


