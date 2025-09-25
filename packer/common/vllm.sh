#!/bin/bash


# MOUNT_PATH=/mnt/gcs
# MODEL_PREFIX=model-data
# CACHE_PREFIX=vllm-cache
# MODEL_ID=google/gemma-3-4b-it

echo "installing python and dependencies ..."
sudo apt install -y python3-dev || true

sudo mkdir -p ${MOUNT_PATH}/${CACHE_PREFIX}/${MODEL_ID}
sudo chmod a+w ${MOUNT_PATH}/${CACHE_PREFIX}/${MODEL_ID}

python3 -mvenv .venv
source .venv/bin/activate

pip install vllm

VLLM_CACHE_ROOT=${MOUNT_PATH}/${CACHE_PREFIX}/${MODEL_ID}

python <<END
from vllm import LLM
from vllm.config import CompilationConfig

llm = LLM(
    model="${MOUNT_PATH}/${MODEL_PREFIX}/${MODEL_ID}",
    compilation_config=CompilationConfig(
        cache_dir="${MOUNT_PATH}/${CACHE_PREFIX}/${MODEL_ID}",
    )
)
END

# TODO: instead of gcsfuse, we may want to zip up the vllm cache directory and copy it manually to GCS
# GCS small object file perfomance means caching to GCS doesn't actually save that much load time