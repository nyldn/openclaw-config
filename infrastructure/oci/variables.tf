# --- OCI Authentication ---

variable "tenancy_ocid" {
  description = "OCID of the OCI tenancy"
  type        = string
}

variable "user_ocid" {
  description = "OCID of the OCI user for API access"
  type        = string
}

variable "fingerprint" {
  description = "Fingerprint of the OCI API signing key"
  type        = string
}

variable "private_key_path" {
  description = "Path to the OCI API private key PEM file"
  type        = string
}

variable "compartment_id" {
  description = "OCID of the compartment to create resources in"
  type        = string
}

variable "region" {
  description = "OCI region"
  type        = string
  default     = "us-ashburn-1"
}

# --- Instance Configuration ---

variable "availability_domain" {
  description = "Availability domain name. If empty, the first AD in the tenancy is used."
  type        = string
  default     = ""
}

variable "instance_shape" {
  description = "Compute instance shape"
  type        = string
  default     = "VM.Standard.A1.Flex"
}

variable "ocpus" {
  description = "Number of OCPUs for the flex instance"
  type        = number
  default     = 4
}

variable "memory_in_gbs" {
  description = "Amount of memory in GBs for the flex instance"
  type        = number
  default     = 24
}

variable "boot_volume_size_gb" {
  description = "Size of the boot volume in GBs"
  type        = number
  default     = 50
}

variable "debian_image_ocid" {
  description = "OCID of the Debian 12 custom image (must be imported manually)"
  type        = string
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key for instance access"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

# --- OpenClaw Bootstrap ---

variable "deploy_user" {
  description = "Username for the deploy user created by cloud-init"
  type        = string
  default     = "openclaw"
}

variable "bootstrap_modules" {
  description = "Comma-separated list of modules to install. Empty string installs all modules."
  type        = string
  default     = ""
}
