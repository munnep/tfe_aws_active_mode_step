resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "${var.tag_prefix}-vpc"
  }
}

resource "aws_subnet" "public1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 1)
  availability_zone = local.az1
  tags = {
    Name = "${var.tag_prefix}-public1"
  }
}

resource "aws_subnet" "public2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 2)
  availability_zone = local.az2

  tags = {
    Name = "${var.tag_prefix}-public2"
  }
}

resource "aws_subnet" "private1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 11)
  availability_zone = local.az1
  tags = {
    Name = "${var.tag_prefix}-private1"
  }
}

resource "aws_subnet" "private2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 12)
  availability_zone = local.az2
  tags = {
    Name = "${var.tag_prefix}-private2"
  }
}


resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.tag_prefix}-gw"
  }
}


resource "aws_route_table" "publicroutetable" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "${var.tag_prefix}-route-table-gw"
  }
}


resource "aws_eip" "nateIP" {
  vpc = true
}



resource "aws_nat_gateway" "NAT" {
  allocation_id = aws_eip.nateIP.id
  subnet_id     = aws_subnet.public1.id

  tags = {
    Name = "${var.tag_prefix}-nat"
  }
}




resource "aws_route_table" "privateroutetable" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.NAT.id
  }

  tags = {
    Name = "${var.tag_prefix}-route-table-nat"
  }

}



resource "aws_route_table_association" "PublicRT1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.publicroutetable.id
}

resource "aws_route_table_association" "PublicRT2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.publicroutetable.id
}

resource "aws_route_table_association" "PrivateRT1" {
  subnet_id      = aws_subnet.private1.id
  route_table_id = aws_route_table.privateroutetable.id
}

resource "aws_route_table_association" "PrivateRT2" {
  subnet_id      = aws_subnet.private2.id
  route_table_id = aws_route_table.privateroutetable.id
}

resource "aws_security_group" "tfe_server_sg" {
  vpc_id      = aws_vpc.main.id
  name        = "tfe_server_sg"
  description = "tfe_server_sg"

  ingress {
    description = "https tfe dashboard from internet"
    from_port   = 8800
    to_port     = 8800
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "https from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "https from internet"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "netdata from internet"
    from_port   = 19999
    to_port     = 19999
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  ingress {
    description = "https from internet"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "vault internal active-active"
    from_port   = 8201
    to_port     = 8201
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }



  ingress {
    description = "redis "
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "icmp from internet"
    from_port   = 0
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${var.tag_prefix}-tfe_server_sg"
  }
}


resource "aws_s3_bucket" "tfe-bucket" {
  bucket        = "${var.tag_prefix}-bucket"
  force_destroy = true

  tags = {
    Name = "${var.tag_prefix}-bucket"
  }
}

resource "aws_s3_bucket" "tfe-bucket-software" {
  bucket        = "${var.tag_prefix}-software"
  force_destroy = true

  tags = {
    Name = "${var.tag_prefix}-software"
  }
}


resource "aws_s3_object" "object_airgap" {
  bucket = "${var.tag_prefix}-software"
  key    = var.filename_airgap
  source = "files/${var.filename_airgap}"

  depends_on = [
    aws_s3_bucket.tfe-bucket-software
  ]
}

resource "aws_s3_object" "object_license" {
  bucket = "${var.tag_prefix}-software"
  key    = var.filename_license
  source = "files/${var.filename_license}"

  depends_on = [
    aws_s3_bucket.tfe-bucket-software
  ]

}

resource "aws_s3_object" "object_bootstrap" {
  bucket = "${var.tag_prefix}-software"
  key    = var.filename_bootstrap
  source = "files/${var.filename_bootstrap}"

  depends_on = [
    aws_s3_bucket.tfe-bucket-software
  ]
}

resource "aws_s3_bucket_acl" "tfe-bucket" {
  bucket = aws_s3_bucket.tfe-bucket.id
  acl    = "private"
}

resource "aws_iam_role" "role" {
  name = "${var.tag_prefix}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_instance_profile" "profile" {
  name = "${var.tag_prefix}-instance"
  role = aws_iam_role.role.name
}

resource "aws_iam_role_policy" "policy" {
  name = "${var.tag_prefix}-bucket"
  role = aws_iam_role.role.id

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "VisualEditor0",
        "Effect" : "Allow",
        "Action" : [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject",
          "s3:GetBucketLocation"
        ],
        "Resource" : [
          "arn:aws:s3:::${var.tag_prefix}-bucket",
          "arn:aws:s3:::${var.tag_prefix}-software",
          "arn:aws:s3:::*/*"
        ]
      },
      {
        "Sid" : "VisualEditor1",
        "Effect" : "Allow",
        "Action" : "s3:ListAllMyBuckets",
        "Resource" : "*"
      }
    ]
  })
}


