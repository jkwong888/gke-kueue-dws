locals {
  gke_sa_roles = [
    "roles/monitoring.metricWriter",
    "roles/logging.logWriter",
    "roles/monitoring.viewer",
  ]
}

resource "random_string" "gke_nodepool_network_tag" {
  length           = 8
  special          = false
  upper            = false
}

resource "google_project_iam_member" "container_host_service_agent" {
  depends_on = [
    module.service_project.enabled_apis,
  ]

  project     = data.google_project.host_project.id
  role        = "roles/container.hostServiceAgentUser"
  member      = format("serviceAccount:service-%d@container-engine-robot.iam.gserviceaccount.com", module.service_project.number)
}

resource "google_service_account" "gke_sa" {
  project       = module.service_project.project_id
  account_id    = format("%s-sa", var.gke_cluster_name)
  display_name  = format("%s cluster service account", var.gke_cluster_name)
}

resource "google_project_iam_member" "gke_sa_role" {
  count   = length(local.gke_sa_roles) 
  project = module.service_project.project_id
  role    = element(local.gke_sa_roles, count.index) 
  member  = format("serviceAccount:%s", google_service_account.gke_sa.email)
}

resource "google_container_cluster" "primary" {
  provider = google-beta

  lifecycle {
    ignore_changes = [
      # Ignore changes to tags, e.g. because a management agent
      # updates these based on some ruleset managed elsewhere.
      //node_pool["node_count"],
      node_pool["node_count"],
    ]
  }

  depends_on = [
    module.service_project.enabled_apis,
    module.service_project.subnet_users,
    module.service_project.hostServiceAgentUser,
    google_project_iam_member.gke_sa_role,
    google_project_organization_policy.shielded_vm_disable,
    google_project_organization_policy.oslogin_disable,
  ]


  name     = var.gke_cluster_name
  location = module.service_project.subnets[0].region
  project  = module.service_project.project_id

  remove_default_node_pool = true
  initial_node_count       = 1

  release_channel  {
      channel = "REGULAR"
  }

  network = data.google_compute_network.shared_vpc.self_link
  subnetwork = module.service_project.subnets[0].self_link

  #enable_autopilot = true

  ip_allocation_policy {
    cluster_secondary_range_name = var.gke_subnet_pods_range_name
    services_secondary_range_name = var.gke_subnet_services_range_name
  }


  private_cluster_config {
    enable_private_nodes = true
    master_ipv4_cidr_block = var.gke_cluster_master_range
  }

  workload_identity_config {
    workload_pool = "${module.service_project.project_id}.svc.id.goog"
  }

  cluster_autoscaling {
    enabled = false # this settings is for nodepool autoprovisioning
    autoscaling_profile = "OPTIMIZE_UTILIZATION"
  }

}

resource "google_container_node_pool" "primary_preemptible_nodes" {
  lifecycle {
    ignore_changes = [
      node_count,
    ]
  }

  depends_on = [
    google_container_cluster.primary,
  ]

  name       = format("%s-default-pvm", var.gke_cluster_name)
  location   = var.gke_cluster_location
  cluster    = var.gke_cluster_name
  node_count = var.gke_default_nodepool_initial_size
  project    = module.service_project.project_id

  autoscaling {
    min_node_count = var.gke_default_nodepool_min_size
    max_node_count = var.gke_default_nodepool_max_size
  }

  node_locations = [
    "us-central1-c"
  ]


  node_config {
    preemptible  = var.gke_use_preemptible_nodes
    machine_type = var.gke_default_nodepool_machine_type

    metadata = {
      disable-legacy-endpoints = "true"
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    service_account = google_service_account.gke_sa.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    tags = [
      "b${random_string.gke_nodepool_network_tag.id}"
    ]
  }
}

resource "google_container_node_pool" "default_primary_nodes" {
  lifecycle {
    ignore_changes = [
      node_count,
    ]
  }

  depends_on = [
    google_container_cluster.primary,
  ]

  name       = format("%s-default-nodepool", var.gke_cluster_name)
  location   = var.gke_cluster_location
  cluster    = var.gke_cluster_name
  node_count = 0

  project    = module.service_project.project_id

  autoscaling {
    min_node_count = 0
    max_node_count = 4
    location_policy = "ANY"
  }

  node_locations = [
    "us-central1-c"
  ]

  node_config {
    preemptible  = var.gke_use_preemptible_nodes
    machine_type = "e2-standard-4"

    metadata = {
      disable-legacy-endpoints = "true"
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    service_account = google_service_account.gke_sa.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    tags = [
      "b${random_string.gke_nodepool_network_tag.id}"
    ]

  }
}

resource "google_container_node_pool" "a100_80gb_nodes" {
  lifecycle {
    ignore_changes = [
      node_count,
    ]
  }

  depends_on = [
    google_container_cluster.primary,
  ]

  name       = format("%s-a100-80gb-nodepool", var.gke_cluster_name)
  location   = var.gke_cluster_location
  cluster    = var.gke_cluster_name
  node_count = 0
  queued_provisioning {
    enabled = true
  }

  project    = module.service_project.project_id

  autoscaling {
    min_node_count = 0
    max_node_count = 4
    location_policy = "ANY"
  }

  node_locations = [
    "us-central1-a",
    "us-central1-c"
  ]

  management {
    auto_repair = false
    #auto_upgrade = false
  }

  node_config {
    machine_type = "a2-ultragpu-1g"

    guest_accelerator {
      type = "nvidia-a100-80gb"
      count = 1
      gpu_driver_installation_config {
        gpu_driver_version = "DEFAULT"
      }
    }

    gvnic {
      enabled = true
    }

    metadata = {
      disable-legacy-endpoints = "true"
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    service_account = google_service_account.gke_sa.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    reservation_affinity {
      consume_reservation_type = "NO_RESERVATION"
    }

    # TODDO these nodes might not be exposed directly to the internet so maybe we don't need this
    tags = [
      "b${random_string.gke_nodepool_network_tag.id}"
    ]

    # prevent workloads not scheduled with kueue from running
    taint {
      key = "kueue"
      value = "true"
      effect ="NO_SCHEDULE"
    }

  }
}

resource "google_compute_firewall" "cluster_api_webhook" {
  name    = "${var.gke_cluster_name}-allow-webhook"
  project     = data.google_project.host_project.project_id

  network = data.google_compute_network.shared_vpc.self_link

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = [var.gke_cluster_master_range]
  target_tags = [ "b${random_string.gke_nodepool_network_tag.id}" ]
}

