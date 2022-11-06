resource "aws_iam_role" "default" {
  name               = var.role_name
  description        = var.role_description
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

// policy that restricts who can assume the role
data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [var.oidc_github_provider_arn]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        for repo in var.github_repos : "repo:${var.github_org}/${repo}:*"
      ]
    }
  }
}

resource "aws_iam_role_policy_attachment" "default" {
  role       = aws_iam_role.default.id
  policy_arn = var.policy_arn
}
