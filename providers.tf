# Root Configuration for the Google Provider

provider "google" {
  # You should define any global settings here, like project, region, etc.,
  project                     = var.project_id
  region                      = var.region
  #impersonate_service_account = "[REPLACE]"
}