terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "google" {
  project = "woogie-sandbox-gcp"
  region  = "asia-northeast3"
}

# 필수 GCP API 활성화
resource "google_project_service" "cloudfunctions" {
  service = "cloudfunctions.googleapis.com"
}

resource "google_project_service" "cloudbuild" {
  service = "cloudbuild.googleapis.com"
}

resource "google_project_service" "run" {
  service = "run.googleapis.com"
}

resource "google_project_service" "artifactregistry" {
  service = "artifactregistry.googleapis.com"
}

resource "google_project_service" "cloudresourcemanager" {
  service = "cloudresourcemanager.googleapis.com"
}

# GCS 버킷
resource "google_storage_bucket" "memobox" {
  name          = "woogie-sandbox-gcp-memobox"
  location      = "ASIA-NORTHEAST3"
  force_destroy = true
}

# 서비스 계정 (GitHub Actions가 GCP에 로그인할 때 쓰는 전용 계정)
resource "google_service_account" "github_actions" {
  account_id   = "memobox-github-actions"
  display_name = "MemoBox GitHub Actions"
}

# Cloud Functions Developer 권한 (프로젝트 레벨)
resource "google_project_iam_member" "cf_developer" {
  project = "woogie-sandbox-gcp"
  role    = "roles/cloudfunctions.developer"
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

# Cloud Run 서비스 IAM 정책 설정 권한 (--allow-unauthenticated 적용에 필요)
resource "google_project_iam_member" "run_admin" {
  project = "woogie-sandbox-gcp"
  role    = "roles/run.admin"
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

# Cloud Functions 배포 시 기본 컴퓨트 서비스 계정 사용 권한
resource "google_service_account_iam_member" "github_actions_act_as" {
  service_account_id = "projects/woogie-sandbox-gcp/serviceAccounts/371125433847-compute@developer.gserviceaccount.com"
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.github_actions.email}"
}

# Storage Object Admin 권한 (버킷 한정)
resource "google_storage_bucket_iam_member" "storage_admin" {
  bucket = google_storage_bucket.memobox.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.github_actions.email}"
}

# 서비스 계정 JSON 키 (서비스 계정 인증키 생성)
resource "google_service_account_key" "github_actions_key" {
  service_account_id = google_service_account.github_actions.name
}

# sa-key.json 으로 로컬 출력
resource "local_file" "sa_key" {
  content  = base64decode(google_service_account_key.github_actions_key.private_key)
  filename = "${path.module}/sa-key.json"
}
