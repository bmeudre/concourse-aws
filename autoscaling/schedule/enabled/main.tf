resource "aws_autoscaling_schedule" "add_workers_before_working_time" {
    scheduled_action_name = "add_workers_before_working_time"
    min_size = "${var.num_workers_during_working_time}"
    max_size = "${var.max_num_workers_during_working_time}"
    desired_capacity = "${var.num_workers_during_working_time}"
    # 7:30 UTC
    recurrence = "30 7 * * MON-FRI"
    autoscaling_group_name = "${var.target_asg_name}"
}

resource "aws_autoscaling_schedule" "rem_workers_after_working_time" {
    scheduled_action_name = "rem_workers_after_working_time"
    min_size = "${var.num_workers_during_non_working_time}"
    max_size = "${var.max_num_workers_during_non_working_time}"
    desired_capacity = "${var.num_workers_during_non_working_time}"
    # 21:30 UTC
    recurrence = "30 21 * * MON-FRI"
    autoscaling_group_name = "${var.target_asg_name}"
}

variable "target_asg_name" {}

variable "num_workers_during_working_time" {}
variable "max_num_workers_during_working_time" {}

variable "max_num_workers_during_non_working_time" {}
variable "num_workers_during_non_working_time" {}