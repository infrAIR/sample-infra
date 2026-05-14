resource "aws_db_subnet_group" "main" {
  name       = "${var.environment}-db-subnet-group"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}

resource "aws_db_instance" "primary" {
  identifier        = "${var.environment}-postgres-primary"
  engine            = "postgres"
  engine_version    = "15.4"
  instance_class    = "db.t3.medium"
  allocated_storage = 100

  db_name  = "appdb"
  username = "appuser"
  password = "CHANGE_ME"

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.data.id]

  backup_retention_period = 7
  skip_final_snapshot     = true
  multi_az                = true
}

resource "aws_db_instance" "replica" {
  identifier          = "${var.environment}-postgres-replica"
  replicate_source_db = aws_db_instance.primary.identifier
  instance_class      = "db.t3.medium"
  skip_final_snapshot = true

  vpc_security_group_ids = [aws_security_group.data.id]
}

resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.environment}-cache-subnet-group"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}

resource "aws_elasticache_cluster" "cache" {
  cluster_id           = "${var.environment}-redis"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.main.name
  security_group_ids   = [aws_security_group.data.id]
}

resource "aws_s3_bucket" "assets" {
  bucket = "${var.environment}-app-assets-${var.aws_region}"
}

resource "aws_s3_bucket_versioning" "assets" {
  bucket = aws_s3_bucket.assets.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_sqs_queue" "events" {
  name                      = "${var.environment}-events"
  message_retention_seconds = 86400
  visibility_timeout_seconds = 30
}

resource "aws_sqs_queue" "events_dlq" {
  name = "${var.environment}-events-dlq"
}
