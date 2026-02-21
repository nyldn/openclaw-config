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

By default, all 17 modules are installed. To install only specific modules, set `bootstrap_modules` in your tfvars:

```hcl
bootstrap_modules = "system-deps,python,nodejs,claude-cli"
```

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
