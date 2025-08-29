# Create packer disk image 

Create a disk image containing the cached model from huggingface.

Note that to run this I put my huggingface token into a secret called `hf_token` see [download_model.sh](./download_model.sh)

Also attempted to speed up vLLM init by caching the graphs into GCS using the GCS Fuse inside the packer image.  However this doesn't really improve startup times by that much because of GCS small file performance.  you can remove this step by removing the [vllm.sh](./vllm.sh] script.

the model disk can be used as a secondary boot disk in the GKE node pool or in the compute class definition when creating auto provisioned node pools.