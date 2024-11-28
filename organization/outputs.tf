output "organization_arn" {
  description = "ARN of the organization."
  value       = local.organization_arn
}

output "organization_id" {
  description = "Identifier of the organization."
  value       = local.organization_id
}

output "organization_root_id" {
  description = "Identifier of the root of this organization."
  value       = local.root_id
}

output "master_account_arn" {
  description = "ARN of the master account."
  value       = local.master_account_arn
}

output "master_account_id" {
  description = "Identifier of the master account."
  value       = local.master_account_id
  sensitive   = true
}

output "master_account_email" {
  description = "Email address of the master account."
  value       = local.master_account_email
  sensitive   = true
}

output "child_account_ids" {
  description = "A map of all accounts created by this module (NOT including the root account). The keys are the names of the accounts and the values are the IDs."
  value = {
    for account in aws_organizations_account.child_accounts : account.name => account.id
  }
  sensitive = true
}
