# OpenClaw OCI Deployment

Terraform configuration to deploy openclaw-config on an Oracle Cloud Infrastructure (OCI) Debian 12 ARM instance using cloud-init.

**Target instance:** VM.Standard.A1.Flex (4 OCPUs / 24 GB RAM — free tier eligible)

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.3
- An OCI account with an API signing key configured
- An SSH key pair (default: `~/.ssh/id_ed25519`)

## Step 1: Import the Debian 12 Image

OCI does not provide Debian as a platform image. You need to import a Debian 12 cloud image as a custom image.

1. Download the Debian 12 `genericcloud-arm64` image from https://cloud.debian.org/images/cloud/bookworm/latest/ (QCOW2 format).
2. In the OCI Console, go to **Compute > Custom Images > Import Image**.
3. Choose **Import from Object Storage** or upload directly.
4. Settings:
   - **Operating system:** Linux
   - **Image type:** QCOW2
   - **Launch mode:** Paravirtualized
   - **Shape compatibility:** Select `VM.Standard.A1.Flex`
5. Copy the resulting image OCID for use in `terraform.tfvars`.

## Step 2: Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and fill in the required values. At minimum you need:

- `tenancy_ocid`, `user_ocid`, `fingerprint`, `private_key_path` — from your OCI API key
- `compartment_id` — the compartment to deploy into
- `debian_image_ocid` — the custom image OCID from Step 1

## Step 3: Deploy

```bash
terraform init
terraform plan
terraform apply
```

Terraform will output the public IP and an SSH command when complete.

## Step 4: Post-Deploy Setup

Cloud-init runs the bootstrap automatically. Wait a few minutes for it to finish, then SSH in:

```bash
ssh openclaw@<public-ip>
```

Once connected:

1. Check bootstrap progress: `tail -f /var/log/openclaw-bootstrap.log`
2. Configure API keys for Claude, OpenAI, Gemini, etc.
3. Run the setup wizard: `cd ~/openclaw-config/bootstrap && ./bootstrap.sh --interactive`

## Selecting Modules

By default, all modules are installed. To install only specific modules, set `bootstrap_modules` in your tfvars:

```hcl
bootstrap_modules = "system-deps,python,nodejs,claude-cli"
```

## Optional Features

| Feature | Variable | Default | Description |
|---|---|---|---|
| Monitoring | `enable_monitoring` | `false` | CPU/memory alarms via OCI Monitoring |
| Email alerts | `notification_email` | `""` | Email for alarm notifications |
| Boot backup | `enable_boot_volume_backup` | `false` | Automatic boot volume backups |
| Backup schedule | `backup_frequency` | `WEEKLY` | `DAILY` or `WEEKLY` |

### Monitoring

Set `enable_monitoring = true` and `notification_email` to receive alerts when:
- CPU utilization exceeds 90% for 5 minutes
- Memory utilization exceeds 85% for 5 minutes

```hcl
enable_monitoring  = true
notification_email = "you@example.com"
```

### Backup

Set `enable_boot_volume_backup = true` to create automatic incremental backups of the boot volume with 7-day retention.

```hcl
enable_boot_volume_backup = true
backup_frequency          = "DAILY"
```

## DNS Configuration

The instance gets a public IP but no DNS name by default. Options for DNS:

### Option A: Tailscale (recommended)
The bootstrap installs Tailscale (module 17). After `tailscale up`, your instance is reachable at `openclaw-server.<tailnet>.ts.net`. Use `tailscale serve` to expose the gateway with HTTPS.

### Option B: Reverse Proxy
Use Caddy or nginx on the instance with a domain you control. Point your domain's A record to the public IP.

### Option C: OCI Load Balancer
Create an OCI Load Balancer with an SSL certificate for a production-grade setup. This adds cost beyond the free tier.

## Multi-Region Deployment

For deploying across multiple OCI regions (e.g., for redundancy or latency):

### Workspace Approach

Use separate Terraform workspaces per region:

```bash
terraform workspace new eu-frankfurt
terraform apply -var="region=eu-frankfurt-1"

terraform workspace new ap-tokyo
terraform apply -var="region=ap-tokyo-1"
```

### Available Regions

| Region | Identifier | Free Tier |
|---|---|---|
| US East (Ashburn) | `us-ashburn-1` | Yes (home region) |
| US West (Phoenix) | `us-phoenix-1` | Yes |
| EU (Frankfurt) | `eu-frankfurt-1` | Yes |
| AP (Tokyo) | `ap-tokyo-1` | Yes |
| UK (London) | `uk-london-1` | Yes |

Note: Free tier ARM instances are limited to your home region. Multi-region requires a paid account.

## Teardown

```bash
terraform destroy
```

This removes all OCI resources created by this configuration. Data on the boot volume is permanently deleted.

## Resources Created

| Resource | Description |
|---|---|
| VCN | Virtual Cloud Network (10.0.0.0/16) |
| Subnet | Public subnet (10.0.1.0/24) |
| Internet Gateway | Outbound internet access |
| Route Table | Default route via internet gateway |
| Security List | Ingress: SSH (22), OpenClaw (18789); Egress: all |
| Compute Instance | ARM Flex instance with cloud-init bootstrap |
| Notification Topic | Monitoring alerts (if `enable_monitoring`) |
| Email Subscription | Alert delivery (if `notification_email` set) |
| CPU Alarm | High CPU alert >90% (if `enable_monitoring`) |
| Memory Alarm | High memory alert >85% (if `enable_monitoring`) |
| Backup Policy | Boot volume backup schedule (if `enable_boot_volume_backup`) |
