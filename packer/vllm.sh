#!/bin/bash


MODEL_DIR=/mnt/disks/model-data
BUCKET_ID="jkwng-llama-experiments"
MODEL_ID=google/gemma-3-4b-it
BUCKET_PATH="vllm-cache"
CACHE_MOUNT_PATH=/mnt/disks/cache

echo "Installing gcsfuse ..."
export GCSFUSE_REPO=gcsfuse-`lsb_release -c -s`
echo "deb [signed-by=/usr/share/keyrings/cloud.google.asc] https://packages.cloud.google.com/apt $GCSFUSE_REPO main" | sudo tee /etc/apt/sources.list.d/gcsfuse.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo tee /usr/share/keyrings/cloud.google.asc

sudo apt update
sudo apt install -y gcsfuse || true

echo "installing python and dependencies ..."
sudo apt install -y python3-dev || true

sudo mkdir -p ${CACHE_MOUNT_PATH}
sudo chmod a+w ${CACHE_MOUNT_PATH}
gcsfuse --only-dir ${BUCKET_PATH} ${BUCKET_ID} ${CACHE_MOUNT_PATH}
sudo mkdir -p ${CACHE_MOUNT_PATH}/${MODEL_ID}
sudo chmod a+w ${CACHE_MOUNT_PATH}/${MODEL_ID}

python3 -mvenv .venv
source .venv/bin/activate

pip install vllm

VLLM_CACHE_ROOT=${CACHE_MOUNT_PATH}

python <<END
from vllm import LLM
from vllm.config import CompilationConfig

llm = LLM(
    model="${MODEL_DIR}/models/${MODEL_ID}",
    compilation_config=CompilationConfig(
        cache_dir="${CACHE_MOUNT_PATH}/${MODEL_ID}",
    )
)
END

# TODO: instead of gcsfuse, we may want to zip up the vllm cache directory and copy it manually to GCS
# GCS small object file perfomance means caching to GCS doesn't actually save that much load time