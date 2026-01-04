provider "aws" {
  region = var.aws_region
}

locals {
  envs = toset(var.environments)

  common_tags = merge(
    {
      Project   = var.project
      ManagedBy = "terraform"
      Layer     = "bootstrap"
    },
    var.tags
  )
}

data "aws_iam_policy_document" "assume_role" {
  for_each = local.envs

  statement {
    sid     = "AllowAssumeFromBase"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [var.base_principal_arn]
    }

    dynamic "condition" {
      for_each = var.require_mfa ? [1] : []
      content {
        test     = "Bool"
        variable = "aws:MultiFactorAuthPresent"
        values   = ["true"]
      }
    }

    dynamic "condition" {
      for_each = var.external_id != null ? [1] : []
      content {
        test     = "StringEquals"
        variable = "sts:ExternalId"
        values   = [var.external_id]
      }
    }
  }
}

resource "aws_iam_role" "terraform_env_role" {
  for_each = local.envs

  name               = "${var.role_name_prefix}${upper(each.key)}"
  assume_role_policy = data.aws_iam_policy_document.assume_role[each.key].json

  tags = merge(local.common_tags, {
    Environment = each.key
  })
}

# Adjunta las policies (por defecto AdministratorAccess) a cada rol
resource "aws_iam_role_policy_attachment" "attach_policies" {
  for_each = {
    for pair in flatten([
      for env in local.envs : [
        for pol in var.permissions_policy_arns : {
          key    = "${env}__${pol}"
          env    = env
          policy = pol
        }
      ]
    ]) : pair.key => pair
  }

  role       = aws_iam_role.terraform_env_role[each.value.env].name
  policy_arn = each.value.policy
}
