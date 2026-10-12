variable "name" {
  description = "Base naming prefix for RDS resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the RDS security group will reside"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the RDS subnet group"
  type        = list(string)
}

variable "ecs_security_group_id" {
  description = "Security group ID of the ECS tasks allowed to connect to RDS"
  type        = string
}

variable "instance_class" {
  description = "RDS instance compute class (e.g., db.t4g.micro, db.t4g.small)"
  type        = string
}

variable "allocated_storage" {
  description = "Allocated storage in GiB"
  type        = number
}

variable "backup_retention_period" {
  description = "Days of automated backups to retain (e.g., 3 for dev, 14 for prod)"
  type        = number
}

variable "deletion_protection" {
  description = "Enable deletion protection on the database instance"
  type        = bool
}

variable "db_name" {
  description = "Name of the initial PostgreSQL database to create"
  type        = string
}

variable "db_username" {
  description = "Master username for PostgreSQL administrator"
  type        = string
}

variable "db_password" {
  description = "Master password for PostgreSQL administrator"
  type        = string
  sensitive   = true
}

variable "multi_az" {
  description = "Enable Multi-AZ deployment for high availability"
  type        = bool
}
