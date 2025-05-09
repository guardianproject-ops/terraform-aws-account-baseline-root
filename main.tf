locals {
  enabled                                = module.this.enabled
  guardduty_enabled                      = local.enabled && var.guardduty_delegation_enabled
  securityhub_enabled                    = local.enabled && var.securityhub_delegation_enabled
  auditmanager_delegation_enabled        = local.enabled && var.auditmanager_delegation_enabled
  iam_access_analyzer_delegation_enabled = local.enabled && var.iam_access_analyzer_delegation_enabled

  accounts_by_id = {
    for account in data.aws_organizations_organization.pre.accounts : account.id => account
  }
}

data "aws_organizations_organization" "pre" {}

module "landing_zone" {
  source                             = "guardianproject-ops/control-tower-landing-zone/aws"
  version                            = "0.0.3"
  email_address_account_audit        = local.accounts_by_id[var.control_tower_accounts.audit.id].email
  email_address_account_log_archiver = local.accounts_by_id[var.control_tower_accounts.logging.id].email
  governed_regions                   = var.governed_regions
}

module "organization" {
  source                                      = "./organization"
  context                                     = module.this.context
  child_ous                                   = var.ous
  create_organization                         = var.create_organization
  organizations_aws_service_access_principals = var.organizations_aws_service_access_principals
  organizations_enabled_policy_types          = var.organizations_enabled_policy_types
  organizations_feature_set                   = var.organizations_feature_set
  tags                                        = var.organizations_default_tags
}

module "accounts" {
  source                           = "./accounts"
  context                          = module.this.context
  accounts                         = var.accounts
  organizational_unit_id_on_delete = var.organizational_unit_id_on_delete
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
  admin_account_id = var.guardduty_admin_account_id != null ? var.guardduty_admin_account_id : var.control_tower_accounts.audit.id
}

# Since we are are in the AWS Org management account, delegate SecurityHub to our Control Tower Audit account
resource "aws_securityhub_organization_admin_account" "default" {
  count            = local.securityhub_enabled ? 1 : 0
  admin_account_id = var.securityhub_admin_account_id != null ? var.securityhub_admin_account_id : var.control_tower_accounts.audit.id
  depends_on       = [module.organization]
}

resource "aws_auditmanager_account_registration" "this" {
  count                   = local.auditmanager_delegation_enabled == true ? 1 : 0
  delegated_admin_account = var.control_tower_accounts.audit.id
  deregister_on_destroy   = true
}

resource "aws_organizations_delegated_administrator" "iam_access_analyzer" {
  count             = local.iam_access_analyzer_delegation_enabled == true ? 1 : 0
  account_id        = var.control_tower_accounts.audit.id
  service_principal = "access-analyzer.amazonaws.com"
}

#resource "aws_iam_service_linked_role" "access_analyzer" {
#  count            = local.iam_access_analyzer_delegation_enabled == true ? 1 : 0
#  aws_service_name = "access-analyzer.amazonaws.com"
#  description      = "Service-Linked Role for Access Analyzer, used by the landing zone"
#  tags             = module.this.tags
#}

module "break_glass" {
  source = "git::https://gitlab.com/guardianproject-ops/terraform-aws-account-break-glass//modules/target?ref=v0.0.1"

  allow_break_glass      = var.break_glass.enabled
  break_glass_principals = var.break_glass.principals
  break_glass_policy_arn = var.break_glass.policy_arn
  break_glass_role_name  = var.break_glass.role_name
}
