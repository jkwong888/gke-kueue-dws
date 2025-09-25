resource "google_storage_bucket_iam_member" "gcs_model_storage_reader" {
    depends_on = [
        module.service_project.enabled_apis,
    ]

    bucket = google_storage_bucket.model_bucket.name
    role = "roles/storage.objectAdmin"
    member = format("serviceAccount:%s", google_service_account.gke_sa.email)
}

resource "google_storage_bucket_iam_member" "gcs_model_storage_reader_default_compute" {
    depends_on = [
        module.service_project.enabled_apis,
    ]

    bucket = google_storage_bucket.model_bucket.name
    role = "roles/storage.objectAdmin"
    member = format("serviceAccount:%d-compute@developer.gserviceaccount.com", module.service_project.number)
}

resource "google_storage_bucket" "model_bucket" {
    project = module.service_project.project_id
    location = var.gke_cluster_location
    name = "jkwng-model-data"

    hierarchical_namespace {
        enabled = true
    }

    uniform_bucket_level_access = true
}

resource "google_storage_bucket" "data_bucket" {
    project = module.service_project.project_id
    location = var.gke_cluster_location
    name = "jkwng-data"

    uniform_bucket_level_access = true

}

resource "google_storage_notification" "notification" {
    bucket = google_storage_bucket.data_bucket.name
    payload_format = "JSON_API_V1"
    topic = google_pubsub_topic.data_bucket_changes.id
    event_types = ["OBJECT_FINALIZE"]

    # object_name_prefix = ""

    depends_on = [
        google_pubsub_topic.data_bucket_changes,
        google_pubsub_topic_iam_member.gcs_pub,
    ]
}

resource "google_storage_bucket_iam_member" "gcs_data_bucket_reader" {
    depends_on = [
        module.service_project.enabled_apis,
    ]

    bucket  = google_storage_bucket.data_bucket.name
    role    = "roles/storage.objectAdmin"
    member  = "principal://iam.googleapis.com/projects/${module.service_project.number}/locations/global/workloadIdentityPools/${module.service_project.project_id}.svc.id.goog/subject/ns/processor/sa/pubsub-argo-processor"
}