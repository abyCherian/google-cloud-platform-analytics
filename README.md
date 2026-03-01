# google-cloud-platform-analytics

> Deploy Server-Side Google Tag Manager (sGTM) on Google Cloud Run using Terraform — with a custom domain, static IP, and auto-renewing SSL certificate.

---

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [File Structure](#file-structure)
- [Variables](#variables)
- [Getting Started](#getting-started)
- [DNS Configuration](#dns-configuration)
- [GTM Configuration](#gtm-configuration)
- [Useful Commands](#useful-commands)
- [Troubleshooting](#troubleshooting)

---

## Overview

This project provisions the full infrastructure needed to run Server-Side GTM on GCP using Terraform. Instead of clicking through the GCP console, everything is defined as code and deployed in a single command.

**What gets created:**
- A **Preview Server** — used for debugging tags in GTM
- A **Tagging Server** — handles all production tag firing traffic
- A **Static IP Address** — a fixed IP to point your domain to
- A **Google-Managed SSL Certificate** — auto-provisioned and auto-renewed
- A **Global Load Balancer** — routes your custom domain to Cloud Run with HTTPS
- **HTTP → HTTPS redirect** — ensures all traffic is encrypted

---

## Architecture

```
Browser / Website
       │
       ▼
  your-domain.com (DNS A Record)
       │
       ▼
  Static IP (GCP Global)
       │
       ▼
  Global Load Balancer
  ├── HTTPS (443) → SSL Certificate → Tagging Server (Cloud Run)
  └── HTTP  (80)  → Redirect to HTTPS
       │
       ▼
  sgtm-tagging-server (Cloud Run)
       │
       ▼
  sgtm-preview-server (Cloud Run) ← used during GTM debug sessions
```

---

## Prerequisites

Before deploying, make sure you have the following:

| Requirement | Details |
|---|---|
| [Terraform](https://developer.hashicorp.com/terraform/install) | v1.3 or higher |
| [GCP Account](https://console.cloud.google.com) | With billing enabled |
| GCP Service Account Key | Download as `key.json` — see below |
| GTM Server Container | With a Container Config string ready |
| Custom Domain | e.g. `gtm.yourdomain.com` |

### Creating a Service Account Key

1. Go to **GCP Console → IAM & Admin → Service Accounts**
2. Click **Create Service Account**
3. Grant the following roles:
   - `Cloud Run Admin`
   - `Compute Admin`
   - `Service Account User`
4. Click **Keys → Add Key → JSON**
5. Save the downloaded file as `key.json` in the project root

> ⚠️ Never commit `key.json` to Git. Add it to `.gitignore`.

### Getting Your GTM Container Config String

1. Open **Google Tag Manager**
2. Select your **Server container**
3. Go to **Admin → Container Settings**
4. Copy the config string — it looks like `eyJhY2NvdW50SWQi...`

---

## File Structure

```
google-cloud-platform-analytics/
├── main.tf          # Provider and Terraform version config
├── variables.tf     # All input variables
├── cloudrun.tf      # Preview and tagging Cloud Run services
├── ip_address.tf    # Static external IP address
├── ssl.tf           # SSL certificate, Load Balancer, routing rules
├── outputs.tf       # URLs and IP printed after deployment
├── key.json         # ⚠️ GCP service account key (never commit this)
└── README.md        # This file
```

---

## Variables

| Variable | Description | Required | Default |
|---|---|---|---|
| `project_id` | GCP Project ID | **Yes** | `XX-XXX-47XX15` |
| `region` | GCP region | No | `us-central1` | Based on project requirements, you need to change
| `container_config` | GTM container config string | **Yes** | — |
| `tagging_domain` | Custom domain for tagging server | **Yes** | — |

You can pass variables in two ways:

**Option 1 — Inline:**
```bash
terraform apply \
  -var="container_config=YOUR_CONFIG_STRING" \
  -var="tagging_domain=gtm.yourdomain.com"
```

**Option 2 — `terraform.tfvars` file (recommended):**
```hcl
# terraform.tfvars
container_config = "YOUR_CONFIG_STRING"
tagging_domain   = "gtm.yourdomain.com"
```
Then just run `terraform apply`.

> ⚠️ Never commit `terraform.tfvars` to Git if it contains your config string.

---

## Getting Started

```bash
# 1. Clone the repo
git clone https://github.com/yourname/google-cloud-platform-analytics.git
cd google-cloud-platform-analytics

# 2. Add your service account key
cp /path/to/downloaded-key.json key.json

# 3. Initialise Terraform (downloads the Google provider)
terraform init

# 4. Preview what will be created
terraform plan \
  -var="container_config=YOUR_CONFIG_STRING" \
  -var="tagging_domain=gtm.yourdomain.com"

# 5. Deploy everything
terraform apply \
  -var="container_config=YOUR_CONFIG_STRING" \
  -var="tagging_domain=gtm.yourdomain.com"
```

After a successful apply, Terraform will print your outputs:

```
Outputs:

static_ip_address    = "34.x.x.x"
tagging_server_url   = "https://gtm.yourdomain.com"
tagging_cloudrun_url = "https://sgtm-tagging-server-xxx.run.app"
```

---

## DNS Configuration

After `terraform apply` completes, you need to point your domain to the static IP:

1. Copy the `static_ip_address` from the Terraform output
2. Go to your domain registrar (GoDaddy, Cloudflare, Namecheap, etc.)
3. Create a new **A record**:

| Field | Value |
|---|---|
| Type | `A` |
| Name / Host | `gtm` (or your chosen subdomain) |
| Value / Points to | The IP from Terraform output |
| TTL | `300` (5 minutes) |

4. Wait for DNS to propagate — usually 5–30 minutes
5. Google will then automatically provision your SSL certificate — this can take **10–60 minutes**

---

## GTM Configuration

Once your domain is live and SSL is active:

1. Open **Google Tag Manager**
2. Go to **Admin → Container Settings**
3. Update the following fields:

| Field | Value |
|---|---|
| **Server container URL** | `https://gtm.yourdomain.com` |

4. Click **Save** and **Publish** your container

---

## Useful Commands

```bash
# See what Terraform will create/change without applying
terraform plan

# Apply changes
terraform apply

# View current outputs (after apply)
terraform output

# Destroy all resources (careful — deletes everything)
terraform destroy

# Check Cloud Run logs for tagging server
gcloud logging read \
  'resource.type="cloud_run_revision" AND resource.labels.service_name="sgtm-tagging-server"' \
  --project=ga4-mcp-472215 \
  --limit=20 \
  --order=desc

# Check Cloud Run logs for preview server
gcloud logging read \
  'resource.type="cloud_run_revision" AND resource.labels.service_name="sgtm-preview-server"' \
  --project=ga4-mcp-472215 \
  --limit=20 \
  --order=desc
```

---

## Troubleshooting

**Container failed to start on port 8080**
- Verify your `CONTAINER_CONFIG` string is valid by running: `echo "YOUR_STRING" | base64 -d`
- It should decode to a JSON object with `accountId`, `containerId` etc.
- Check logs using the gcloud command above

**SSL certificate stuck in PROVISIONING**
- DNS has not propagated yet — wait 10–60 minutes
- Verify your A record is correct: `nslookup gtm.yourdomain.com`
- The IP returned must match your `static_ip_address` output

**Preview mode not working**
- Make sure both URLs are saved in GTM container settings and the container is republished
- Confirm the preview server Cloud Run service is healthy in the GCP console

**`deletion_protection` unsupported error**
- Your Google provider version is below 5.x — run `terraform init -upgrade`

---

## .gitignore

Add this to your `.gitignore` to avoid committing secrets:

```
key.json
terraform.tfvars
.terraform/
.terraform.lock.hcl
terraform.tfstate
terraform.tfstate.backup
```
