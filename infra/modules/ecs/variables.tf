variable "name" {
  description = "Base naming prefix for all ECS and ALB resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where ECS and ALB resources will be created"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for Application Load Balancer placement"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for ECS Fargate task placement"
  type        = list(string)
}

variable "alb_ingress_cidrs" {
  description = "List of CIDR blocks permitted to reach the ALB HTTP listener"
  type        = list(string)
}

variable "task_cpu" {
  description = "Fargate CPU units (e.g., 256 for 0.25 vCPU, 512 for 0.5 vCPU)"
  type        = number
}

variable "task_memory" {
  description = "Fargate memory in MiB (e.g., 512, 1024)"
  type        = number
}

variable "desired_count" {
  description = "Desired number of running ECS task instances"
  type        = number
}

variable "container_image" {
  description = "Container image URI/tag for the ECS task placeholder"
  type        = string
}

variable "aws_region" {
  description = "AWS region for CloudWatch logs configuration"
  type        = string
}
