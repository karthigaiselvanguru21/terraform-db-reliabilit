aws_region              = "ap-south-1"
environment             = "prod"
name                    = "assessment-prod"
vpc_cidr                = "10.20.0.0/16"
public_subnet_cidrs     = ["10.20.1.0/24", "10.20.2.0/24"]
private_subnet_cidrs    = ["10.20.11.0/24", "10.20.12.0/24"]
availability_zones      = ["ap-south-1a", "ap-south-1b"]
single_nat_gateway      = false
alb_ingress_cidrs       = ["0.0.0.0/0"]
task_cpu                = 512
task_memory             = 1024
desired_count           = 2
container_image         = "nginx:stable-alpine"
db_instance_class       = "db.t4g.small"
db_allocated_storage    = 50
backup_retention_period = 14
deletion_protection     = true
db_multi_az             = true
db_name                 = "appdb"
db_username             = "appadmin"
db_password             = "AssessmentOnly-ChangeMe123!"

# Plan-only assessment mode; set false only when using real AWS credentials.
plan_only = true
