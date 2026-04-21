module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name = "alb-demo-vpc"
  cidr = var.vpc_cidr

  azs  = var.azs
  public_subnets  =  var.subnet_cidr
  enable_nat_gateway = false

}


module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"

  name = "app"

  instance_type = var.instance_type
  key_name      = aws_key_pair.alb_key.key_name
  subnet_id     = module.vpc.public_subnets[0]
  vpc_security_group_ids = [module.ec2_sg.security_group_id]
  associate_public_ip_address = true
  tags = {
  }
}

resource "aws_key_pair" "alb_key" {
  key_name   = "ssh-ec2-key"
  public_key = file("${path.module}/my-aws-key.pub")
}

module "alb" {
  source = "terraform-aws-modules/alb/aws"

  name = "demo-alb"
  vpc_id = module.vpc.vpc_id
  subnets = module.vpc.public_subnets
  security_groups = [module.alb_sg.security_group_id]
  enable_deletion_protection = false

listeners = {
    # Listener 1: Entry point for Nginx
    http-80 = {
      port     = 80
      protocol = "HTTP"
      forward = {
        target_group_key = "nginx-tg"
      }
    }

    # Listener 2: Entry point for Python
    http-3000 = {
      port     = 3000
      protocol = "HTTP"
      forward = {
        target_group_key = "python-tg"
      }
    }
  }

  target_groups = {
    nginx-tg = {
      backend_protocol = "HTTP"
      backend_port     = 80
      target_id        = module.ec2_instance.id
    }
    python-tg = {
      backend_protocol = "HTTP"
      backend_port     = 3000
      target_id        = module.ec2_instance.id
    }
  }
}

module "alb_sg" {
  source  = "terraform-aws-modules/security-group/aws"


  name        = "alb-sg"
  description = "Security group for ALB"
  vpc_id      = module.vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "HTTP from internet"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 3000
      to_port     = 3000
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
    }
  ]

  egress_rules = ["all-all"]
}
module "ec2_sg" {
  source  = "terraform-aws-modules/security-group/aws"

  name="ec2-sg"
  description = "sg for ec2"

  vpc_id = module.vpc.vpc_id

  ingress_with_source_security_group_id = [{
    from_port                = 80
    to_port                  = 80
    protocol                 = "tcp"
    description              = "HTTP from ALB only"
    source_security_group_id = module.alb_sg.security_group_id
}
,{
      from_port                = 3000
      to_port                  = 3000
      protocol                 = "tcp"
      description              = "Python from ALB"
      source_security_group_id = module.alb_sg.security_group_id
    }
]
ingress_with_cidr_blocks= [ {
  from_port = 22
  to_port = 22
  protocol = "tcp"
  cidr_blocks="0.0.0.0/0"
} ]

  egress_rules = ["all-all"]
  
}


