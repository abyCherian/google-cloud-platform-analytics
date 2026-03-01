# ──────────────────────────────────────────
# outputs.tf
# Printed in terminal after terraform apply
# Use these values to configure GTM and DNS
# ──────────────────────────────────────────

# ── STEP 1 — Point your DNS here ───────────
output "static_ip_address" {
  description = "➡️  Create a DNS A record pointing your domain to this IP"
  value       = google_compute_global_address.sgtm_ip.address
}

# ── STEP 2 — Paste into GTM ────────────────
output "tagging_server_url" {
  description = "➡️  GTM → Admin → Container Settings → Server container URL"
  value       = "https://${var.tagging_domain}"
}


# ── For reference ──────────────────────────
output "tagging_cloudrun_url" {
  description = "Raw Cloud Run URL for the tagging server (before custom domain)"
  value       = google_cloud_run_v2_service.sgtm_tagging.uri
}
