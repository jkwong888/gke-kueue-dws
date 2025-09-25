packer {
  required_plugins {
    googlecompute = {
      version = ">= 1.1.1"
      source = "github.com/hashicorp/googlecompute"
    }
  }
}

source "googlecompute" "model-data-build" {
  image_name                  = "gemma3-4b-it-model-data-{{timestamp}}"
  project_id                  = var.project_id
  source_image_family         = "debian-12"
  zone                        = var.zone
  ssh_username                = "packer"
  tags                        = ["packer"]
  machine_type                = "g2-standard-4"
  # preemptible                 = true
  on_host_maintenance         = "TERMINATE"

  disk_type              = "pd-balanced"
  disk_size                    = 100
#   impersonate_service_account = var.builder_sa

  scopes = [
    "https://www.googleapis.com/auth/cloud-platform"
  ]

  omit_external_ip = true
  use_internal_ip = true
  use_iap = true

  network = var.network
  subnetwork = var.subnetwork

  disk_attachment {
    device_name = var.disk_name
    volume_type = "pd-balanced"
    volume_size = 60
    create_image = true
  }
}

build {
  sources = ["sources.googlecompute.model-data-build"]

  # needs a reboot after installing dependencies
  provisioner "shell" {
    script = "../common/install_nvidia_driver.sh"
    expect_disconnect = true
    pause_after = "45s"
  }

  # doesn't need a reboot after installing driver
  provisioner "shell" {
    script = "../common/install_nvidia_driver.sh"
    expect_disconnect = true
    pause_after = "5s"
  }

  # needs a reboot after cuda install
  provisioner "shell" {
    script = "../common/install_cuda.sh"
    expect_disconnect = true
    pause_after = "45s"
  }

  # prepare the model disk
  provisioner "shell" {
    environment_vars = [
      "MOUNT_PATH=${var.mount_path}/models",
      "DISK_NAME=${var.disk_name}"
    ]
    script = "../common/prepare_disk.sh"
  }

  # prepare the model disk
  provisioner "shell" {
    environment_vars = [ 
      "BUCKET_ID=${var.model_bucket}",
      "MODEL_PREFIX=${var.bucket_model_prefix}",
      "CACHE_PREFIX=${var.bucket_cache_prefix}",
      "MOUNT_PATH=${var.mount_path}",
    ]

    pause_before = "5s"
    script = "../common/gcsfuse.sh"
  }


  # download the model
  provisioner "shell" {
    environment_vars = [ 
      "MOUNT_PATH=${var.mount_path}",
      "MODEL_PREFIX=${var.bucket_model_prefix}",
      "MODEL_ID=${var.model_id}",
    ]

    script = "../common/download_model.sh"
  }

  # build the vllm graph cache ahead of time - this actually doesn't work because the secondary boot disk is read-only
  provisioner "shell" {
    environment_vars = [ 
      "MOUNT_PATH=${var.mount_path}",
      "MODEL_PREFIX=${var.bucket_model_prefix}",
      "CACHE_PREFIX=${var.bucket_cache_prefix}",
      "MODEL_ID=${var.model_id}",
    ]

    script = "../common/vllm.sh"
    # pause_before = "5s"
  }

}