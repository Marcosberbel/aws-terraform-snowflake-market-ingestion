output "roles" {
  description = "Roles creados por entorno"
  value = {
    for env, r in aws_iam_role.terraform_env_role :
    env => {
      name = r.name
      arn  = r.arn
    }
  }
}
