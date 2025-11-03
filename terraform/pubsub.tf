# create a pubsub topic for changes to the data bucket
resource "google_pubsub_topic" "data_bucket_changes" {
  project = module.service_project.project_id
  name    = "data-bucket-changes"
}

data "google_storage_project_service_account" "gcs_sa" {
    project = module.service_project.project_id
}

resource "google_pubsub_topic_iam_member" "gcs_pub" {
  project = module.service_project.project_id
  topic   = google_pubsub_topic.data_bucket_changes.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${data.google_storage_project_service_account.gcs_sa.email_address}"
}

resource "google_pubsub_subscription" "data-bucket-changes-sub" {
  project = module.service_project.project_id
  name    = "data-bucket-changes-sub"
  topic   = google_pubsub_topic.data_bucket_changes.name

  ack_deadline_seconds = 60

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }
}

resource "google_pubsub_subscription_iam_member" "data_bucket_changes_sub_processor" {
  project      = module.service_project.project_id
  subscription = google_pubsub_subscription.data-bucket-changes-sub.name
  role         = "roles/pubsub.subscriber"
  member       = "principal://iam.googleapis.com/projects/${module.service_project.number}/locations/global/workloadIdentityPools/${module.service_project.project_id}.svc.id.goog/subject/ns/processor/sa/pubsub-gcs-processor"
}

resource "google_pubsub_subscription_iam_member" "data_bucket_changes_sub_argo_events" {
  project      = module.service_project.project_id
  subscription = google_pubsub_subscription.data-bucket-changes-sub.name
  role         = "roles/pubsub.subscriber"
  member       = "principal://iam.googleapis.com/projects/${module.service_project.number}/locations/global/workloadIdentityPools/${module.service_project.project_id}.svc.id.goog/subject/ns/argo-events/sa/default"
}