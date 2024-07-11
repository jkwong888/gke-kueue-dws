data "google_project" "registry_project" {
    project_id = var.registry_project_id
}

data "google_artifact_registry_repository" "my-repo" {
  project = data.google_project.registry_project.project_id
  location      = "us"
  repository_id = "gcr.io"
}

resource "google_artifact_registry_repository_iam_member" "member" {
  project = data.google_project.registry_project.project_id
  location = data.google_artifact_registry_repository.my-repo.location
  repository = data.google_artifact_registry_repository.my-repo.name
  role = "roles/artifactregistry.reader"
  member = format("serviceAccount:%s", google_service_account.gke_sa.email)
}

resource "google_storage_bucket_iam_member" "gke_sa_image_pull" {
    depends_on = [
        module.service_project.enabled_apis,
    ]

    bucket = format("artifacts.%s.appspot.com", data.google_project.registry_project.project_id)
    role = "roles/storage.objectViewer"
    member = format("serviceAccount:%s", google_service_account.gke_sa.email)
}

