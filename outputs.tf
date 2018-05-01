output "concourse_web_endpoint" {
  value = "${var.elb_listener_lb_protocol}://${element(split(",","${aws_elb.web-elb.dns_name},${var.custom_external_domain_name}"), var.use_custom_external_domain_name)}${element(split(",",",:${var.elb_listener_lb_port}"), var.use_custom_elb_port)}"
}

output "concourse_web_elb_dns_name" {
  value = "${aws_elb.web-elb.dns_name}"
}
