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
    source_id               = var.debian_image_ocid
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
