# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Default principal fallback logic
locals {
  default_principal          = "arn:aws:iam::" + data.aws_caller_identity.current.account_id + ":root"
  effective_read_principals  = length(var.allowed_read_principals) > 0 ? var.allowed_read_principals : [local.default_principal]
  effective_write_principals = length(var.allowed_write_principals) > 0 ? var.allowed_write_principals : [local.default_principal]
}


# ECR Repositories
resource "aws_ecr_repository" "repositories" {
  for_each = toset(var.repositories)

  name                  = "${var.project_name}-${each.value}"
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = var.encryption_type
    kms_key         = var.kms_key_id
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${each.value}"
  })
}

# ECR Repository Policies
resource "aws_ecr_repository_policy" "repositories" {
  for_each = toset(var.repositories)

  repository = aws_ecr_repository.repositories[each.value].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowPull"
        Effect = "Allow"
        Principal = {
          AWS = local.effective_read_principals
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
      },
      {
        Sid    = "AllowPush"
        Effect = "Allow"
        Principal = {
          AWS = local.effective_write_principals
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
      }
    ]
  })
}

# ECR Lifecycle Policies
locals {
  lifecycle_policy = {
    rules = [
      {
        rulePriority = 1
        description  = "Keep last ${var.max_image_count} images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = var.max_image_count
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Delete untagged images older than ${var.untagged_image_days} days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.untagged_image_days
        }
        action = {
          type = "expire"
        }
      }
    ]
  }
}

resource "aws_ecr_lifecycle_policy" "repositories" {
  for_each = var.lifecycle_policy_enabled ? toset(var.repositories) : []

  repository = aws_ecr_repository.repositories[each.value].name
  policy     = jsonencode(local.lifecycle_policy)
}
