output "namespace_name" {
  description = "Kubernetes namespace name"
  value       = kubernetes_namespace.microservice.metadata[0].name
}

output "service_account_name" {
  description = "Kubernetes service account name"
  value       = kubernetes_service_account.microservice.metadata[0].name
}

output "iam_role_arn" {
  description = "IAM role ARN for the microservice"
  value       = aws_iam_role.microservice_role.arn
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.microservice.dns_name
}

output "alb_zone_id" {
  description = "ALB zone ID"
  value       = aws_lb.microservice.zone_id
}

output "target_group_arn" {
  description = "ALB target group ARN"
  value       = aws_lb_target_group.microservice.arn
}

output "database_endpoint" {
  description = "Database endpoint"
  value = var.enable_rds ? (
    var.use_aurora ? 
    try(aws_rds_cluster.microservice[0].endpoint, null) : 
    try(aws_db_instance.microservice[0].endpoint, null)
  ) : null
}

output "database_port" {
  description = "Database port"
  value = var.enable_rds ? (
    var.use_aurora ? 
    try(aws_rds_cluster.microservice[0].port, null) : 
    try(aws_db_instance.microservice[0].port, null)
  ) : null
}

output "cache_endpoint" {
  description = "ElastiCache Redis endpoint"
  value       = var.enable_cache ? aws_elasticache_replication_group.microservice[0].primary_endpoint_address : null
}

output "cache_port" {
  description = "ElastiCache Redis port"
  value       = var.enable_cache ? aws_elasticache_replication_group.microservice[0].port : null
}

output "sqs_queue_url" {
  description = "SQS queue URL"
  value       = var.enable_sqs ? aws_sqs_queue.microservice[0].url : null
}

output "sqs_queue_arn" {
  description = "SQS queue ARN"
  value       = var.enable_sqs ? aws_sqs_queue.microservice[0].arn : null
}

output "sqs_dlq_url" {
  description = "SQS dead letter queue URL"
  value       = var.enable_sqs ? aws_sqs_queue.microservice_dlq[0].url : null
}

output "security_group_ids" {
  description = "Security group IDs"
  value = {
    alb          = aws_security_group.alb.id
    microservice = aws_security_group.microservice.id
    rds          = var.enable_rds ? aws_security_group.rds[0].id : null
    cache        = var.enable_cache ? aws_security_group.elasticache[0].id : null
  }
}