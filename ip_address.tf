# ──────────────────────────────────────────
# ip_address.tf
# Creates a static external IP address
# You will point your domain's DNS A record
# to this IP after running terraform apply
# ──────────────────────────────────────────

resource "google_compute_global_address" "sgtm_ip" {
  name         = "sgtm-static-ip"   # Name shown in GCP console
  address_type = "EXTERNAL"         # Public-facing IP
  ip_version   = "IPV4"

  description  = "Static IP for sGTM tagging server custom domain"
}
