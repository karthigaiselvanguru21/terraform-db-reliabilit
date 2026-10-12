variable "aws_region" {
  description = "AWS deployment region"
  type        = string
}

variable "environment" {
  description = "Deployment environment name (dev or prod)"
  type        = string
}

variable "name" {
  description = "Resource prefix identifier"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

variable "availability_zones" {
  description = "Availability zones to spread subnets across"
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "Flag to deploy one NAT Gateway (dev cost-effective) or one per AZ (prod resilient)"
  type        = bool
}

variable "alb_ingress_cidrs" {
  description = "Allowed ingress CIDRs for ALB HTTP traffic"
  type        = list(string)
}

variable "task_cpu" {
  description = "Fargate CPU units for the task definition"
  type        = number
}

variable "task_memory" {
  description = "Fargate memory (MiB) for the task definition"
  type        = number
}

variable "desired_count" {
  description = "Desired number of running ECS tasks"
  type        = number
}

variable "container_image" {
  description = "Container image for the web task placeholder"
  type        = string
}

variable "db_instance_class" {
  description = "RDS instance size/type"
  type        = string
}

variable "db_allocated_storage" {
  description = "RDS storage allocation in GiB"
  type        = number
}

variable "backup_retention_period" {
  description = "RDS automated backup retention period in days"
  type        = number
}

variable "deletion_protection" {
  description = "Whether deletion protection is enabled on RDS"
  type        = bool
}

variable "db_multi_az" {
  description = "Whether Multi-AZ replication is enabled on RDS"
  type        = bool
}

variable "db_name" {
  description = "Initial RDS database name"
  type        = string
}

variable "db_username" {
  description = "RDS master username"
  type        = string
}

variable "db_password" {
  description = "RDS master password"
  type        = string
  sensitive   = true
}

variable "plan_only" {
  description = "Use placeholder AWS credentials for plan-only validation; never apply with this enabled."
  type        = bool
  default     = true
}
