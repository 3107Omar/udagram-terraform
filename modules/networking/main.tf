data "aws_availability_zones" "available" {}

module "vpc" { #A
  source                           = "terraform-aws-modules/vpc/aws"
  version                          = "2.64.0"
  name                             = "terraform-vpc"
  cidr                             = "10.0.0.0/16"
  azs                              = data.aws_availability_zones.available.names
  private_subnets                  = ["10.0.1.0/24"]
  public_subnets                   = ["10.0.101.0/24","10.0.102.0/24"]
  enable_dns_support 		   = true
  enable_dns_hostnames		   = true
  single_nat_gateway = true
  enable_nat_gateway = false
}

module "lb_sg" {
  source = "terraform-in-action/sg/aws"
  vpc_id = module.vpc.vpc_id
  ingress_rules = [{
    port        = 80
    cidr_blocks = ["0.0.0.0/0"]
  }]
}

module "ecs_sg" {
  source = "terraform-in-action/sg/aws"
  vpc_id = module.vpc.vpc_id
  ingress_rules = [
    {
      port            = 8080
      security_groups = [module.lb_sg.security_group.id]
    },
  ]
}
