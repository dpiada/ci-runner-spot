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

resource "aws_security_group" "sg-runner-git" {
  name   = "runner-gitlab"
  vpc_id = aws_default_vpc.default.id

  ingress = [
    {
      description      = "HTTP"
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]  
      ipv6_cidr_blocks = []
      prefix_list_ids = []
      security_groups = []
      self = false
    },
    {
        description      = "HTTPS"
        from_port        = 443
        to_port          = 443
        protocol         = "tcp"
        cidr_blocks      = ["0.0.0.0/0"]  
        ipv6_cidr_blocks = []
        prefix_list_ids = []
        security_groups = []
        self = false      
    },
    {
      description      = "SSH"
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]  
      ipv6_cidr_blocks = []
      prefix_list_ids = []
      security_groups = []
      self = false      
    }
  ]


  egress = [
    {
      description      = "for all outgoing traffics"
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids = []
      security_groups = []
      self = false
    }
  ]
}


#####################################################################
#                       Runner Configurations                       #
#####################################################################

module "runner" {
  source  = "cattle-ops/gitlab-runner/aws"
  version = "8.1.0"

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

  runner_networking = {
    allow_incoming_ping                    = true
    security_group_ids                     = [resource.aws_security_group.sg-runner-git.id]
  }

  runner_gitlab = {
    url = "https://gitlab.com"

    preregistered_runner_token_ssm_parameter_name = "precreated-token"
  }

  runner_schedule_enable = true
  runner_schedule_config = {
    scale_out_recurrence = "0 6 * * 1-5"
    scale_out_count      = 1 

    scale_in_recurrence  = "0 18 * * 1-5" 
    scale_in_count       = 0 
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