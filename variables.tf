variable "github_org" {
  type        = string
  description = "Organization or username in github"
}

variable "github_repo" {
  type        = string
  description = "Repository in github that would be allowed to perform actions in AWS account"
}
