terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

  # backend "s3" {
  #   region         = "<YOUR_AWS_REGION>"
  #   bucket         = "terraform-state-for-<YOUR_GITHUB_ORG or USERNAME>-<YOUR_GITHUB_REPO>"
  #   dynamodb_table = "terraform-state-lock"
  #   kms_key_id     = "alias/terraform-bucket-key"

  #   key     = "org-shared-state/terraform.tfstate"
  #   encrypt = true
  # }
}

provider "aws" {
  region = local.aws_region
}

# Those values are not passed as variables because sadly you need to hardcode them in "backend" above
# so let's at least keep them close to one another
# This can be avoided by using Terragrunt, but that's an adventure for another day
locals {
  aws_region                             = "<YOUR_AWS_REGION>"
  terraform_state_bucket_name            = "terraform-state-for-<YOUR_GITHUB_ORG or USERNAME>-<YOUR_GITHUB_REPO>" # or anything else unique accross whole AWS
  terraform_state_dynamo_lock_table_name = "terraform-state-lock"
  terraform_state_kms_key_alias          = "alias/terraform-bucket-key"
}


module "terraform_backend" {
  source = "./backend"

  state_bucket_name      = local.terraform_state_bucket_name
  dynamo_lock_table_name = local.terraform_state_dynamo_lock_table_name
  kms_key_alias          = local.terraform_state_kms_key_alias
}

module "management_account" {
  source = "./accounts/management"

  github_org = var.github_org
  repo       = var.github_repo
}
