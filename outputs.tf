output "landing_zone" {
  value = module.landing_zone
}

output "organization" {
  value = module.organization
}

output "guardrails" {
  value = module.control_tower_controls.guardrails
}

output "accounts" {
  value = module.accounts
}

output "global_controls" {
  value = module.control_tower_controls.global_controls
}
