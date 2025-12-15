terraform {
    backend "gcs" {
    bucket = "yt-redaction-tfstate" # <-- CHANGE THIS
    prefix = "terraform/state"
    }
}