locals {
  az1 = "${var.region}a"
  az2 = "${var.region}b"
  tfe_setup = var.tfe_active_active ? aws_launch_configuration.as_conf_tfe_active.name : aws_launch_configuration.as_conf_tfe_single.name
}

