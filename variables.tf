# ──────────────────────────────────────────
# variables.tf
# All input variables defined in one place
# Pass values via: terraform apply -var="key=value"
# Or create a terraform.tfvars file
# ──────────────────────────────────────────

variable "project_id" {
  description = "Your GCP project ID"
  type        = string
  default     = "ga4-mcp-472215"
}

variable "region" {
  description = "GCP region to deploy resources"
  type        = string
  default     = "us-central1"
}

variable "container_config" {
  description = "GTM Server container config string — find in GTM → Admin → Container Settings"
  type        = string
  sensitive   = true # Never printed in logs or terminal output
}

variable "tagging_domain" {
  description = "Custom domain for the tagging server e.g. gtm.yourdomain.com"
  type        = string
  # Example: default = "gtm.yourdomain.com"
}
