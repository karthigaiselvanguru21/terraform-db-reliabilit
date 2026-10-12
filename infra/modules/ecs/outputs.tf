output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.this.dns_name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.this.arn
}

output "task_security_group_id" {
  description = "Security group ID assigned to ECS tasks"
  value       = aws_security_group.task.id
}
