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
  validation {
    condition = alltrue([
      for account in values(var.accounts) :
      account.name != null &&
      account.name != ""
    ])
    error_message = "Account name cannot be null or empty."
  }

  validation {
    condition = alltrue([
      for account in values(var.accounts) :
      account.email != null &&
      account.email != ""
    ])
    error_message = "Account email cannot be null or empty."
  }

  validation {
    condition = alltrue([
      for account in values(var.accounts) :
      account.parent != null &&
      account.parent != ""
    ])
    error_message = "Account parent cannot be null or empty."
  }
}

variable "organizational_unit_id_on_delete" {
  description = "The ID of the organizational unit to move accounts to when they are deleted."
  type        = string
  default     = null
}

resource "controltower_aws_account" "account" {
  for_each                         = var.accounts
  name                             = each.value.name
  email                            = each.value.email
  organizational_unit              = each.value.parent
  close_account_on_delete          = true
  organizational_unit_id_on_delete = var.organizational_unit_id_on_delete
  tags                             = each.value.tags

  sso {
    # We always delete this user as soon as it is created (outside terraform unfortunately)
    first_name                          = "Guardian Project"
    last_name                           = "Dummy"
    email                               = "aws-root+dummy@gpcmdln.net"
    permission_set_name                 = "AWSReadOnlyAccess"
    remove_account_assignment_on_update = true
  }
  lifecycle {
    ignore_changes = [
      email, sso["email"]
    ]
  }
}

output "accounts" {
  description = "A map of all accounts created by this module. The keys are the names of the accounts and the values are the IDs."
  value = {
    for account in controltower_aws_account.account : account.name => {
      name  = account.name
      email = account.email
      ou    = account.organizational_unit
      id    = account.account_id
    }
  }
}
