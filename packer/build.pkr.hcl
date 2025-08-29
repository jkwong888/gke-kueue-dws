packer {
  required_plugins {
    googlecompute = {
      version = ">= 1.1.1"
      source = "github.com/hashicorp/googlecompute"
    }
  }
}

variable "project_id" {
  type = string
}

variable "zone" {
  type = string
}

# variable "builder_sa" {
#   type = string
# }

source "googlecompute" "model-data-build" {
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

  network = "projects/jkwng-nonprod-vpc/global/networks/shared-vpc-nonprod-1"
  subnetwork = "projects/jkwng-nonprod-vpc/regions/us-central1/subnetworks/kueue-dev"

  disk_attachment {
    device_name = "model-data"
    volume_type = "pd-balanced"
    volume_size = 60
    create_image = true
  }
}

build {
  sources = ["sources.googlecompute.model-data-build"]

  # needs a reboot after installing dependencies
  provisioner "shell" {
    script = "install_nvidia_driver.sh"
    expect_disconnect = true
    pause_after = "30s"
  }

  # doesn't need a reboot after installing driver
  provisioner "shell" {
    script = "install_nvidia_driver.sh"
    expect_disconnect = true
    pause_after = "5s"
  }

  # needs a reboot after cuda install
  provisioner "shell" {
    script = "install_cuda.sh"
    expect_disconnect = true
    pause_after = "45s"
  }

  # prepare the model disk
  provisioner "shell" {
    script = "prepare_disk.sh"
  }

  # download the model
  provisioner "shell" {
    script = "download_model.sh"
    pause_before = "5s"
  }

  # build the vllm graph cache ahead of time - this actually doesn't work because the secondary boot disk is read-only
  provisioner "shell" {
    script = "vllm.sh"
    pause_before = "5s"
  }

}