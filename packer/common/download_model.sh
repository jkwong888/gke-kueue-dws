#!/bin/bash

# MODEL_ID=${MODEL_ID}
# MOUNT_PATH=/mnt/gcs
# MODEL_PREFIX=model-data
# BUCKET_ID=jkwng-model-data

echo "installing python and dependencies ..."
sudo apt install -y python3-pip python3.11-venv
python3 -mvenv .venv
source .venv/bin/activate

echo "installing huggingface CLI ..."
pip install huggingface-hub[cli]

export HF_TOKEN=$(gcloud secrets versions access latest --secret=hf_token --project=jkwng-vertex-playground)

echo "downloading model to ${MOUNT_PATH}/${MODEL_PREFIX} ..."
mkdir -p ${MOUNT_PATH}/${MODEL_PREFIX}/${MODEL_ID}
hf download ${MODEL_ID} --local-dir ${MOUNT_PATH}/${MODEL_PREFIX}/${MODEL_ID}

echo "uploading model to gs://${BUCKET_ID}/${MODEL_PREFIX}/${MODEL_ID} ..."
if [ ! -z "${BUCKET_ID}" ]; then
    gcloud storage rsync ${MOUNT_PATH}/${MODEL_PREFIX}/${MODEL_ID} gs://${BUCKET_ID}/${MODEL_PREFIX}/${MODEL_ID}
fi