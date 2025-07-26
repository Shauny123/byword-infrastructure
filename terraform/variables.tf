variable "project_id" {
  description = "The ID of the GCP project to deploy resources into"
  type        = string
}

variable "environment" {
  description = "The deployment environment (e.g., dev, staging, production)"
  type        = string
}

variable "region" {
  description = "The GCP region to deploy resources in"
  type        = string
  default     = "us-central1"
}
