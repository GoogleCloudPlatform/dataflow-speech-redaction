variable "project_id" {
  description = "The GCP project ID."
  type        = string
}

variable "region" {
  description = "The GCP region to deploy resources in."
  type        = string
  default     = "us-central1"
}

variable "buckets_region" {
  description = "The GCP region or multiregion to deploy buckets."
  type        = string
  default     = "us-central1"
}

variable "dataflow_staging_bucket_name" {
  description = "The name of the Cloud Storage bucket for Dataflow staging."
  type        = string
}

variable "cloud_functions_bucket_name" {
  description = "The name of the Cloud Storage bucket for Cloud Functions deployment."
  type        = string
}

variable "audio_files_bucket_name" {
  description = "The name of the Cloud Storage bucket for uploaded audio files."
  type        = string
}

variable "dlp_findings_bucket_name" {
  description = "The name of the Cloud Storage bucket for DLP findings."
  type        = string
}

variable "redacted_audio_bucket_name" {
  description = "The name of the Cloud Storage bucket for redacted audio files."
  type        = string
}

variable "pubsub_topic_name" {
  description = "The name of the Pub/Sub topic."
  type        = string
}

variable "dlp_template_id" {
  description = "The ID of the DLP inspection template."
  type        = string
}

variable "dataflow_subnet_name" {
  description = "The name of the subnet for Dataflow instance"
  type        = string
}