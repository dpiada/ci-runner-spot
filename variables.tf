variable "aws_region" {
  type        = string
  description = "The AWS region where to create the cluster."
  default     = "eu-west-1"
}

variable "aws_profile" {
  type        = string
  description = "The AWS credentials profile to use to authenticate."
  default     = "aws_profile"
}

variable "environment"{
  type        = string
  description = "The description of gilab runner environment"
  default     = "gitlab-runner-spot"
}
