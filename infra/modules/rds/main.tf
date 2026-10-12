resource "aws_security_group" "this" {
  name        = "${var.name}-rds-sg"
  description = "PostgreSQL ingress only from ECS tasks"
  vpc_id      = var.vpc_id
  ingress {
    description     = "PostgreSQL from ECS task security group"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.ecs_security_group_id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.name}-rds-sg" }
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-db-subnets"
  subnet_ids = var.private_subnet_ids
  tags       = { Name = "${var.name}-db-subnets" }
}

resource "aws_db_instance" "this" {
  identifier                      = "${var.name}-postgres"
  engine                          = "postgres"
  engine_version                  = "16.4"
  instance_class                  = var.instance_class
  allocated_storage               = var.allocated_storage
  max_allocated_storage           = max(var.allocated_storage * 2, 100)
  storage_type                    = "gp3"
  storage_encrypted               = true
  db_name                         = var.db_name
  username                        = var.db_username
  password                        = var.db_password
  port                            = 5432
  db_subnet_group_name            = aws_db_subnet_group.this.name
  vpc_security_group_ids          = [aws_security_group.this.id]
  publicly_accessible             = false
  backup_retention_period         = var.backup_retention_period
  deletion_protection             = var.deletion_protection
  multi_az                        = var.multi_az
  auto_minor_version_upgrade      = true
  apply_immediately               = false
  skip_final_snapshot             = !var.deletion_protection
  final_snapshot_identifier       = var.deletion_protection ? "${var.name}-final-snapshot" : null
  copy_tags_to_snapshot           = true
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  tags                            = { Name = "${var.name}-postgres" }
}
