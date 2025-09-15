output "microservice_outputs" {
  description = "All outputs from the microservice platform module"
  value       = module.microservice_platform
}

output "service_url" {
  description = "Service URL"
  value       = "http://${module.microservice_platform.alb_dns_name}/${var.service_name}"
}

output "database_secret_arn" {
  description = "Database password secret ARN"
  value       = aws_secretsmanager_secret.db_password.arn
}

output "database_endpoint" {
  description = "Database endpoint"
  value       = module.microservice_platform.database_endpoint
}