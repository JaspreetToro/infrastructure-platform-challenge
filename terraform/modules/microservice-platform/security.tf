# IAM Role for Microservice
resource "aws_iam_role" "microservice_role" {
  name = "${var.service_name}-${var.environment}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(var.oidc_provider_arn, "/^.*oidc-provider//", "")}:sub" = "system:serviceaccount:${var.service_name}:${var.service_name}-sa"
            "${replace(var.oidc_provider_arn, "/^.*oidc-provider//", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.service_name}-${var.environment}-role"
  })
}

# IAM Policy for Microservice
resource "aws_iam_role_policy" "microservice_policy" {
  name = "${var.service_name}-${var.environment}-policy"
  role = aws_iam_role.microservice_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      var.enable_sqs ? [
        {
          Effect = "Allow"
          Action = [
            "sqs:SendMessage",
            "sqs:ReceiveMessage",
            "sqs:DeleteMessage",
            "sqs:GetQueueAttributes"
          ]
          Resource = [
            aws_sqs_queue.microservice[0].arn,
            aws_sqs_queue.microservice_dlq[0].arn
          ]
        }
      ] : [],
      [
        {
          Effect = "Allow"
          Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ]
          Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
        }
      ]
    )
  })
}

# Security Group for ALB
resource "aws_security_group" "alb" {
  name_prefix = "${var.service_name}-${var.environment}-alb-"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.service_name}-${var.environment}-alb-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group for RDS
resource "aws_security_group" "rds" {
  count = var.enable_rds ? 1 : 0

  name_prefix = "${var.service_name}-${var.environment}-rds-"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL/Aurora"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.microservice.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.service_name}-${var.environment}-rds-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group for ElastiCache
resource "aws_security_group" "elasticache" {
  count = var.enable_cache ? 1 : 0

  name_prefix = "${var.service_name}-${var.environment}-cache-"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Redis"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.microservice.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.service_name}-${var.environment}-cache-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group for Microservice Pods
resource "aws_security_group" "microservice" {
  name_prefix = "${var.service_name}-${var.environment}-pods-"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Service Port"
    from_port       = var.service_port
    to_port         = var.service_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.service_name}-${var.environment}-pods-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}