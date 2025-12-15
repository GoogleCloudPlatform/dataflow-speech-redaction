output "dataflow_staging_bucket" {
  description = "The name of the Dataflow staging bucket."
  value       = google_storage_bucket.dataflow_staging_bucket.name
}

output "cloud_functions_bucket" {
  description = "The name of the Cloud Functions source bucket."
  value       = google_storage_bucket.cloud_functions_bucket.name
}

output "audio_files_bucket" {
  description = "The name of the bucket for uploaded audio files."
  value       = google_storage_bucket.audio_files_bucket.name
}

output "dlp_findings_bucket" {
  description = "The name of the bucket for DLP findings."
  value       = google_storage_bucket.dlp_findings_bucket.name
}

output "redacted_audio_bucket" {
  description = "The name of the bucket for redacted audio files."
  value       = google_storage_bucket.redacted_audio_bucket.name
}

output "pubsub_topic" {
  description = "The name of the Pub/Sub topic."
  value       = google_pubsub_topic.topic.name
}

output "dlp_inspect_template_name" {
  description = "The full name of the DLP inspect template."
  value       = google_data_loss_prevention_inspect_template.dlp_template.name
}
