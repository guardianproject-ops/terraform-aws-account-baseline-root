data "aws_region" "current" {}

locals {
  # this file is fetched from https://docs.aws.amazon.com/controltower/latest/controlreference/all-global-identifiers.html
  # last update: 2025-01-22
  global_controls = jsondecode(file("${path.module}/controls.json"))
}

resource "aws_controltower_control" "guardrails" {
  for_each           = { for c in var.guardrails : "${c.ou_name}/${c.control_name}" => c }
  control_identifier = each.value.is_global_type ? "arn:aws:controlcatalog:::control/${local.global_controls[each.value.control_name]}" : "arn:aws:controltower:${data.aws_region.current.name}::control/${each.value.control_name}"
  target_identifier  = var.ou_names_to_arns[each.value.ou_name]
  dynamic "parameters" {
    for_each = each.value.parameters
    content {
      key   = parameters.key
      value = parameters.value
    }
  }
}

output "global_controls" {
  value       = local.global_controls
  description = "A map of name => global id, of the global controls in Control Tower"
}

output "guardrails" {
  value       = aws_controltower_control.guardrails
  description = "The applied AWS Control Tower Guardrails"
}
