variable "community_name" {
  type        = string
  description = "Name of the community — becomes the ZITADEL organization (the shared identity pool)."
}

variable "associations" {
  type = list(object({
    name  = string
    roles = list(string)
  }))
  description = <<-EOT
    Clubs / subgroups. Each becomes a ZITADEL project with the listed roles.
    Roles end up as claims in tokens; apps authorize on them.
    Keep the structure flat — ZITADEL has no nested groups. Deeper structures
    are modeled as role conventions ("football:board"), not trees.
  EOT
}

variable "managers" {
  type        = map(list(string))
  default     = {}
  description = <<-EOT
    Delegated administration: association name -> list of ZITADEL user IDs
    that become PROJECT_OWNER of that association's project. A project owner
    assigns existing community users to the project's roles in self-service —
    without access to any other association.
  EOT

  validation {
    condition     = alltrue([for k, v in var.managers : contains([for a in var.associations : a.name], k)])
    error_message = "Every key in managers must be the name of an association."
  }
}
