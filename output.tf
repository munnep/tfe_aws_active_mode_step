output "ssh_tf_client" {
  value = "ssh ubuntu@${var.dns_hostname}-client.${var.dns_zonename}"
}

output "tfe_dashboard" {
  value = "https://${var.dns_hostname}.${var.dns_zonename}:8800"
}

output "tfe_netdata_performance_dashboard" {
  value = "http://${var.dns_hostname}.${var.dns_zonename}:19999"
}

output "tfe_appplication" {
  value = "https://${var.dns_hostname}.${var.dns_zonename}"
}

output "ssh_tfe_server" {
  value = "ssh -J ubuntu@${var.dns_hostname}-client.${var.dns_zonename} ubuntu@<internal ip address of the TFE server>"
}

