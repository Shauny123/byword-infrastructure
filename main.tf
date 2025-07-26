provider "google" {
  project = var.project_id
  region  = var.region
}

terraform {
  backend "gcs" {
    bucket  = "byword-terraform-state"
    prefix  = "infrastructure"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }

  required_version = ">= 1.0"
}

resource "google_compute_network" "vpc_network" {
  name = "${var.environment}-vpc"
  auto_create_subnetworks = true
}

# Example: Deploying Cloud Run service infrastructure (optional block)
# module "cloud_run_service" {
#   source     = "./modules/cloud_run"
#   project_id = var.project_id
#   region     = var.region
#   service_name = "intake-api"
#   image       = "gcr.io/${var.project_id}/byword-voicelaw-ai"
# }
