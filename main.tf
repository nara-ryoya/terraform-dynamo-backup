//make dynamodb + backup

data "aws_caller_identity" "current" {}

output "account_id" {
  description = "The ID of the AWS account"
  value       = data.aws_caller_identity.current.account_id
}

provider "aws" {
  region = "ap-northeast-1"
}

resource "aws_dynamodb_table" "dynamodb_table" {
  name         = "dynamodb-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"
  attribute {
    name = "id"
    type = "S"
  }
  tags = {
    Name = "dynamodb-table"
  }
}

resource "aws_backup_plan" "backup_plan" {
  name = "backup-plan"

  rule {
    rule_name         = "backup-rule"
    target_vault_name = aws_backup_vault.backup_vault.name
    schedule          = "cron(0 12 * * ? *)"
    start_window      = 60
    completion_window = 360
    lifecycle {
      cold_storage_after = 90
      delete_after       = 365
    }
  }
}

resource "aws_iam_role" "backup_role" {
  name = "backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "backup_operator_access" {
  name       = "backup-operator-access"
  policy_arn = aws_iam_policy.backup_operator_policy.arn
  roles      = [aws_iam_role.backup_role.name]
}


resource "aws_iam_policy" "backup_operator_policy" {
  name        = "backup-operator-policy"
  description = "Custom policy for AWS Backup"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "backup:*",
          "dynamodb:DescribeTable",
          "dynamodb:ListTagsOfResource",
          "dynamodb:UpdateTimeToLive",
          "dynamodb:DescribeTimeToLive"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}



resource "aws_backup_selection" "backup_selection" {
  name         = "backup-selection"
  plan_id      = aws_backup_plan.backup_plan.id
  iam_role_arn = aws_iam_role.backup_role.arn

  resources = [
    aws_dynamodb_table.dynamodb_table.arn
  ]
}

resource "aws_backup_vault" "backup_vault" {
  name = "backup_vault"
}