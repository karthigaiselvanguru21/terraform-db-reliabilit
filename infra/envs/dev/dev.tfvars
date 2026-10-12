aws_region              = "ap-south-1"
environment             = "dev"
name                    = "assessment-dev"
vpc_cidr                = "10.10.0.0/16"
public_subnet_cidrs     = ["10.10.1.0/24", "10.10.2.0/24"]
private_subnet_cidrs    = ["10.10.11.0/24", "10.10.12.0/24"]
availability_zones      = ["ap-south-1a", "ap-south-1b"]
single_nat_gateway      = true
alb_ingress_cidrs       = ["0.0.0.0/0"]
task_cpu                = 256
task_memory             = 512
desired_count           = 1
container_image         = "nginx:stable-alpine"
db_instance_class       = "db.t4g.micro"
db_allocated_storage    = 20
backup_retention_period = 3
deletion_protection     = false
db_multi_az             = false
db_name                 = "appdb"
db_username             = "appadmin"
db_password             = "AssessmentOnly-ChangeMe123!"

# Plan-only assessment mode; set false only when using real AWS credentials.
plan_only = true
