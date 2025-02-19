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

variable "organizations_aws_service_access_principals" {
  description = <<-EOT
    List of AWS service principal names for which you want to enable integration
    with your organization. Must have `organizations_feature_set` set to ALL.
    See
    https://docs.aws.amazon.com/organizations/latest/userguide/orgs_integrate_services.html
  EOT
  type        = list(string)
  default     = ["cloudtrail.amazonaws.com", "config-multiaccountsetup.amazonaws.com", "config.amazonaws.com", "access-analyzer.amazonaws.com"]
}

variable "organizations_default_iam_user_access_to_billing" {
  description = <<-EOT
    If set to ALLOW, the new account enables IAM users to access account billing
    information if they have the required permissions. If set to DENY, then only
    the root user of the new account can access account billing information.
  EOT
  type        = string
  default     = "ALLOW"
}

variable "organizations_default_role_name" {
  description = <<-EOT
    The name of an IAM role that Organizations automatically preconfigures in
    the new member account. This role trusts the master account, allowing users
    in the master account to assume the role, as permitted by the master account
    administrator.
  EOT
  type        = string
  default     = "OrganizationAccountAccessRole"
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

variable "child_ous" {
  description = <<-EOT
Map of the child organizational units to create and manage. The map key is the name of the OU, and the value is an object containing configuration variables for the OU.
EOT

  type = map(object({
    tags      = optional(map(string), {})
    parent_ou = optional(string, null)
  }))
}

variable "child_accounts" {
  description = <<-EOT
    Map of child accounts to create. The map key is the name of the account and
    the value is an object containing account configuration variables.

    Required keys for each object:
    - email: Email address for the account.

    Optional keys for each object:
    - is_logs_account: Set to true to mark this account as the "logs" account for aggregating AWS Config and CloudTrail data
    - parent_id: Parent Organizational Unit ID or Root ID for the account
    - parent_ou: The parent OU name. Null signifies the root. parent_id will take precedance over this.
    - role_name: Name of IAM role that Organizations automatically preconfigures in the new member account
    - iam_user_access_to_billing: Set to 'ALLOW' or 'DENY' to control IAM user access to billing information
    - enable_config_rules: Set to true to enable org-level AWS Config Rules for this child account
    - tags: Key-value mapping of resource tags

    Example:
    child_accounts = {
      logs = {
        email           = "root-accounts+logs@acme.com"
        is_logs_account = true
      }
      security = {
        email                      = "root-accounts+security@acme.com"
        role_name                  = "OrganizationAccountAccessRole"
        iam_user_access_to_billing = "DENY"
        tags = {
          Tag-Key = "tag-value"
        }
      }
    }
  EOT
  type = map(object({
    email                      = string
    close_on_deletion          = optional(bool, false)
    is_logs_account            = optional(bool, false)
    parent_id                  = optional(string, null)
    parent_ou                  = optional(string, null)
    role_name                  = optional(string, null)
    iam_user_access_to_billing = optional(string, true)
    enable_config_rules        = optional(bool, true)
    tags                       = optional(map(string), {})
  }))
}


#variable "organizations_delegated_administrators" {
#  description = "The accounts to designate as delegated administrators in the organization. A map of service_principal to account id."
#  type        = map(string)
#  default     = {}
#}
