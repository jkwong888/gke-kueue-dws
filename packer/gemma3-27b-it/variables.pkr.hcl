# Below variables are set with example values. Please adjust them accordingly.
variable "project_id" {
    type = string
}

variable "zone" {
    type = string
}

variable "network" {}
variable "subnetwork" {}

# variable "builder_sa" {
#   type = string
# }

variable "disk_name" {
    type = string
    default = "model-data"
}

variable "model_dir" {
    type = string
    default = "/mnt/disks/model-data"
}

variable "cache_dir" {
    type = string
    default = "/mnt/disks/cache"
}

variable "mount_path" {
    type = string
    default = "/mnt/gcs"
}

variable "model_id" {
    type = string
    default = "google/gemma-3-27b-it"
}

variable "model_bucket" {}
variable "bucket_model_prefix" {
    type = string
    default = "models"
}
variable "bucket_cache_prefix" {
    type = string
    default = "vllm-cache"
}


# builder_sa = "packer@my-project.iam.gserviceaccount.com"