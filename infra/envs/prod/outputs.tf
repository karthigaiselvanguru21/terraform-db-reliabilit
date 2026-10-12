output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.ecs.alb_dns_name
}

output "rds_endpoint" {
  description = "Endpoint address of the RDS PostgreSQL database"
  value       = module.rds.endpoint
}

output "rds_port" {
  description = "Port of the RDS PostgreSQL database"
  value       = module.rds.port
}
