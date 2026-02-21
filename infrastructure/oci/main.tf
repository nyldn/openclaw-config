# --- Availability Domain Lookup ---

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

locals {
  availability_domain = (
    var.availability_domain != ""
    ? var.availability_domain
    : data.oci_identity_availability_domains.ads.availability_domains[0].name
  )

  image_ocid = (
    var.os_image == "ubuntu"
    ? data.oci_core_images.ubuntu.images[0].id
    : var.debian_image_ocid
  )
}

# --- Ubuntu 24.04 Minimal ARM Image Lookup ---

data "oci_core_images" "ubuntu" {
  compartment_id           = var.compartment_id
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04 Minimal aarch64"
  shape                    = var.instance_shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# --- Networking ---

resource "oci_core_vcn" "openclaw" {
  compartment_id = var.compartment_id
  display_name   = "openclaw-vcn"
  cidr_blocks    = ["10.0.0.0/16"]
  dns_label      = "oclawvcn"
}

resource "oci_core_internet_gateway" "openclaw" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.openclaw.id
  display_name   = "openclaw-igw"
  enabled        = true
}

resource "oci_core_route_table" "openclaw" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.openclaw.id
  display_name   = "openclaw-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.openclaw.id
  }
}

resource "oci_core_security_list" "openclaw" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.openclaw.id
  display_name   = "openclaw-sl"

  # Allow all egress
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
    stateless   = false
  }

  # SSH
  ingress_security_rules {
    source   = "0.0.0.0/0"
    protocol = "6" # TCP
    tcp_options {
      min = 22
      max = 22
    }
    stateless = false
  }

  # OpenClaw gateway
  ingress_security_rules {
    source   = "0.0.0.0/0"
    protocol = "6" # TCP
    tcp_options {
      min = 18789
      max = 18789
    }
    stateless = false
  }
}

resource "oci_core_subnet" "openclaw" {
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.openclaw.id
  display_name               = "openclaw-subnet"
  cidr_block                 = "10.0.1.0/24"
  dns_label                  = "oclawsub"
  route_table_id             = oci_core_route_table.openclaw.id
  security_list_ids          = [oci_core_security_list.openclaw.id]
  prohibit_public_ip_on_vnic = false
}

# --- Compute Instance ---

resource "oci_core_instance" "openclaw" {
  compartment_id      = var.compartment_id
  availability_domain = local.availability_domain
  display_name        = "openclaw-server"
  shape               = var.instance_shape

  shape_config {
    ocpus         = var.ocpus
    memory_in_gbs = var.memory_in_gbs
  }

  source_details {
    source_type             = "image"
    source_id               = local.image_ocid
    boot_volume_size_in_gbs = var.boot_volume_size_gb
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.openclaw.id
    assign_public_ip = true
    display_name     = "openclaw-vnic"
  }

  metadata = {
    ssh_authorized_keys = file(pathexpand(var.ssh_public_key_path))
    user_data = base64encode(templatefile("${path.module}/cloud-init.yaml.tftpl", {
      deploy_user       = var.deploy_user
      ssh_public_key    = file(pathexpand(var.ssh_public_key_path))
      bootstrap_modules = var.bootstrap_modules
    }))
  }
}

# --- Monitoring (conditional) ---

resource "oci_ons_notification_topic" "openclaw" {
  count          = var.enable_monitoring ? 1 : 0
  compartment_id = var.compartment_id
  name           = "openclaw-alerts"
  description    = "OpenClaw monitoring alerts"
}

resource "oci_ons_subscription" "email" {
  count          = var.enable_monitoring && var.notification_email != "" ? 1 : 0
  compartment_id = var.compartment_id
  topic_id       = oci_ons_notification_topic.openclaw[0].id
  protocol       = "EMAIL"
  endpoint       = var.notification_email
}

resource "oci_monitoring_alarm" "cpu_high" {
  count               = var.enable_monitoring ? 1 : 0
  compartment_id      = var.compartment_id
  display_name        = "openclaw-cpu-high"
  is_enabled          = true
  metric_compartment_id = var.compartment_id
  namespace           = "oci_computeagent"
  query               = "CpuUtilization[5m]{resourceId = \"${oci_core_instance.openclaw.id}\"}.mean() > 90"
  severity            = "CRITICAL"
  body                = "CPU utilization on openclaw-server exceeded 90% for 5 minutes."
  pending_duration    = "PT5M"

  destinations = [oci_ons_notification_topic.openclaw[0].id]
}

resource "oci_monitoring_alarm" "memory_high" {
  count               = var.enable_monitoring ? 1 : 0
  compartment_id      = var.compartment_id
  display_name        = "openclaw-memory-high"
  is_enabled          = true
  metric_compartment_id = var.compartment_id
  namespace           = "oci_computeagent"
  query               = "MemoryUtilization[5m]{resourceId = \"${oci_core_instance.openclaw.id}\"}.mean() > 85"
  severity            = "WARNING"
  body                = "Memory utilization on openclaw-server exceeded 85% for 5 minutes."
  pending_duration    = "PT5M"

  destinations = [oci_ons_notification_topic.openclaw[0].id]
}

# --- Boot Volume Backup (conditional) ---

resource "oci_core_volume_backup_policy" "openclaw" {
  count          = var.enable_boot_volume_backup ? 1 : 0
  compartment_id = var.compartment_id
  display_name   = "openclaw-backup-policy"

  schedules {
    backup_type       = "INCREMENTAL"
    period            = var.backup_frequency == "DAILY" ? "ONE_DAY" : "ONE_WEEK"
    retention_seconds = 604800 # 7 days
    time_zone         = "UTC"
  }
}

resource "oci_core_volume_backup_policy_assignment" "openclaw" {
  count     = var.enable_boot_volume_backup ? 1 : 0
  asset_id  = oci_core_instance.openclaw.boot_volume_id
  policy_id = oci_core_volume_backup_policy.openclaw[0].id
}
