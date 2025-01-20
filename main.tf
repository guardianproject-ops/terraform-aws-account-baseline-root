locals {
  enabled            = module.this.enabled
  guardduty_enabled  = local.enabled && var.guardduty_delegation_enabled
  audit_account      = [for name, account in var.child_accounts : account if account.is_audit_account][0]
  logs_account       = [for name, account in var.child_accounts : account if account.is_logs_account][0]
  audit_account_name = [for name, account in var.child_accounts : name if account.is_audit_account][0]
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
  count            = local.guardduty_enabled ? 1 : 0
  admin_account_id = var.guardduty_admin_account_id != null ? var.guardduty_admin_account_id : module.organization.child_account_ids[local.audit_account_name]
}

module "landing_zone" {
  source                             = "guardianproject-ops/control-tower-landing-zone/aws"
  version                            = "0.0.1"
  email_address_account_audit        = local.audit_account.email
  email_address_account_log_archiver = local.logs_account.email
  governed_regions                   = var.governed_regions
}
