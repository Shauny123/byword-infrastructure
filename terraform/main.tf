# terraform/main.tf
terraform {
  required_version = ">= 1.5"
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }

  backend "gcs" {
    bucket = "byword-terraform-state"
    prefix = "infrastructure"
  }
}

locals {
  cluster_name = "byword-${var.environment}"
  cluster_type = var.environment == "production" ? "standard" : "autopilot"
  
  # Node pool configuration based on environment
  node_pools = var.environment == "production" ? {
    primary = {
      machine_type = "e2-standard-4"
      min_count    = 3
      max_count    = 10
      disk_size_gb = 100
      preemptible  = false
    }
    secondary = {
      machine_type = "e2-standard-2"
      min_count    = 1
      max_count    = 5
      disk_size_gb = 50
      preemptible  = true
    }
  } : {
    default = {
      machine_type = "e2-standard-2"
      min_count    = 1
      max_count    = 3
      disk_size_gb = 50
      preemptible  = var.environment == "development"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# Enable required APIs
resource "google_project_service" "apis" {
  for_each = toset([
    "container.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "dns.googleapis.com",
    "compute.googleapis.com",
    "iam.googleapis.com",
    "secretmanager.googleapis.com",
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com"
  ])
  
  service            = each.value
  disable_on_destroy = false
}

# VPC and Subnet
resource "google_compute_network" "vpc" {
  name                    = "${local.cluster_name}-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "subnet" {
  name          = "${local.cluster_name}-subnet"
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc.name
  
  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }
  
  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }
}

# GKE Cluster
resource "google_container_cluster" "primary" {
  name     = local.cluster_name
  location = var.region
  
  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name
  
  # Remove default node pool
  remove_default_node_pool = true
  initial_node_count       = 1

  # Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Network configuration
  network_policy {
    enabled = true
  }

  # IP allocation policy
  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  # Master authorized networks
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block = "0.0.0.0/0"
      display_name = "All"
    }
  }

  # Maintenance window
  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00"
    }
  }

  # Enable addons
  addons_config {
    horizontal_pod_autoscaling {
      disabled = false
    }
    http_load_balancing {
      disabled = false
    }
    dns_cache_config {
      enabled = true
    }
  }

  # Enable private cluster features
  private_cluster_config {
    enable_private_endpoint = false
    enable_private_nodes    = true
    master_ipv4_cidr_block  = var.master_cidr
  }

  depends_on = [google_project_service.apis]
}

# Node pools
resource "google_container_node_pool" "pools" {
  for_each = local.node_pools
  
  name       = each.key
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = each.value.min_count

  autoscaling {
    min_node_count = each.value.min_count
    max_node_count = each.value.max_count
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    preemptible  = each.value.preemptible
    machine_type = each.value.machine_type
    disk_size_gb = each.value.disk_size_gb
    disk_type    = "pd-standard"
    
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = {
      environment = var.environment
      node_pool   = each.key
    }

    tags = ["gke-node", "${local.cluster_name}-node"]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}

# Kubernetes provider configuration
data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${google_container_cluster.primary.endpoint}"
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth.0.cluster_ca_certificate)
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "gke-gcloud-auth-plugin"
  }
}

# Helm provider configuration
provider "helm" {
  kubernetes {
    host                   = "https://${google_container_cluster.primary.endpoint}"
    cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth.0.cluster_ca_certificate)
    
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "gke-gcloud-auth-plugin"
    }
  }
}

# Service accounts for workload identity
resource "google_service_account" "external_dns" {
  account_id   = "external-dns-${var.environment}"
  display_name = "External DNS Service Account"
}

resource "google_service_account" "cert_manager" {
  account_id   = "cert-manager-${var.environment}"
  display_name = "Cert Manager Service Account"
}

# IAM bindings
resource "google_project_iam_member" "external_dns" {
  role   = "roles/dns.admin"
  member = "serviceAccount:${google_service_account.external_dns.email}"
}

resource "google_project_iam_member" "cert_manager" {
  role   = "roles/dns.admin"
  member = "serviceAccount:${google_service_account.cert_manager.email}"
}

# Kubernetes namespaces
resource "kubernetes_namespace" "system_namespaces" {
  for_each = toset(["external-dns", "cert-manager", "monitoring", "ingress-nginx"])
  
  metadata {
    name = each.value
    labels = {
      "app.kubernetes.io/part-of" = each.value
    }
  }
}

# Create service account secrets
resource "kubernetes_service_account" "workload_identity" {
  for_each = {
    external_dns = google_service_account.external_dns.email
    cert_manager = google_service_account.cert_manager.email
  }
  
  metadata {
    name      = each.key
    namespace = each.key
    annotations = {
      "iam.gke.io/gcp-service-account" = each.value
    }
  }
}
