provider "google" {
  project = var.project_id
  region  = var.region
  user_project_override = true
  billing_project       = var.project_id
}

locals {
  # List of APIs to enable
  apis = [
    "cloudbuild.googleapis.com",
    "compute.googleapis.com",
    "dataflow.googleapis.com",
    "run.googleapis.com",
    "speech.googleapis.com",
    "dlp.googleapis.com",
    "cloudfunctions.googleapis.com",
    "eventarc.googleapis.com",
    "iam.googleapis.com",
    "pubsub.googleapis.com",
    "storage.googleapis.com",
  ]
}

# Enable the required APIs
resource "google_project_service" "enabled_apis" {
  for_each                   = toset(local.apis)
  project                    = var.project_id
  service                    = each.key
  # Change this line
  disable_dependent_services = true 
  
  # Usually used in conjunction with
  disable_on_destroy = false
}

# --- IAM ---

data "google_project" "project" {}

# Get the GCE default service account
data "google_compute_default_service_account" "gce_default_sa" {
  depends_on = [google_project_service.enabled_apis]
}

# Get the GCS service agent
data "google_storage_project_service_account" "gcs_sa" {
  depends_on = [google_project_service.enabled_apis]
}

# Grant roles to the GCE default service account
resource "google_project_iam_member" "gce_sa_roles" {
  for_each = toset([
    "roles/eventarc.eventReceiver",
    "roles/speech.serviceAgent",
    "roles/dlp.user",
    "roles/dlp.admin",
    "roles/pubsub.admin",
    "roles/pubsub.subscriber",
    "roles/pubsub.viewer",
    "roles/dataflow.worker",
    "roles/run.invoker",
    "roles/cloudbuild.builds.builder",
  ])
  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${data.google_compute_default_service_account.gce_default_sa.email}"
}

# Grant roles to the GCS service agent
resource "google_project_iam_member" "gcs_sa_roles" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${data.google_storage_project_service_account.gcs_sa.email_address}"
}

# --- Storage Buckets ---

resource "google_storage_bucket" "dataflow_staging_bucket" {
  name          = var.dataflow_staging_bucket_name
  location      = var.region
  force_destroy = true
  uniform_bucket_level_access = true
}

resource "google_storage_bucket" "cloud_functions_bucket" {
  name          = var.cloud_functions_bucket_name
  location      = var.region
  force_destroy = true
  uniform_bucket_level_access = true
}

resource "google_storage_bucket" "audio_files_bucket" {
  name          = var.audio_files_bucket_name
  location      = var.region
  force_destroy = true
  uniform_bucket_level_access = true
}

resource "google_storage_bucket" "dlp_findings_bucket" {
  name          = var.dlp_findings_bucket_name
  location      = var.region
  force_destroy = true
  uniform_bucket_level_access = true
}

resource "google_storage_bucket" "redacted_audio_bucket" {
  name          = var.redacted_audio_bucket_name
  location      = var.region
  force_destroy = true
  uniform_bucket_level_access = true
}

# --- Pub/Sub ---

resource "google_pubsub_topic" "topic" {
  name = var.pubsub_topic_name
  depends_on = [google_project_service.enabled_apis]
}

# --- DLP Inspection Template ---

