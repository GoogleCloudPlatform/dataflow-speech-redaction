terraform {
    backend "gcs" {
    bucket = "[REPLACE]"
    prefix = "terraform/state"
    }
}