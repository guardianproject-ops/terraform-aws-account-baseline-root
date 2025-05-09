######################
# REQUIRED VARIABLES #
######################
variable "governed_regions" {
  description = "List of AWS regions to enable LandingZone, GuardDuty, etc in"
  type        = list(string)
}

variable "ous" {
  description = <<-EOT
Map of the child organizational units to create and manage. The map key is the name of the OU, and the value is an object containing configuration variables for the OU.
EOT

  type = map(object({
    tags      = optional(map(string), {})
    parent_ou = optional(string, null)
  }))
}

variable "accounts" {
  description = <<-EOT
Map of the AWS accounts to ensure are created with AWS Control Tower.
EOT
  type = map(object({
    name   = string
    email  = string
    parent = string
    tags   = optional(map(string))
  }))
}

variable "control_tower_accounts" {
  description = "Information about the pre-req Control Tower core accounts. These must already exist!"
  type = object({
    audit = object({
      id = string
    })
    management = object({
      id = string
    })
    logging = object({
      id = string
    })
  })
}

variable "guardduty_delegation_enabled" {
  type        = bool
  default     = true
  description = <<-EOT
Whether to delegate GuardDuty administration to the GuardDuty delegated admin account.
EOT
}

variable "guardduty_admin_account_id" {
  description = "The AWS account ID of the GuardDuty delegated admin account, if not specified, defaults to the Audit account created by Control Tower"
  type        = string
  default     = null
}

variable "organizations_aws_service_access_principals" {
  description = <<-EOT
    List of AWS service principal names for which you want to enable integration
    with your organization. Must have `organizations_feature_set` set to ALL.
    See
    https://docs.aws.amazon.com/organizations/latest/userguide/orgs_integrate_services.html
  EOT
  type        = list(string)
  default = [
    "auditmanager.amazonaws.com",
    "access-analyzer.amazonaws.com",
    "account.amazonaws.com",
    "backup.amazonaws.com",
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "controltower.amazonaws.com",
    "member.org.stacksets.cloudformation.amazonaws.com",
    "sso.amazonaws.com",
    "guardduty.amazonaws.com",
    "malware-protection.guardduty.amazonaws.com",
    "securityhub.amazonaws.com",
    "access-analyzer.amazonaws.com",
    "iam.amazonaws.com"
  ]
}

variable "organizations_default_tags" {
  description = "Default tags to add to accounts. Will be appended to ´child_account.*.tags´"
  type        = map(string)
  default     = {}
}

variable "organizations_enabled_policy_types" {
  description = <<-EOT
    List of Organizations policy types to enable in the Organization Root. See
    https://docs.aws.amazon.com/organizations/latest/APIReference/API_EnablePolicyType.html
  EOT
  type        = list(string)
  default     = ["BACKUP_POLICY", "SERVICE_CONTROL_POLICY"]
}

variable "organizations_feature_set" {
  description = "Specify `ALL` or `CONSOLIDATED_BILLING`."
  type        = string
  default     = "ALL"
}

variable "create_organization" {
  description = <<-EOT
    Set to true to create/configure AWS Organizations for the first time in this
    account. If you already configured AWS Organizations in your account, set
    this to false; alternatively, you could set it to true and run 'terraform
    import' to import you existing Organization.
  EOT
  type        = bool
  default     = true
}


variable "securityhub_delegation_enabled" {
  type        = bool
  default     = true
  description = <<-EOT
Whether to delegate SecurityHub administration to the SecurityHub delegated admin account.
EOT
}

variable "securityhub_admin_account_id" {
  description = "The AWS account ID of the SecurityHub delegated admin account, if not specified, defaults to the Audit account created by Control Tower"
  type        = string
  default     = null
}

variable "auditmanager_delegation_enabled" {
  type        = bool
  default     = true
  description = <<-EOT
Whether to delegate AuditManager administration to the delegated admin account.
EOT
}

variable "iam_access_analyzer_delegation_enabled" {
  type        = bool
  default     = true
  description = <<-EOT
Whether to delegate IAM Access Analyzer administration to the delegated admin account.
EOT
}

variable "controltower_guardrails" {
  type = list(object({
    control_name   = string
    is_global_type = optional(bool, true)
    ou_name        = string
    parameters     = optional(map(string), {})
  }))
  description = "Configuration of AWS Control Tower Guardrails for the whole organization"
}

variable "organizational_unit_id_on_delete" {
  description = "The ID of the organizational unit to move accounts to when they are deleted."
  type        = string
  default     = null
}

variable "break_glass" {
  type = object({
    enabled    = bool
    principals = list(string)
    role_name  = optional(string, "BreakGlassRole")
    policy_arn = optional(string, "arn:aws:iam::aws:policy/AdministratorAccess")
  })
  description = <<EOT
Configuration for emergency "break glass" access to the AWS account.

**Fields:**

* `enabled` - (Required) Boolean flag to control whether the emergency access role is created.
  Set to true to enable emergency access capabilities.

* `principal` - (Required) The AWS principal that can assume the emergency role.
  Can be an AWS account root ARN, an IAM user ARN, or an IAM role ARN.
  Format examples:
  - AWS account: ["arn:aws:iam::123456789012}:root"]
  - IAM user: ["arn:aws:iam::123456789012:user/EmergencyUser"]
  - IAM role: ["arn:aws:iam::123456789012:role/EmergencyRole"]
  - Multiple principals: ["arn:aws:iam::123456789012:user/User1", "arn:aws:iam::123456789012:user/User2"]

* `role_name` - (Optional) Name of the IAM role created for emergency access.
  Defaults to "BreakGlassRole" if not specified. If you change this from the default value,
  you must also change it in the break glass account and ensure your break glass documentation
  and procedures are updated accordingly so authorized personnel know which role to
  assume during an emergency.

* `policy_arn` - (Optional) ARN of the IAM policy to attach to the emergency role.
  Defaults to "arn:aws:iam::aws:policy/AdministratorAccess" if not specified.
  Consider using a more restrictive policy based on your specific emergency scenarios.

**Security Note:** Break glass access should be strictly controlled, thoroughly audited,
and only used in genuine emergency situations. Ensure proper monitoring and alerting
are set up for any use of this role.
EOT
}
