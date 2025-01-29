data "aws_caller_identity" "this" {}
locals {
  enabled                                = module.this.enabled
  guardduty_enabled                      = local.enabled && var.guardduty_delegation_enabled
  securityhub_enabled                    = local.enabled && var.securityhub_delegation_enabled
  auditmanager_delegation_enabled        = local.enabled && var.auditmanager_delegation_enabled
  iam_access_analyzer_delegation_enabled = local.enabled && var.iam_access_analyzer_delegation_enabled
  audit_account                          = [for name, account in var.child_accounts : account if account.is_audit_account][0]
  logs_account                           = [for name, account in var.child_accounts : account if account.is_logs_account][0]
  log_account_name                       = [for name, account in var.child_accounts : name if account.is_logs_account][0]
  audit_account_name                     = [for name, account in var.child_accounts : name if account.is_audit_account][0]
  audit_account_id                       = module.organization.child_account_ids[local.audit_account_name]
  log_account_id                         = module.organization.child_account_ids[local.log_account_name]
  management_account_id                  = data.aws_caller_identity.this.account_id

}

module "landing_zone" {
  source  = "guardianproject-ops/control-tower-landing-zone/aws"
  version = "0.0.1"
  #context                            = module.this.context
  email_address_account_audit        = local.audit_account.email
  email_address_account_log_archiver = local.logs_account.email
  governed_regions                   = var.governed_regions
}

module "organization" {
  source                                           = "./organization"
  context                                          = module.this.context
  child_accounts                                   = var.child_accounts
  child_ous                                        = var.child_ous
  create_organization                              = var.create_organization
  organizations_aws_service_access_principals      = var.organizations_aws_service_access_principals
  organizations_default_iam_user_access_to_billing = var.organizations_default_iam_user_access_to_billing
  organizations_default_role_name                  = var.organizations_default_role_name
  organizations_enabled_policy_types               = var.organizations_enabled_policy_types
  organizations_feature_set                        = var.organizations_feature_set
  tags                                             = var.organizations_default_tags
}

module "control_tower_controls" {
  source           = "./control-tower-controls"
  context          = module.this.context
  guardrails       = var.controltower_guardrails
  ou_names_to_arns = module.organization.child_ou_arns
  depends_on       = [module.organization, module.landing_zone]
}

# Since we are are in the AWS Org management account, delegate GuardDuty to our Control Tower Audit account
resource "aws_guardduty_organization_admin_account" "this" {
  count            = local.guardduty_enabled ? 1 : 0
  admin_account_id = var.guardduty_admin_account_id != null ? var.guardduty_admin_account_id : local.audit_account_id
}

# Since we are are in the AWS Org management account, delegate SecurityHub to our Control Tower Audit account
resource "aws_securityhub_organization_admin_account" "default" {
  count            = local.securityhub_enabled ? 1 : 0
  admin_account_id = var.securityhub_admin_account_id != null ? var.securityhub_admin_account_id : local.audit_account_id
  depends_on       = [module.organization]
}

resource "aws_auditmanager_account_registration" "this" {
  count                   = local.auditmanager_delegation_enabled == true ? 1 : 0
  delegated_admin_account = local.audit_account_id
  deregister_on_destroy   = true
}

resource "aws_organizations_delegated_administrator" "iam_access_analyzer" {
  count             = local.iam_access_analyzer_delegation_enabled == true ? 1 : 0
  account_id        = local.audit_account_id
  service_principal = "access-analyzer.amazonaws.com"
}

#resource "aws_iam_service_linked_role" "access_analyzer" {
#  count            = local.iam_access_analyzer_delegation_enabled == true ? 1 : 0
#  aws_service_name = "access-analyzer.amazonaws.com"
#  description      = "Service-Linked Role for Access Analyzer, used by the landing zone"
#  tags             = module.this.tags
#}
