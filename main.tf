provider "google" {
  project     = "ga4-mcp-472215"    # Get your GCP Project-ID
  region      = "us-central1"        # Select your region
  credentials = "key.json" # Service account key file — download from GCP → IAM → Service Accounts
}

# ──────────────────────────────────────────
# PREVIEW SERVER
# Must be created before the tagging server
# because the tagging server references its URL
# ──────────────────────────────────────────
resource "google_cloud_run_v2_service" "sgtm_preview" {
  name                = "sgtm-preview-server"
  location            = "us-central1"
  deletion_protection = false        # Allows terraform destroy to delete this service
  ingress             = "INGRESS_TRAFFIC_ALL" # Accept traffic from the internet

  template {
    scaling {
      min_instance_count = 0 # Scale to zero when idle — saves cost
      max_instance_count = 1 # Preview server only needs 1 instance
    }

    containers {
      # Official Google Server-Side GTM container image
      image = "gcr.io/cloud-tagging-10302018/gtm-cloud-image:stable"

      ports {
        container_port = 8080 # GTM container always listens on 8080
      }

      resources {
        limits = {
          cpu    = "1"      # 1 vCPU is sufficient for preview server
          memory = "512Mi"  # 512MB is the recommended minimum
        }
      }

      # Your GTM server container config string
      # Get this from GTM → Admin → Container Settings → Copy config snippet
      env {
        name  = "CONTAINER_CONFIG"
        value = var.container_config
      }

      # This flag tells the container to run in preview mode
      # instead of tagging/production mode
      env {
        name  = "RUN_AS_PREVIEW_SERVER"
        value = "true"
      }
    }

    timeout = "300s" # Max request timeout — 5 minutes
  }
}

# Allow unauthenticated requests to the preview server
# Required so GTM can reach it from the browser during debugging
resource "google_cloud_run_v2_service_iam_member" "preview_public" {
  project  = "ga4-mcp-472215"
  location = "us-central1"
  name     = google_cloud_run_v2_service.sgtm_preview.name
  role     = "roles/run.invoker"
  member   = "allUsers" # Makes the service publicly accessible
}

# ──────────────────────────────────────────
# TAGGING SERVER
# Handles all production tag firing traffic
# Created after preview server via depends_on
# ──────────────────────────────────────────
resource "google_cloud_run_v2_service" "sgtm_tagging" {
  name                = "sgtm-tagging-server"
  location            = "us-central1"
  deletion_protection = false
  ingress             = "INGRESS_TRAFFIC_ALL"

  # Ensures preview server exists before tagging server is created
  # so its URI can be passed as an environment variable below
  depends_on = [google_cloud_run_v2_service.sgtm_preview]

  template {
    scaling {
      min_instance_count = 0 # Scale to zero when idle
      max_instance_count = 2 # Scale up to 2 instances under load
    }

    containers {
      image = "gcr.io/cloud-tagging-10302018/gtm-cloud-image:stable"

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }

      # Your GTM server container config string (same value as preview server)
      env {
        name  = "CONTAINER_CONFIG"
        value = var.container_config
      }

      # Points tagging server to the preview server for GTM debug/preview mode
      # .uri already includes https:// — do NOT add it manually or it will break
      env {
        name  = "PREVIEW_SERVER_URL"
        value = google_cloud_run_v2_service.sgtm_preview.uri
      }
    }

    timeout = "300s"
  }
}

# Allow unauthenticated requests to the tagging server
# Required so your website can send events to it
resource "google_cloud_run_v2_service_iam_member" "tagging_public" {
  project  = "ga4-mcp-472215"
  location = "us-central1"
  name     = google_cloud_run_v2_service.sgtm_tagging.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# ──────────────────────────────────────────
# VARIABLES
# ──────────────────────────────────────────

# Marked sensitive so the value is never printed in terraform output or logs
variable "container_config" {
  description = "GTM Server container config string — find in GTM → Admin → Container Settings"
  type        = string
  sensitive   = true
}

# ──────────────────────────────────────────
# OUTPUTS
# Paste these URLs into GTM → Admin → Container Settings after apply
# ──────────────────────────────────────────
output "tagging_server_url" {
  description = "Paste into GTM → Admin → Container Settings → Server container URL"
  value       = google_cloud_run_v2_service.sgtm_tagging.uri
}

output "preview_server_url" {
  description = "Paste into GTM → Admin → Container Settings → Preview server URL"
  value       = google_cloud_run_v2_service.sgtm_preview.uri
}

