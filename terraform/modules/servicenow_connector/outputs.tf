output "connector_id" {
  value = var.connector_id
}

output "connector_api_key" {
  value     = elasticstack_elasticsearch_security_api_key.connector.encoded
  sensitive = true
}

output "index_name" {
  value = var.index_name
}
