resource "aws_ecs_cluster" "main" {
  name = "${var.environment}-cluster"
}

resource "aws_ecs_task_definition" "api" {
  family                   = "${var.environment}-api-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "api"
    image     = "123456789012.dkr.ecr.us-east-1.amazonaws.com/api:${var.app_image_tag}"
    essential = true
    portMappings = [{ containerPort = 8080 }]
    environment = [
      { name = "DB_HOST",    value = aws_db_instance.primary.address },
      { name = "REDIS_HOST", value = aws_elasticache_cluster.cache.cache_nodes[0].address },
      { name = "ENV",        value = var.environment }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"  = "/ecs/${var.environment}/api"
        "awslogs-region" = var.aws_region
      }
    }
  }])
}

resource "aws_ecs_service" "api" {
  name            = "${var.environment}-api"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_groups = [aws_security_group.app.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "api"
    container_port   = 8080
  }

  depends_on = [aws_lb_listener.https]
}

resource "aws_ecs_task_definition" "worker" {
  family                   = "${var.environment}-worker-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "worker"
    image     = "123456789012.dkr.ecr.us-east-1.amazonaws.com/worker:${var.app_image_tag}"
    essential = true
    environment = [
      { name = "DB_HOST",    value = aws_db_instance.primary.address },
      { name = "REDIS_HOST", value = aws_elasticache_cluster.cache.cache_nodes[0].address }
    ]
  }])
}

resource "aws_ecs_service" "worker" {
  name            = "${var.environment}-worker"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.worker.arn
  desired_count   = 3
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_groups = [aws_security_group.app.id]
  }
}

resource "aws_lambda_function" "event_processor" {
  function_name = "${var.environment}-event-processor"
  role          = aws_iam_role.lambda.arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  filename      = "lambda.zip"

  vpc_config {
    subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_group_ids = [aws_security_group.app.id]
  }

  environment {
    variables = {
      DB_HOST    = aws_db_instance.primary.address
      QUEUE_URL  = aws_sqs_queue.events.url
    }
  }
}

resource "aws_lambda_event_source_mapping" "sqs" {
  event_source_arn = aws_sqs_queue.events.arn
  function_name    = aws_lambda_function.event_processor.arn
  batch_size       = 10
}

# sync
