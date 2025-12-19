terraform {
    backend "gcs" {
    bucket = "mw-redaction-dev-tf" # <-- CHANGE THIS
    prefix = "terraform/state"
    }
}