resource "google_data_loss_prevention_inspect_template" "dlp_template" {
  parent       = "projects/${var.project_id}/locations/global"
  template_id  = var.dlp_template_id
  display_name = "CCAI log entry inspection for PCI compliance"
  description  = "Inspection template for CCAI log entries needing PCI compliance"

  inspect_config {
    info_types { name = "CREDIT_CARD_NUMBER" }
    info_types { name = "DATE_OF_BIRTH" }
    info_types { name = "EMAIL_ADDRESS" }
    info_types { name = "FIRST_NAME" }
    info_types { name = "IP_ADDRESS" }
    info_types { name = "LAST_NAME" }
    info_types { name = "PASSPORT" }
    info_types { name = "PERSON_NAME" }
    info_types { name = "PHONE_NUMBER" }
    info_types { name = "STREET_ADDRESS" }
    info_types { name = "US_DRIVERS_LICENSE_NUMBER" }
    info_types { name = "US_HEALTHCARE_NPI" }
    info_types { name = "US_PASSPORT" }
    info_types { name = "US_SOCIAL_SECURITY_NUMBER" }
    info_types { name = "US_VEHICLE_IDENTIFICATION_NUMBER" }
    info_types { name = "US_EMPLOYER_IDENTIFICATION_NUMBER" }

    min_likelihood = "POSSIBLE"
  }

  depends_on = [google_project_service.enabled_apis]
}

# --- Cloud Functions ---

# Zip the source code for the audio processing function
data "archive_file" "audio_process_func_zip" {
  type        = "zip"
  source_dir  = "srf-audio-process-func"
  output_path = "/tmp/srf-audio-process-func.zip"
}

# Upload the zip file to the functions bucket
resource "google_storage_bucket_object" "audio_process_func_object" {
  name   = "source/srf-audio-process-func.zip"
  bucket = google_storage_bucket.cloud_functions_bucket.name
  source = data.archive_file.audio_process_func_zip.output_path
}

# Deploy the audio processing function
resource "google_cloudfunctions2_function" "audio_process_func" {
  name     = "srf-audio-process-func"
  location = "us-central1"

  build_config {
    runtime     = "nodejs20"
    entry_point = "srfAudioProcessFunc"
    source {
      storage_source {
        bucket = google_storage_bucket.cloud_functions_bucket.name
        object = google_storage_bucket_object.audio_process_func_object.name
      }
    }
  }

  service_config {
    max_instance_count = 1
    environment_variables = {
      TOPIC_NAME = google_pubsub_topic.topic.name
    }
  }

  event_trigger {
    trigger_region = "us-central1"
    event_type     = "google.cloud.storage.object.v1.finalized"
    retry_policy   = "RETRY_POLICY_RETRY"
    service_account_email = data.google_compute_default_service_account.gce_default_sa.email
    event_filters {
      attribute = "bucket"
      value     = google_storage_bucket.audio_files_bucket.name
    }
  }

  depends_on = [google_project_service.enabled_apis]
}

# Zip the source code for the redaction function
data "archive_file" "redaction_func_zip" {
  type        = "zip"
  source_dir  = "srf-redaction-func"
  output_path = "/tmp/srf-redaction-func.zip"
}

# Upload the zip file to the functions bucket
resource "google_storage_bucket_object" "redaction_func_object" {
  name   = "source/srf-redaction-func.zip"
  bucket = google_storage_bucket.cloud_functions_bucket.name
  source = data.archive_file.redaction_func_zip.output_path
}

# Deploy the redaction function
resource "google_cloudfunctions2_function" "redaction_func" {
  name     = "srf-redaction-func"
  location = "us-central1"

  build_config {
    runtime     = "nodejs20"
    entry_point = "srfRedactionFunc"
    source {
      storage_source {
        bucket = google_storage_bucket.cloud_functions_bucket.name
        object = google_storage_bucket_object.redaction_func_object.name
      }
    }
  }

  service_config {
    max_instance_count = 1
    environment_variables = {
      REDACTED_AUDIO_BUCKET_NAME = google_storage_bucket.redacted_audio_bucket.name
    }
  }

  event_trigger {
    trigger_region = "us-central1"
    event_type     = "google.cloud.storage.object.v1.finalized"
    retry_policy   = "RETRY_POLICY_RETRY"
    service_account_email = data.google_compute_default_service_account.gce_default_sa.email
    event_filters {
      attribute = "bucket"
      value     = google_storage_bucket.dlp_findings_bucket.name
    }
  }

  depends_on = [google_project_service.enabled_apis]
}
