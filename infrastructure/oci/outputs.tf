output "instance_public_ip" {
  description = "Public IP address of the OpenClaw instance"
  value       = oci_core_instance.openclaw.public_ip
}

output "instance_ocid" {
  description = "OCID of the OpenClaw instance"
  value       = oci_core_instance.openclaw.id
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh ${var.deploy_user}@${oci_core_instance.openclaw.public_ip}"
}

output "vcn_ocid" {
  description = "OCID of the Virtual Cloud Network"
  value       = oci_core_vcn.openclaw.id
}

output "subnet_ocid" {
  description = "OCID of the subnet"
  value       = oci_core_subnet.openclaw.id
}

output "notification_topic_ocid" {
  description = "OCID of the monitoring notification topic (if enabled)"
  value       = var.enable_monitoring ? oci_ons_notification_topic.openclaw[0].id : null
}

output "boot_volume_backup_policy_ocid" {
  description = "OCID of the boot volume backup policy (if enabled)"
  value       = var.enable_boot_volume_backup ? oci_core_volume_backup_policy.openclaw[0].id : null
}
