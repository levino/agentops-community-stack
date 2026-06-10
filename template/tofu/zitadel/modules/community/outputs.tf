output "org_id" {
  value       = zitadel_org.community.id
  description = "ID of the community organization."
}

output "org_name" {
  value       = zitadel_org.community.name
  description = "Name of the community organization."
}

output "project_ids" {
  value       = { for name, p in zitadel_project.association : name => p.id }
  description = "Project ID per association."
}
