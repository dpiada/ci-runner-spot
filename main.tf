####################################################################
#                          Configurations                          #
####################################################################
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.46.0"
    }
  }

  backend "s3" {
    bucket  = "gitlab-ci-runner-spot-tfstate"
    key     = "tfstate"
    region  = "eu-west-1"
  }
}

provider "aws" {

  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project       = "gitlab-ci-runner-spot"
      Creation_type = "terraform"
    }
  }
}

####################################################################
#                          Networking                              #
####################################################################

resource "aws_default_vpc" "default" {

}

data "aws_subnets" "subnets" {
  filter {
    name   = "vpc-id"
    values = [aws_default_vpc.default.id]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_security_group" "default" {
  name   = "default"
  vpc_id = aws_default_vpc.default.id
}

#####################################################################
#                       Runner Configurations                       #
#####################################################################

module "runner" {
  source  = "cattle-ops/gitlab-runner/aws"
  version = "7.5.0"

  environment = "gitlab-runner-spot-fleet"

  vpc_id    = aws_default_vpc.default.id
  subnet_id = data.aws_subnets.subnets.ids[0]

  ###### RUNNER MANAGER #########
  runner_instance = {
    name = "gitlab-runner-manager"
    private_address_only = false
    ssm_access = true
    use_eip = true
    type = "t3a.nano"
  }

  runner_gitlab = {
    url = "https://gitlab.com"
    registration_token = var.registration_token
    preregistered_runner_token_ssm_parameter_name = "runner-token"
  }

  runner_schedule_enable = true
  runner_schedule_config = {
    # Configure optional scale_out scheduled action
    scale_out_recurrence = "0 6 * * 1-5" #UTC
    scale_out_count      = 1 # Default for min_size, desired_capacity and max_size
    # Override using: scale_out_min_size, scale_out_desired_capacity, scale_out_max_size

    # Configure optional scale_in scheduled action
    scale_in_recurrence  = "0 18 * * 1-5" #UTC
    scale_in_count       = 0 # Default for min_size, desired_capacity and max_size
    # Override using: scale_out_min_size, scale_out_desired_capacity, scale_out_max_size
  }
  
  ###### RUNNER WORKER #########
  runner_worker = {
    type = "docker+machine"
  }

  runner_worker_docker_machine_fleet = {
    enable = true
  }

  runner_worker_docker_machine_instance = {
    types = ["t3a.medium"]
    subnet_ids = data.aws_subnets.subnets.ids
    private_address_only = false
  }
}