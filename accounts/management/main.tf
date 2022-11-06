module "oidc_github_provider" {
  source = "../../modules/oidc_github_provider"
}

module "github_oidc_role" {
  source                   = "../../modules/github_oidc_role"
  oidc_github_provider_arn = module.oidc_github_provider.arn
  github_org               = var.github_org
  github_repos             = [var.repo]

  role_name        = "github-role-for-${var.repo}-repo"
  role_description = "Role for github ${var.repo} repository"

  # Policy restricting what github repo can do once it assumes this role
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

