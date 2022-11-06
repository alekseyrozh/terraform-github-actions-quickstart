# Preconditions:

- Have AWS CLI installed

- Have Terraform Cli installed

- Have AWS account credentials exported/configured with sufficient rights to create and destroy stuff

# How to start using terraform with github actions

## Steps:

1. Clone this repository

2. Make sure you're making changes to the right AWS account. Execute this command to see who you are authenticated as

```
aws sts get-caller-identity
```

3. Change aws region and bucket name to what you need.

- Open `./main.tf`
- Change `aws-region` in `locals` to the region you want
- Change `terraform_state_bucket_name` to the bucket name that makes sense for your project. **Bucket name must be unique across all of AWS**
- Change `region` and `bucket` in `backend` configuration a few lines above to match the values you just set in `locals`. Keep backend configuration commented out for now

4. Specify which github repository you want to give permissions to apply terraform to your AWS account

- Open `./terraform.tfvars`
- Change `github_org` value to your github org or username
- Change `github_repo` value to the github repository name you want to give permissions to apply terraform to your AWS account (you can create a new repository)

5. Terraform init for the first time

```
terraform init
```

6. Terraform apply for the first time

   This will create:

- S3 bucket fro storing terraform state
- Dynamodb table for locking the state
- Secret in KMS for encypting data in s3
- Github identity provider, so that you repo can assume role without storing credentials
- A role that your github repo can assume that gives AdministratorAccess to your AWS account (the policy attached to this role can be modified in `./accounts/management/main.tf`)

```
terraform apply

-> Do you want to perform these actions?
yes
```

This will also output the arn of the created role, you will need it later to configure github actions

```
github_iam_role_arn = "arn:aws:iam::123456890:role/github-role-for-<YOUR_GITHUB_REPO>-repo"
```

7.  Uncomment the s3 backend provider code in `./main.tf`, cause now we created all infrastructure to be able to switch to new backend

```
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    region         = "<YOUR_AWS_REGION>"
    bucket         = "terraform-state-for-<YOUR_GITHUB_ORG or USERNAME>-<YOUR_GITHUB_REPO>" # or anything else unique accross whole AWS
    dynamodb_table = "terraform-state-lock"
    kms_key_id     = "alias/terraform-bucket-key"

    key     = "org-shared-state/terraform.tfstate"
    encrypt = true
  }
}
```

8.  Terraform init once again cause we're using new backend

```
terraform init

-> Do you want to copy existing state to the new backend?
yes
```

9. Just as a test, do terraform apply and see 0 changes

```
terraform apply
```

10. Open `./.github/workflows/apply-on-master.yml` and `./.github/workflows/plan-on-PR.yml` and in both of them

- set `ROLE_TO_ASSUME` to the arn that terraform apply output gave you in step 6 (or step 9)
- set `AWS_REGION` to the region that you set for terraform backend in `./main.tf`

11. Commit your code to `master`, add your repository as remote, and push to `master`

This step will push your code to the repo and in `Actions` tab on github you will see 2 github action appear

Note that repository name and org should match what you specified in `./terraform.tfvars`

```git
git add .
git commit -m "setup remote state and gh actions"

git remote remove origin
git remote add origin git@github.com:<YOUR_GITHUB_ORG or USERNAME>/<YOUR_GITHUB_REPO>.git
git push --set-upstream origin master
```

12. Create a test PR creating an S3 bucket

- Open `./accounts/management/main.tf`
- Add an S3 bucket at bottom (note that the name should be unique across all AWS)

```hcl
resource "aws_s3_bucket" "terraform_state" {
  bucket = "my-test-bucket-<YOUR_GITHUB_ORG or USERNAME>-<YOUR_GITHUB_REPO>" # or anything else unique accross whole AWS
}
```

- Create a PR with those changes

```
git checkout -b "add-my-first-test-bucket"
git add .
git commit -m "added my first bucket"
git push --set-upstream origin add-my-first-test-bucket
```

- Click on the link that git cli gives you to create PR

13. See `Terraform Plan on PR` action automatically start on the PR. Once the action finishes it will create a comment on your PR where you can preview the result of `terraform plan`

14. Merge the PR and see the effect of terraform apply

- Merge pull request
- See `Terraform Apply on Master` action starting
- After it's finished, the test bucket should appear in AWS account

15. Create another PR to delete the test bucket

- Pull latest master and create a new branch off it

```
git checkout master
git pull
git checkout -b "remove-test-bucket"
```

- Open `./accounts/management/main.tf` and remove the lines we added in step 12

```hcl
resource "aws_s3_bucket" "terraform_state" {
  bucket = "my-test-bucket-<YOUR_GITHUB_ORG or USERNAME>-<YOUR_GITHUB_REPO>"
}
```

- Commit and create a PR

```
git add .
git commit -m "remove test bucket"
git push --set-upstream origin remove-test-bucket
```

- Click on the link that git cli gives you to create PR
- Wait until `Terraform Plan on PR` finishes and adds a comment to a PR to of with the plan that removes the bucket
- Merge pull request
- Wait until `Terraform Apply on Master` succeeds
- Verify the bucket is deleted from AWS account

16. At this point you can delete the user or the role from AWS that you initially used to make changes to AWS account (and turn it into a readonly user), and let github actions make all infrustructure changes to your AWS account

17. All the new changes to the account can be added at the bottom of `./accounts/management/main.tf` and can be previed/applied by creating a PR and merging it. Terraform plan can be done locally, however, if your user has read-only permissions the only way to apply terraform is by merging a PR

# Notes on this setup:

- The good thing is that credentials to your AWS account do not need to be set/stored anywhere in github thanks to OpenID connect provider configured through terraform

- Terraform apply is only triggered when the PR is merged. Pushing directly to master is ignored. If code was pushed directly to master, it will show up in the next PR's plan.

- `aws region` value needs to be hadcoded in 4 places: 2 github actions and twice in `./main.tf`. Terragrunt might help with the latter, but hardcoding `aws region` only once and share between terraform and gh actions might be tricky to achieve (not impossible though)

- `role to assume` value that `terraform apply` outputs needs to be hardcoded twice in github actions

# How to destroy all created infrastructure (including stored state) without messing things up

1. Have/create a user or the role has sufficient rights to create and destroy stuff in your AWS accounts

2. Have the credentials for this configured/exported

3. Make sure you're making changes to the right AWS account. Execute this command to see who you are authenticated as

```
aws sts get-caller-identity
```

4. Comment out the backend configuration in `./main.tf`

```
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
```

5. Move state from s3 backend to local backend

```
terraform init -migrate-state

-> Do you want to copy existing state to the new backend?
yes
```

6. Make the s3 bucket that stores state as destroyable

In `./backend/main.tf` change `prevent_destroy = true` to `prevent_destroy = false` in s3 bucket resource

7. Delete all content of all versions in the bucket.

You have 2 options:

a) via AWS console, go to s3, select the bucket and click `EMPTY BUCKET`

b) via AWS CLI:

Run the command after
**replacing `<YOUR BUCKET NAME>` with your bucket name in 2 places**.

```
aws s3api delete-objects --bucket <YOUR BUCKET NAME> \
  --delete "$(aws s3api list-object-versions \
  --bucket "<YOUR BUCKET NAME>" \
  --output=json \
  --query='{Objects: Versions[].{Key:Key,VersionId:VersionId}}')"
```

8. Run terraform destroy

```
terraform destroy

-> Do you really want to destroy all resources?
yes
```
