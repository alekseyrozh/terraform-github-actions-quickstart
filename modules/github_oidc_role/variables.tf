variable "role_name" {
  description = "Friendly name of the role. If omitted, Terraform will assign a random, unique name."
  type        = string
}

variable "role_description" {
  description = "Description of the role"
  type        = string
}

variable "oidc_github_provider_arn" {
  type = string
}

variable "github_org" {
  description = "GitHub organisation name."
  type        = string
}

variable "github_repos" {
  description = "List of GitHub repository names."
  type        = list(string)
}

variable "policy_arn" {
  type = string
}