# code idea from https://itnext.io/lets-encrypt-certs-with-terraform-f870def3ce6d
data "aws_route53_zone" "base_domain" {
  name = var.dns_zonename
}

resource "tls_private_key" "private_key" {
  algorithm = "RSA"
}

resource "acme_registration" "registration" {
  account_key_pem = tls_private_key.private_key.private_key_pem
  email_address   = var.certificate_email
}

resource "acme_certificate" "certificate" {
  account_key_pem = acme_registration.registration.account_key_pem
  common_name     = "${var.dns_hostname}.${var.dns_zonename}"

  dns_challenge {
    provider = "route53"

    config = {
      AWS_HOSTED_ZONE_ID = data.aws_route53_zone.base_domain.zone_id
    }
  }

  depends_on = [acme_registration.registration]
}



resource "aws_acm_certificate" "cert" {
  certificate_body  = acme_certificate.certificate.certificate_pem
  private_key       = acme_certificate.certificate.private_key_pem
  certificate_chain = acme_certificate.certificate.issuer_pem
}


resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.base_domain.zone_id
  name    = var.dns_hostname
  type    = "CNAME"
  ttl     = "300"
  records = [aws_lb.lb_application.dns_name]
}

# loadbalancer Target Group
resource "aws_lb_target_group" "lb_target_group1" {
  name     = "${var.tag_prefix}-target-group1"
  port     = 8800
  protocol = "HTTPS"
  vpc_id   = aws_vpc.main.id
}

# loadbalancer Target Group
resource "aws_lb_target_group" "lb_target_group2" {
  name     = "${var.tag_prefix}-target-group2"
  port     = 443
  protocol = "HTTPS"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    protocol            = "HTTPS"
    timeout             = 20
    unhealthy_threshold = 2
    path                = "/_health_check"
  }
}

# loadbalancer Target Group
resource "aws_lb_target_group" "lb_target_group3" {
  name     = "${var.tag_prefix}-target-group3"
  port     = 19999
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}


# application load balancer
resource "aws_lb" "lb_application" {
  name               = "${var.tag_prefix}-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.tfe_server_sg.id]
  subnets            = [aws_subnet.public1.id, aws_subnet.public2.id]

  tags = {
    Environment = "${var.tag_prefix}-lb"
  }
}

resource "aws_lb_listener" "front_end1" {
  load_balancer_arn = aws_lb.lb_application.arn
  port              = "8800"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.cert.arn


  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb_target_group1.arn
  }
}

resource "aws_lb_listener" "front_end2" {
  load_balancer_arn = aws_lb.lb_application.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.cert.arn


  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb_target_group2.arn
  }
}

resource "aws_lb_listener" "front_end3" {
  load_balancer_arn = aws_lb.lb_application.arn
  port              = "19999"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb_target_group3.arn
  }
}

resource "aws_key_pair" "default-key" {
  key_name   = "${var.tag_prefix}-key"
  public_key = var.public_key
}


resource "aws_db_subnet_group" "default" {
  name       = "main"
  subnet_ids = [aws_subnet.private1.id, aws_subnet.private2.id]

  tags = {
    Name = "My DB subnet group"
  }
}

