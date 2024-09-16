# for network load balancer, allow traffic from the internet to reach the GKE nodes specified by the network tags

resource "google_compute_firewall" "allow_inbound_https" {
  name    = "${var.gke_cluster_name}-allow-https"
  project     = data.google_project.host_project.project_id

  network = data.google_compute_network.shared_vpc.self_link

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags = [ "b${random_string.gke_nodepool_network_tag.id}" ]
}