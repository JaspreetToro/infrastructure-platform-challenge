

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

# EKS Namespace
resource "kubernetes_namespace" "microservice" {
  metadata {
    name = var.service_name
    labels = {
      "app.kubernetes.io/name"       = var.service_name
      "app.kubernetes.io/managed-by" = "terraform"
      "environment"                  = var.environment
    }
  }
}

# Service Account with IRSA
resource "kubernetes_service_account" "microservice" {
  metadata {
    name      = "${var.service_name}-sa"
    namespace = kubernetes_namespace.microservice.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.microservice_role.arn
    }
  }
}

# RBAC
resource "kubernetes_role" "microservice" {
  metadata {
    namespace = kubernetes_namespace.microservice.metadata[0].name
    name      = "${var.service_name}-role"
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "services", "configmaps", "secrets"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }
}

resource "kubernetes_role_binding" "microservice" {
  metadata {
    name      = "${var.service_name}-binding"
    namespace = kubernetes_namespace.microservice.metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.microservice.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.microservice.metadata[0].name
    namespace = kubernetes_namespace.microservice.metadata[0].name
  }
}

# RDS Subnet Group
resource "aws_db_subnet_group" "microservice" {
  count      = var.enable_rds ? 1 : 0
  name       = "${var.service_name}-${var.environment}-db-subnet"
  subnet_ids = var.private_subnet_ids

  tags = merge(var.tags, {
    Name = "${var.service_name}-${var.environment}-db-subnet"
  })
}

# RDS Instance
resource "aws_db_instance" "microservice" {
  count = var.enable_rds && !var.use_aurora ? 1 : 0

  identifier = "${var.service_name}-${var.environment}"
  
  engine         = var.db_engine
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class
  
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  storage_encrypted     = true
  
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  
  vpc_security_group_ids = [aws_security_group.rds[0].id]
  db_subnet_group_name   = aws_db_subnet_group.microservice[0].name
  
  backup_retention_period = var.environment == "prod" ? 7 : 1
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
  
  skip_final_snapshot = var.environment != "prod"
  deletion_protection = var.environment == "prod"
  
  tags = merge(var.tags, {
    Name = "${var.service_name}-${var.environment}-db"
  })
}

# Aurora Cluster (alternative to RDS)
resource "aws_rds_cluster" "microservice" {
  count = var.enable_rds && var.use_aurora ? 1 : 0

  cluster_identifier = "${var.service_name}-${var.environment}-aurora"
  
  engine         = "aurora-mysql"
  engine_version = "8.0.mysql_aurora.3.02.0"
  
  database_name   = var.db_name
  master_username = var.db_username
  master_password = var.db_password
  
  vpc_security_group_ids = [aws_security_group.rds[0].id]
  db_subnet_group_name   = aws_db_subnet_group.microservice[0].name
  
  backup_retention_period = var.environment == "prod" ? 7 : 1
  preferred_backup_window = "03:00-04:00"
  
  skip_final_snapshot = var.environment != "prod"
  deletion_protection = var.environment == "prod"
  
  tags = merge(var.tags, {
    Name = "${var.service_name}-${var.environment}-aurora"
  })
}

resource "aws_rds_cluster_instance" "microservice" {
  count = var.enable_rds && var.use_aurora ? var.aurora_instance_count : 0

  identifier         = "${var.service_name}-${var.environment}-aurora-${count.index}"
  cluster_identifier = aws_rds_cluster.microservice[0].id
  instance_class     = var.aurora_instance_class
  engine             = aws_rds_cluster.microservice[0].engine
  engine_version     = aws_rds_cluster.microservice[0].engine_version
}

# ElastiCache Subnet Group
resource "aws_elasticache_subnet_group" "microservice" {
  count      = var.enable_cache ? 1 : 0
  name       = "${var.service_name}-${var.environment}-cache-subnet"
  subnet_ids = var.private_subnet_ids
}

# ElastiCache Redis
resource "aws_elasticache_replication_group" "microservice" {
  count = var.enable_cache ? 1 : 0

  replication_group_id       = "${var.service_name}-${var.environment}"
  description                = "Redis cache for ${var.service_name}"
  
  node_type            = var.cache_node_type
  port                 = 6379
  parameter_group_name = "default.redis7"
  
  num_cache_clusters = var.cache_num_nodes
  
  subnet_group_name  = aws_elasticache_subnet_group.microservice[0].name
  security_group_ids = [aws_security_group.elasticache[0].id]
  
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  
  tags = merge(var.tags, {
    Name = "${var.service_name}-${var.environment}-cache"
  })
}

# SQS Queue
resource "aws_sqs_queue" "microservice" {
  count = var.enable_sqs ? 1 : 0

  name = "${var.service_name}-${var.environment}-queue"
  
  visibility_timeout_seconds = 300
  message_retention_seconds  = 1209600
  max_message_size          = 262144
  delay_seconds             = 0
  receive_wait_time_seconds = 0
  
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.microservice_dlq[0].arn
    maxReceiveCount     = 3
  })
  
  tags = merge(var.tags, {
    Name = "${var.service_name}-${var.environment}-queue"
  })
}

# SQS Dead Letter Queue
resource "aws_sqs_queue" "microservice_dlq" {
  count = var.enable_sqs ? 1 : 0

  name = "${var.service_name}-${var.environment}-dlq"
  
  tags = merge(var.tags, {
    Name = "${var.service_name}-${var.environment}-dlq"
  })
}

# Application Load Balancer
resource "aws_lb" "microservice" {
  name               = "${var.service_name}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = var.environment == "prod"

  tags = merge(var.tags, {
    Name = "${var.service_name}-${var.environment}-alb"
  })
}

# ALB Target Group
resource "aws_lb_target_group" "microservice" {
  name     = "${var.service_name}-${var.environment}-tg"
  port     = var.service_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = var.health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = merge(var.tags, {
    Name = "${var.service_name}-${var.environment}-tg"
  })
}

# ALB Listener
resource "aws_lb_listener" "microservice" {
  load_balancer_arn = aws_lb.microservice.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.microservice.arn
  }
}

# ALB Listener Rule for path-based routing
resource "aws_lb_listener_rule" "microservice" {
  listener_arn = aws_lb_listener.microservice.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.microservice.arn
  }

  condition {
    path_pattern {
      values = ["/${var.service_name}/*"]
    }
  }
}