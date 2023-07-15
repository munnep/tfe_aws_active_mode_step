output "ssh_tf_client" {
  value = "ssh ubuntu@${var.dns_hostname}-client.${var.dns_zonename}"
}

output "tfe_dashboard" {
  value = var.tfe_active_active ? "no dashboard in active active" : "https://${var.dns_hostname}.${var.dns_zonename}:8800"
}

output "tfe_netdata_performance_dashboard" {
  value = "http://${var.dns_hostname}.${var.dns_zonename}:19999"
}

output "tfe_appplication" {
  value = "https://${var.dns_hostname}.${var.dns_zonename}"
}

data "aws_instances" "foo" {
  instance_tags = {
    "Name" = "${var.tag_prefix}-tfe-asg"
  }
  instance_state_names = ["running"]
}

output "ssh_tfe_server" {
  value = [
    for k in data.aws_instances.foo.private_ips : "ssh -J ubuntu@${var.dns_hostname}-client.${var.dns_zonename} ubuntu@${k}"
  ]
}
