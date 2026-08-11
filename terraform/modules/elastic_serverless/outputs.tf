output "elasticsearch_endpoint" {
  value = ec_elasticsearch_project.this.endpoints.elasticsearch
}

output "username" {
  value     = ec_elasticsearch_project.this.credentials.username
  sensitive = true
}

output "password" {
  value     = ec_elasticsearch_project.this.credentials.password
  sensitive = true
}

output "cloud_id" {
  value = ec_elasticsearch_project.this.cloud_id
}

output "project_id" {
  value = ec_elasticsearch_project.this.id
}

output "kibana_endpoint" {
  value = ec_elasticsearch_project.this.endpoints.kibana
}
