# Allow EventBridge Scheduler to invoke the Lambda.
resource "aws_lambda_permission" "allow_scheduler" {
  statement_id  = "AllowSchedulerInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "scheduler.amazonaws.com"
}

# Scheduler execution role (least privilege).
data "aws_iam_policy_document" "scheduler_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "scheduler_role" {
  name               = "${local.project}-scheduler-${local.env}"
  assume_role_policy = data.aws_iam_policy_document.scheduler_assume.json
  tags               = local.tags
}

data "aws_iam_policy_document" "scheduler_invoke_lambda" {
  statement {
    actions   = ["lambda:InvokeFunction"]
    resources = [aws_lambda_function.api.arn]
  }
}

resource "aws_iam_policy" "scheduler_invoke_lambda" {
  name   = "${local.project}-scheduler-invoke-${local.env}"
  policy = data.aws_iam_policy_document.scheduler_invoke_lambda.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "scheduler_invoke_attach" {
  role       = aws_iam_role.scheduler_role.name
  policy_arn = aws_iam_policy.scheduler_invoke_lambda.arn
}

# Three schedules per day (UTC). Each run processes a different chunk.
locals {
  schedules = {
    "every8h-00" = { cron = "cron(0 0 * * ? *)", chunk_index = 0 }
    "every8h-08" = { cron = "cron(0 8 * * ? *)", chunk_index = 1 }
    "every8h-16" = { cron = "cron(0 16 * * ? *)", chunk_index = 2 }
  }
}

resource "aws_scheduler_schedule" "daily_3x" {
  for_each = local.schedules

  name                = "${local.project}-${local.env}-${each.key}"
  schedule_expression = each.value.cron

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_lambda_function.api.arn
    role_arn = aws_iam_role.scheduler_role.arn

    input = jsonencode({
      source      = "scheduler"
      chunk_index = each.value.chunk_index
    })
  }
}
