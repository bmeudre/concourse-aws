# Specify the provider and access details
provider "aws" {
  region = "${var.aws_region}"
}

# Create an IAM role for Concourse workers, allow S3 access - https://github.com/concourse/s3-resource
resource "aws_iam_role" "worker_iam_role" {
  name = "worker_iam_role"
  path = "/"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {"AWS": "*"},
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "worker_iam_instance_profile" {
  name = "worker_iam_instance_profile"
  role = "${aws_iam_role.worker_iam_role.name}"
}

resource "aws_iam_policy_attachment" "iam-ecr-policy-attach" {
  name = "ecr-policy-attachment"
  roles = ["${aws_iam_role.worker_iam_role.name}"]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

resource "aws_iam_policy_attachment" "iam-s3-policy-attach" {
  name = "ecr-policy-attachment"
  roles = ["${aws_iam_role.worker_iam_role.name}"]
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

module "autoscaling_hooks" {
  source = "./autoscaling/hooks/enabled"
  target_asg_name = "${aws_autoscaling_group.worker-asg.name}"
  prefix = "${var.prefix}concourse-"
}

module "autoscaling_schedule" {
  source = "./autoscaling/schedule/enabled"
  target_asg_name = "${aws_autoscaling_group.worker-asg.name}"
  num_workers_during_working_time = "${var.worker_asg_desired}"
  max_num_workers_during_working_time = "${var.asg_max}"
  num_workers_during_non_working_time = 1
  max_num_workers_during_non_working_time = "${var.asg_max}"
}

module "autoscaling_utilization" {
  source = "./autoscaling/utilization/enabled"
  target_asg_name = "${aws_autoscaling_group.worker-asg.name}"
}

resource "aws_elb" "web-elb" {
  name = "${var.prefix}concourse"
  security_groups = ["${aws_security_group.external_lb.id}"]
  subnets = ["${split(",", var.subnet_id)}"]
  cross_zone_load_balancing = "true"

  listener {
    instance_port = "${var.elb_listener_instance_port}"
    instance_protocol = "tcp"
    lb_port = "${var.elb_listener_lb_port}"
    lb_protocol = "${var.elb_listener_lb_port == 80 ? "tcp" : "ssl"}"
    ssl_certificate_id = "${var.ssl_certificate_arn}"
  }

  listener {
    instance_port = "${var.tsa_port}"
    instance_protocol = "tcp"
    lb_port = "${var.tsa_port}"
    lb_protocol = "tcp"
  }

  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    target = "TCP:${var.elb_listener_instance_port}"
    interval = 5
  }
}

resource "aws_autoscaling_group" "web-asg" {
  # See "Phasing in" an Autoscaling Group? https://groups.google.com/forum/#!msg/terraform-tool/7Gdhv1OAc80/iNQ93riiLwAJ
  # * Recreation of the launch configuration triggers recreation of this ASG and its EC2 instances
  # * Modification to the lc (change to referring AMI) triggers recreation of this ASG
  name = "${var.prefix}${aws_launch_configuration.web-lc.name}-${var.ami}"
  availability_zones = ["${split(",", var.availability_zones)}"]
  max_size = "${var.asg_max}"
  min_size = "${var.asg_min}"
  desired_capacity = "${var.web_asg_desired}"
  launch_configuration = "${aws_launch_configuration.web-lc.name}"
  load_balancers = ["${aws_elb.web-elb.name}"]
  vpc_zone_identifier = ["${split(",", var.subnet_id)}"]

  tag {
    key = "Name"
    value = "${var.prefix}concourse-web"
    propagate_at_launch = "true"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "worker-asg" {
  name = "${var.prefix}${aws_launch_configuration.worker-lc.name}-${var.ami}"
  availability_zones = ["${split(",", var.availability_zones)}"]
  max_size = "${var.asg_max}"
  min_size = "${var.asg_min}"
  desired_capacity = "${var.worker_asg_desired}"
  launch_configuration = "${aws_launch_configuration.worker-lc.name}"
  vpc_zone_identifier = ["${split(",", var.subnet_id)}"]

  tag {
    key = "Name"
    value = "${var.prefix}concourse-worker"
    propagate_at_launch = "true"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_launch_configuration" "web-lc" {
  name_prefix = "${var.prefix}concourse-web-"
  image_id = "${var.ami}"
  instance_type = "${var.web_instance_type}"
  spot_price = "${substr(var.web_instance_type, 0, 2) == "t2" ? "" : var.web_spot_price}"
  security_groups = ["${aws_security_group.concourse.id}","${aws_security_group.atc.id}","${aws_security_group.tsa.id}"]
  user_data = "${data.template_cloudinit_config.web.rendered}"
  key_name = "${var.key_name}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_launch_configuration" "worker-lc" {
  name_prefix = "${var.prefix}concourse-worker-"
  image_id = "${var.ami}"
  instance_type = "${var.worker_instance_type}"
  spot_price = "${substr(var.worker_instance_type, 0, 2) == "t2" ? "" : var.worker_spot_price}"
  security_groups = ["${aws_security_group.concourse.id}", "${aws_security_group.worker.id}"]
  user_data = "${data.template_cloudinit_config.worker.rendered}"
  key_name = "${var.key_name}"
  iam_instance_profile = "${var.worker_instance_profile != "" ? var.worker_instance_profile : aws_iam_instance_profile.worker_iam_instance_profile.id}"

  root_block_device {
    volume_type = "gp2"
    volume_size = "30"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_ssm_parameter" "db_password" {
  name  = "concourse_db_password"
  type  = "SecureString"
  value = "${var.db_password}"

  lifecycle {
    ignore_changes = ["value"]
  }
}

data "template_file" "install_concourse" {
  template = "${file("${path.module}/00_install_concourse.sh.tpl")}"
}

data "template_file" "start_concourse_web" {
  template = "${file("${path.module}/01_start_concourse_web.sh.tpl")}"

  vars {
    session_signing_key = "${file("${var.session_signing_key}")}"
    tsa_host_key = "${file("${var.tsa_host_key}")}"
    tsa_authorized_keys = "${file("${var.tsa_authorized_keys}")}"
    postgres_data_source = "postgres://${var.db_username}:${aws_ssm_parameter.db_password.value}@${aws_db_instance.concourse.endpoint}/concourse"
    external_url = "${var.elb_listener_lb_protocol}://${element(split(",","${aws_elb.web-elb.dns_name},${var.custom_external_domain_name}"), var.use_custom_external_domain_name)}${element(split(",",",:${var.elb_listener_lb_port}"), var.use_custom_elb_port)}"
    basic_auth_username = "${var.basic_auth_username}"
    basic_auth_password = "${var.basic_auth_password}"
    github_auth_client_id = "${var.github_auth_client_id}"
    github_auth_client_secret = "${var.github_auth_client_secret}"
    github_auth_organizations = "${var.github_auth_organizations}"
    github_auth_teams = "${var.github_auth_teams}"
    github_auth_users = "${var.github_auth_users}"
  }
}

data "template_file" "start_concourse_worker" {
  template = "${file("${path.module}/02_start_concourse_worker.sh.tpl")}"

  vars {
    tsa_host = "${aws_elb.web-elb.dns_name}"
    tsa_public_key = "${file("${var.tsa_public_key}")}"
    tsa_worker_private_key = "${file("${var.tsa_worker_private_key}")}"
  }
}

data "template_cloudinit_config" "web" {
  # Make both turned off until https://github.com/hashicorp/terraform/issues/4794 is fixed
  gzip          = false
  base64_encode = false

  part {
    content_type = "text/x-shellscript"
    content      = "${data.template_file.install_concourse.rendered}"
  }

  part {
    content_type = "text/x-shellscript"
    content      = "${data.template_file.start_concourse_web.rendered}"
  }
}

data "template_cloudinit_config" "worker" {
  # Make both turned off until https://github.com/hashicorp/terraform/issues/4794 is fixed
  gzip          = false
  base64_encode = false

  part {
    content_type = "text/x-shellscript"
    content      = "${data.template_file.install_concourse.rendered}"
  }

  part {
    content_type = "text/x-shellscript"
    content      = "${data.template_file.start_concourse_worker.rendered}"
  }
}

resource "aws_security_group" "concourse" {
  name_prefix = "${var.prefix}concourse"
  vpc_id = "${var.vpc_id}"

  ingress {
    from_port = 123
    to_port = 123
    protocol = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 123
    to_port = 123
    protocol = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH access from a specific CIDRS
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [ "${split(",", var.in_access_allowed_cidrs)}" ]
  }

  # outbound internet access
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "atc" {
  name_prefix = "${var.prefix}concourse-atc"
  vpc_id = "${var.vpc_id}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "allow_external_lb_to_atc_access" {
  type = "ingress"
  from_port = "${var.elb_listener_instance_port}"
  to_port = "${var.elb_listener_instance_port}"
  protocol = "tcp"

  security_group_id = "${aws_security_group.tsa.id}"
  source_security_group_id = "${aws_security_group.external_lb.id}"
}

resource "aws_security_group_rule" "allow_atc_to_worker_access" {
  type = "ingress"
  from_port = "0"
  to_port = "65535"
  protocol = "tcp"

  security_group_id = "${aws_security_group.worker.id}"
  source_security_group_id = "${aws_security_group.atc.id}"
}

resource "aws_security_group" "tsa" {
  name_prefix = "${var.prefix}concourse-tsa"
  vpc_id = "${var.vpc_id}"

  # outbound internet access
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "allow_worker_to_tsa_access" {
  type = "ingress"
  from_port = 2222
  to_port = 2222
  protocol = "tcp"

  security_group_id = "${aws_security_group.tsa.id}"
  source_security_group_id = "${aws_security_group.worker.id}"
}

resource "aws_security_group_rule" "allow_external_lb_to_tsa_access" {
  type = "ingress"
  from_port = 2222
  to_port = 2222
  protocol = "tcp"

  security_group_id = "${aws_security_group.tsa.id}"
  source_security_group_id = "${aws_security_group.external_lb.id}"
}

resource "aws_security_group" "worker" {
  name_prefix = "${var.prefix}concourse-worker"
  vpc_id = "${var.vpc_id}"

  # outbound internet access
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "external_lb" {
  name_prefix = "${var.prefix}concourse-lb"

  vpc_id = "${var.vpc_id}"

  # HTTP access from a specific CIDRS
  ingress {
    from_port = "${var.elb_listener_lb_port}"
    to_port = "${var.elb_listener_lb_port}"
    protocol = "tcp"
    cidr_blocks = [ "${split(",", var.in_access_allowed_cidrs)}" ]
  }

  ingress {
    from_port = "${var.tsa_port}"
    to_port = "${var.tsa_port}"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "concourse_db" {
  name_prefix = "${var.prefix}concourse-db"
  vpc_id = "${var.vpc_id}"

  # outbound internet access
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "allow_db_access_from_atc" {
  type = "ingress"
  from_port = 5432
  to_port = 5432
  protocol = "tcp"

  security_group_id = "${aws_security_group.concourse_db.id}"
  source_security_group_id = "${aws_security_group.atc.id}"
}

resource "aws_db_instance" "concourse" {
  depends_on = ["aws_security_group.concourse_db"]
  identifier = "${var.prefix}concourse-master"
  allocated_storage = "5"
  engine = "postgres"
  engine_version = "9.6.3"
  instance_class = "${var.db_instance_class}"
  storage_type = "gp2"
  name = "concourse"
  username = "${var.db_username}"
  password = "${aws_ssm_parameter.db_password.value}"
  vpc_security_group_ids = ["${aws_security_group.concourse_db.id}"]
  db_subnet_group_name = "${aws_db_subnet_group.concourse.id}"
  storage_encrypted = true
  backup_retention_period = 3
  backup_window = "09:45-10:15"
  maintenance_window = "sun:04:30-sun:05:30"
}

resource "aws_db_subnet_group" "concourse" {
  name = "${var.prefix}concourse-db"
  subnet_ids = ["${split(",", var.db_subnet_ids)}"]
}
