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

output "child_ou_ids" {
  description = "A map of all the OUs created by this module. The keys are the names of the OUs and the values are the IDs"
  value = merge(
    { for ou in aws_organizations_organizational_unit.ous : ou.name => ou.id },
    { for ou in aws_organizations_organizational_unit.child_ous : ou.name => ou.id }
  )
}

output "child_ou_arns" {
  description = "A map of all the OUs created by this module. The keys are the names of the OUs and the values are the ARNs"
  value = merge(
    { for ou in aws_organizations_organizational_unit.ous : ou.name => ou.arn },
    { for ou in aws_organizations_organizational_unit.child_ous : ou.name => ou.arn }
  )
}
