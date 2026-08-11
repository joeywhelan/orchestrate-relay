output "elastic_cloud_api_key" {
  value     = var.elastic_cloud_api_key
  sensitive = true
}

output "cloud_id" {
  value = module.elastic_serverless.cloud_id
}

output "elasticsearch_endpoint" {
  value = module.elastic_serverless.elasticsearch_endpoint
}

output "kibana_endpoint" {
  value = module.elastic_serverless.kibana_endpoint
}

output "elasticsearch_username" {
  value     = module.elastic_serverless.username
  sensitive = true
}

output "elasticsearch_password" {
  value     = module.elastic_serverless.password
  sensitive = true
}

output "connector_id" {
  value = module.servicenow_connector.connector_id
}

output "index_name" {
  value = module.servicenow_connector.index_name
}

output "servicenow_url" {
  value = var.servicenow_url
}

output "servicenow_username" {
  value = var.servicenow_username
}

output "servicenow_password" {
  value     = var.servicenow_password
  sensitive = true
}

output "orchestrate_url" {
  value = var.orchestrate_url
}

output "orchestrate_api_key" {
  value     = var.orchestrate_api_key
  sensitive = true
}
