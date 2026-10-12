terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  # Plan-only mode lets reviewers inspect the graph without AWS credentials.
  # Never run terraform apply while plan_only=true.
  access_key                  = var.plan_only ? "plan-only-placeholder" : null
  secret_key                  = var.plan_only ? "plan-only-placeholder-secret" : null
  skip_credentials_validation = var.plan_only
  skip_requesting_account_id  = var.plan_only
  skip_metadata_api_check     = var.plan_only
  default_tags {
    tags = {
      Project     = "terraform-db-reliability"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

module "network" {
  source               = "../../modules/network"
  name                 = var.name
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
  single_nat_gateway   = var.single_nat_gateway
}

module "ecs" {
  source             = "../../modules/ecs"
  name               = var.name
  aws_region         = var.aws_region
  vpc_id             = module.network.vpc_id
  public_subnet_ids  = module.network.public_subnet_ids
  private_subnet_ids = module.network.private_subnet_ids
  alb_ingress_cidrs  = var.alb_ingress_cidrs
  task_cpu           = var.task_cpu
  task_memory        = var.task_memory
  desired_count      = var.desired_count
  container_image    = var.container_image
}

module "rds" {
  source                  = "../../modules/rds"
  name                    = var.name
  vpc_id                  = module.network.vpc_id
  private_subnet_ids      = module.network.private_subnet_ids
  ecs_security_group_id   = module.ecs.task_security_group_id
  instance_class          = var.db_instance_class
  allocated_storage       = var.db_allocated_storage
  backup_retention_period = var.backup_retention_period
  deletion_protection     = var.deletion_protection
  db_name                 = var.db_name
  db_username             = var.db_username
  db_password             = var.db_password
  multi_az                = var.db_multi_az
}

