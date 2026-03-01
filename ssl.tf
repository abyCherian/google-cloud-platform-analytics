# ──────────────────────────────────────────
# ssl.tf
# Creates a Google-managed SSL certificate
# and maps your custom domain to the
# sGTM tagging server Cloud Run service
#
# ⚠️  IMPORTANT — DNS must be set up first:
# After running terraform apply, go to your
# domain registrar and create an A record:
#   Name: gtm (or whatever subdomain you use)
#   Value: the IP from outputs.tf
# Google will then auto-provision the cert
# This can take 10–60 minutes
# ──────────────────────────────────────────

# Google-managed SSL certificate
# Google automatically provisions and renews this — nothing to manage
resource "google_compute_managed_ssl_certificate" "sgtm_ssl" {
  name = "sgtm-ssl-cert"

  managed {
    # The domain this certificate will be issued for
    # Must match your DNS A record exactly
    domains = [var.tagging_domain]
  }
}

# NEG = Network Endpoint Group
# This is the bridge between the Load Balancer and your Cloud Run service
# Without this, GCP doesn't know how to route traffic to Cloud Run
resource "google_compute_region_network_endpoint_group" "sgtm_neg" {
  name                  = "sgtm-tagging-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region

  cloud_run {
    service = google_cloud_run_v2_service.sgtm_tagging.name
  }
}

# Backend service — sits between the load balancer and the NEG
# Think of it as the traffic director
resource "google_compute_backend_service" "sgtm_backend" {
  name                  = "sgtm-tagging-backend"
  protocol              = "HTTPS"
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group = google_compute_region_network_endpoint_group.sgtm_neg.id
  }
}

# URL map — routes incoming requests to the correct backend
# Explicitly maps your custom domain + all paths to the tagging backend
resource "google_compute_url_map" "sgtm_url_map" {
  name            = "sgtm-url-map"
  default_service = google_compute_backend_service.sgtm_backend.id

  # Single host rule — routes your domain with /* to the tagging backend
  host_rule {
    hosts        = [var.tagging_domain]
    path_matcher = "tagging-paths"
  }

  path_matcher {
    name            = "tagging-paths"
    default_service = google_compute_backend_service.sgtm_backend.id
  }
}

# HTTPS proxy — attaches the SSL certificate to the load balancer
resource "google_compute_target_https_proxy" "sgtm_https_proxy" {
  name             = "sgtm-https-proxy"
  url_map          = google_compute_url_map.sgtm_url_map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.sgtm_ssl.id]
}

# Forwarding rule — ties the static IP to the HTTPS proxy
# This is what makes traffic hitting your IP reach the sGTM server
resource "google_compute_global_forwarding_rule" "sgtm_forwarding_rule" {
  name                  = "sgtm-forwarding-rule"
  target                = google_compute_target_https_proxy.sgtm_https_proxy.id
  port_range            = "443"  # HTTPS port
  ip_address            = google_compute_global_address.sgtm_ip.address
  load_balancing_scheme = "EXTERNAL_MANAGED"
}

# HTTP → HTTPS redirect
# Redirects anyone visiting http://gtm.yourdomain.com to https://
resource "google_compute_url_map" "sgtm_http_redirect" {
  name = "sgtm-http-redirect"

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

resource "google_compute_target_http_proxy" "sgtm_http_proxy" {
  name    = "sgtm-http-proxy"
  url_map = google_compute_url_map.sgtm_http_redirect.id
}

resource "google_compute_global_forwarding_rule" "sgtm_http_forwarding_rule" {
  name                  = "sgtm-http-forwarding-rule"
  target                = google_compute_target_http_proxy.sgtm_http_proxy.id
  port_range            = "80" # HTTP port
  ip_address            = google_compute_global_address.sgtm_ip.address
  load_balancing_scheme = "EXTERNAL_MANAGED"
}
