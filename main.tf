locals {
  enabled = module.this.enabled
}

module "organization" {
  source                                           = "./organization"
  child_accounts                                   = var.child_accounts
  create_organization                              = var.create_organization
  organizations_aws_service_access_principals      = var.organizations_aws_service_access_principals
  organizations_default_iam_user_access_to_billing = var.organizations_default_iam_user_access_to_billing
  organizations_default_role_name                  = var.organizations_default_role_name
  organizations_enabled_policy_types               = var.organizations_enabled_policy_types
  organizations_feature_set                        = var.organizations_feature_set
  tags                                             = var.organizations_default_tags
}

# Since we are are in the AWS Org management account, delegate GuardDuty to our Control Tower Audit account
resource "aws_guardduty_organization_admin_account" "this" {
  count            = local.enabled ? 1 : 0
  admin_account_id = var.guardduty_admin_account_id
}
