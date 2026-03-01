# ──────────────────────────────────────────
# main.tf
# Entry point for Terraform — defines the
# Google Cloud provider and project settings
# ──────────────────────────────────────────

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0" # Use Google provider version 5.x
    }
  }
}

provider "google" {
  project     = var.project_id
  region      = var.region
  credentials = "key.json" # Service account key — download from GCP → IAM → Service Accounts
}