resource "aws_db_instance" "default" {
  allocated_storage      = 10
  engine                 = "postgres"
  engine_version         = "12"
  instance_class         = "db.t3.large"
  username               = "postgres"
  password               = var.rds_password
  parameter_group_name   = "default.postgres12"
  skip_final_snapshot    = true
  db_name                = "tfe"
  publicly_accessible    = false
  vpc_security_group_ids = [aws_security_group.tfe_server_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.default.name
  identifier             = "${var.tag_prefix}-rds"
  tags = {
    "Name" = var.tag_prefix
  }

  depends_on = [
    aws_s3_object.object_bootstrap
  ]
}

resource "aws_launch_configuration" "as_conf_tfe_single" {
  name_prefix          = "${var.tag_prefix}-lc"
  image_id             = var.ami
  instance_type        = "t3.2xlarge"
  security_groups      = [aws_security_group.tfe_server_sg.id]
  iam_instance_profile = aws_iam_instance_profile.profile.name
  key_name             = "${var.tag_prefix}-key"

  root_block_device {
    volume_size = 50
    volume_type = "io1"
    iops        = 1000
  }

  ebs_block_device {
    device_name = "/dev/sdh"
    volume_size = 32
    volume_type = "io1"
    iops        = 1000
  }

  ebs_block_device {
    device_name = "/dev/sdi"
    volume_size = 100
    volume_type = "io1"
    iops        = 2000
  }


  user_data = templatefile("${path.module}/scripts/user-data-single.sh", {
    tag_prefix         = var.tag_prefix
    certificate_email  = var.certificate_email
    filename_airgap    = var.filename_airgap
    filename_license   = var.filename_license
    filename_bootstrap = var.filename_bootstrap
    dns_hostname       = var.dns_hostname
    tfe_password       = var.tfe_password
    dns_zonename       = var.dns_zonename
    pg_dbname          = aws_db_instance.default.db_name
    pg_address         = aws_db_instance.default.address
    rds_password       = var.rds_password
    tfe_bucket         = "${var.tag_prefix}-bucket"
    region             = var.region
  })


  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_elasticache_subnet_group" "test" {
  name       = "test-patrick"
  subnet_ids = [aws_subnet.private1.id]
}

resource "aws_elasticache_cluster" "example" {
  cluster_id           = "patrick-example"
  engine               = "redis"
  node_type            = "cache.t3.small"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis5.0"
  engine_version       = "5.0.6"
  port                 = 6379
  security_group_ids   = [aws_security_group.tfe_server_sg.id]
  subnet_group_name    = aws_elasticache_subnet_group.test.name
}

resource "aws_launch_configuration" "as_conf_tfe_active" {
  name_prefix          = "${var.tag_prefix}-lc2"
  image_id             = var.ami
  instance_type        = "t3.2xlarge"
  security_groups      = [aws_security_group.tfe_server_sg.id]
  iam_instance_profile = aws_iam_instance_profile.profile.name
  key_name             = "${var.tag_prefix}-key"

  root_block_device {
    volume_size = 50
    volume_type = "io1"
    iops        = 1000
  }

  ebs_block_device {
    device_name = "/dev/sdh"
    volume_size = 32
    volume_type = "io1"
    iops        = 1000
  }

  ebs_block_device {
    device_name = "/dev/sdi"
    volume_size = 100
    volume_type = "io1"
    iops        = 2000
  }


  user_data = templatefile("${path.module}/scripts/user-data-active-active.sh", {
    tag_prefix         = var.tag_prefix
    filename_airgap    = var.filename_airgap
    filename_license   = var.filename_license
    filename_bootstrap = var.filename_bootstrap
    dns_hostname       = var.dns_hostname
    tfe_password       = var.tfe_password
    dns_zonename       = var.dns_zonename
    pg_dbname          = aws_db_instance.default.db_name
    pg_address         = aws_db_instance.default.address
    rds_password       = var.rds_password
    tfe_bucket         = "${var.tag_prefix}-bucket"
    region             = var.region
    redis_server       = lookup(aws_elasticache_cluster.example.cache_nodes[0], "address", "No redis created")
  })


  lifecycle {
    create_before_destroy = true
  }
}

# Automatic Scaling group
resource "aws_autoscaling_group" "as_group" {
  name                      = "${var.tag_prefix}-asg"
  max_size                  = var.asg_max_size
  min_size                  = var.asg_min_size
  health_check_grace_period = 3600
  health_check_type         = "ELB"
  desired_capacity          = var.asg_desired_capacity
  force_delete              = true
  launch_configuration      = local.tfe_setup
  vpc_zone_identifier       = [aws_subnet.private1.id]
  target_group_arns         = [aws_lb_target_group.lb_target_group1.id, aws_lb_target_group.lb_target_group2.id, aws_lb_target_group.lb_target_group3.id]


  tag {
    key                 = "Name"
    value               = "${var.tag_prefix}-tfe-asg"
    propagate_at_launch = true
  }

  timeouts {
    delete = "15m"
  }

  depends_on = [
    aws_nat_gateway.NAT, aws_security_group.tfe_server_sg, aws_internet_gateway.gw, aws_db_instance.default
  ]

}