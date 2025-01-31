variable "ou_names_to_arns" {
  description = "A map of OU name to the ARN of the OU"
  type        = map(string)
}

variable "guardrails" {
  type = list(object({
    control_name   = string
    is_global_type = optional(bool, true)
    ou_name        = string
    parameters     = optional(map(string), {})
  }))
  description = "Configuration of AWS Control Tower Guardrails for the whole organization"
}
