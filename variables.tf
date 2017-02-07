terraform {
  required_version = "> 0.8.3"
}

variable "prefix" {
  description = "Prefix for every resource created by this template"
  default = "concourse-"  
}

variable "aws_region" {
  description = "The AWS region to create things in."
  default = "us-west-2"
}

variable "ami" {
}

variable "availability_zones" {
  default = "us-west-2a,us-west-2b,us-west-2c"
  description = "List of availability zones, use AWS CLI to find yours"
}

variable "key_name" {
  description = "Name of AWS key pair"
}

variable "instance_type" {
  default = "r4.large"
  description = "AWS instance type"
}

variable "spot_price" {
  default = "0.15"
  description = "The price to use for reserving spot instances."
}

variable "asg_min" {
  description = "Min numbers of servers in ASG"
  default = "0"
}

variable "asg_max" {
  description = "Max numbers of servers in ASG"
  default = "10"
}

variable "web_asg_desired" {
  description = "Desired numbers of web servers in ASG"
  # Setting this gte 2 result in `fly execute --input foo=bar` to fail with errors like: "bad response uploading bits (404 Not Found)" or "gunzip: invalid magic"
  default = "1"
}

variable "worker_asg_desired" {
  description = "Desired numbers of servers in ASG"
  default = "2"
}

variable "elb_listener_lb_port" {
  description = ""
  default = "80"
}

variable "use_custom_elb_port" {
  default = 0
}

variable "elb_listener_lb_protocol" {
  default = "http"
}

variable "elb_listener_instance_port" {
  description = ""
  default = "8080"
}

variable "in_access_allowed_cidrs" {
  description = ""
}

variable "subnet_id" {
  description = ""
}

variable "db_subnet_ids" {
  description = ""
}

variable "vpc_id" {
  description = ""
}

variable "db_username" {
  description = ""
}

variable "db_password" {
  description = ""
}

variable "db_instance_class" {
  description = "AWS RDS instance type"
  default = "db.t2.small"
}

variable "tsa_host_key" {
  description = ""
}

variable "session_signing_key" {
  description = ""
}

variable "tsa_authorized_keys" {
  description = ""
}

variable "tsa_public_key" {
  description = ""
}

variable "tsa_worker_private_key" {
  description = ""
}

variable "tsa_port" {
  description = ""
  default = "2222"
}

variable "worker_instance_profile" {
  description = "IAM instance profile name to be used by Concourse workers. Can be an empty string to not specify it (no instance profile is used then)"
}

variable "basic_auth_username" {
  default = ""
}

variable "basic_auth_password" {
  default = ""
}

variable "github_auth_client_id" {
  default = ""
}

variable "github_auth_client_secret" {
  default = ""
}

variable "github_auth_organizations" {
  default = ""
}

variable "github_auth_teams" {
  default = ""
}

variable "github_auth_users" {
  default = ""
}

variable "custom_external_domain_name" {
  default = ""
  description ="don't include http[s]://"
}

variable "use_custom_external_domain_name" {
  default = 0
}

variable "ssl_certificate_arn" {
  default = ""
}
