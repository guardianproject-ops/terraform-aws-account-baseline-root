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

