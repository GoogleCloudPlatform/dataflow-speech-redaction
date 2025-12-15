terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0" # Ensure you aren't locked to an ancient version
    }
  }
}