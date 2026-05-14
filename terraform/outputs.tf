output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

output "api_service_name" {
  value = aws_ecs_service.api.name
}

output "db_endpoint" {
  value     = aws_db_instance.primary.endpoint
  sensitive = true
}
