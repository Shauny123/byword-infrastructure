terraform {
  required_providers {
    google = { source = "hashicorp/google", version = "~> 5.0" }
  }
}

variable "project_id" {}
variable "environment" {}
resource "google_container_cluster" "primary" {
  name     = "byword-${var.environment}"
  location = "us-central1"
}
