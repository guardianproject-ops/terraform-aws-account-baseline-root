# Existing AWS Organization
data "aws_organizations_organization" "root" {
  count = var.create_organization ? 0 : 1
}

# New AWS Organization
resource "aws_organizations_organization" "root" {
  count = var.create_organization ? 1 : 0

  aws_service_access_principals = var.organizations_aws_service_access_principals
  enabled_policy_types          = var.organizations_enabled_policy_types
  feature_set                   = var.organizations_feature_set
}

resource "aws_organizations_account" "child_accounts" {
  for_each = var.child_accounts

  name  = each.key
  email = each.value["email"]

  close_on_deletion          = lookup(each.value, "close_on_deletion", false)
  iam_user_access_to_billing = lookup(each.value, "iam_user_access_to_billing", var.organizations_default_iam_user_access_to_billing) ? "ALLOW" : "DENY"
  role_name                  = lookup(each.value, "role_name", var.organizations_default_role_name)
  tags                       = merge(module.this.tags, lookup(each.value, "tags", {}))

  parent_id = lookup(each.value, "parent_id", local.root_id)

  lifecycle {
    ignore_changes = [
      role_name,
      # ref: https://github.com/hashicorp/terraform-provider-aws/issues/12585#issuecomment-934657160
      iam_user_access_to_billing
    ]
  }
}

# If you want to move AWS Org admin out of the root account you would do this
#resource "aws_organizations_delegated_administrator" "delegated_administrators" {
#  for_each = var.organizations_delegated_administrators
#
#  account_id        = each.value
#  service_principal = each.key
#}
