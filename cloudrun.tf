# ──────────────────────────────────────────
# cloudrun.tf
# Defines both the preview and tagging
# Cloud Run services for Server-Side GTM
# ──────────────────────────────────────────

# ── PREVIEW SERVER ─────────────────────────
# Handles GTM debug/preview sessions
# Created first because tagging server needs its URL
resource "google_cloud_run_v2_service" "sgtm_preview" {
  name     = "sgtm-preview-server"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    scaling {
      min_instance_count = 0 # Scales to zero when idle — saves cost
      max_instance_count = 1 # Only 1 instance needed for preview
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

      env {
        name  = "CONTAINER_CONFIG"
        value = var.container_config
      }

      # Tells the container to run in preview mode
      env {
        name  = "RUN_AS_PREVIEW_SERVER"
        value = "true"
      }
    }

    timeout = "300s"
  }
}

# Make preview server publicly accessible
resource "google_cloud_run_v2_service_iam_member" "preview_public" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.sgtm_preview.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# ── TAGGING SERVER ─────────────────────────
# Handles all production tag firing traffic
# Depends on preview server being created first
resource "google_cloud_run_v2_service" "sgtm_tagging" {
  name     = "sgtm-tagging-server"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  depends_on = [google_cloud_run_v2_service.sgtm_preview]

  template {
    scaling {
      min_instance_count = 0
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

      env {
        name  = "CONTAINER_CONFIG"
        value = var.container_config
      }

      # .uri already contains https:// — never add it manually
      env {
        name  = "PREVIEW_SERVER_URL"
        value = google_cloud_run_v2_service.sgtm_preview.uri
      }
    }

    timeout = "300s"
  }
}

# Make tagging server publicly accessible
resource "google_cloud_run_v2_service_iam_member" "tagging_public" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.sgtm_tagging.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
