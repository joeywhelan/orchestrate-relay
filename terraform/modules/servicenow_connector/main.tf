terraform {
  required_providers {
    elasticstack = {
      source  = "elastic/elasticstack"
      version = "~> 0.14"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

resource "null_resource" "connector_registration" {
  triggers = {
    connector_id = var.connector_id
  }

  depends_on = [elasticstack_elasticsearch_index.servicenow]

  provisioner "local-exec" {
    command = <<-EOT
      curl -sf -X PUT "${var.elasticsearch_endpoint}/_connector/${var.connector_id}" \
        -u "${var.elasticsearch_username}:${var.elasticsearch_password}" \
        -H "Content-Type: application/json" \
        -d '{"index_name":"${var.index_name}","name":"${var.connector_display_name}","service_type":"servicenow"}'
    EOT
  }
}

resource "null_resource" "connector_configuration" {
  triggers = {
    connector_id        = var.connector_id
    servicenow_url      = var.servicenow_url
    servicenow_username = var.servicenow_username
    services            = "Incident,Knowledge,Change Request,Requested Item"
  }

  # The connector service registers the configuration schema on its first
  # check-in from EC2; values are rejected until then, so retry up to 10 min.
  provisioner "local-exec" {
    command = <<-EOT
      for i in $(seq 1 40); do
        curl -sf -X PUT "${var.elasticsearch_endpoint}/_connector/${var.connector_id}/_configuration" \
          -u "${var.elasticsearch_username}:${var.elasticsearch_password}" \
          -H "Content-Type: application/json" \
          -d '{
            "values": {
              "url": "${var.servicenow_url}",
              "username": "${var.servicenow_username}",
              "password": "${var.servicenow_password}",
              "services": "Incident,Knowledge,Change Request,Requested Item"
            }
          }' && exit 0
        echo "waiting for connector schema registration ($i/40)"
        sleep 15
      done
      echo "timed out waiting for connector schema registration"
      exit 1
    EOT
  }

  depends_on = [null_resource.connector_registration]
}


resource "elasticstack_elasticsearch_index" "servicenow" {
  name                = var.index_name
  deletion_protection = false

  mappings = jsonencode({
    properties = {
      short_description = {
        type         = "semantic_text"
        inference_id = ".jina-embeddings-v5-text-small"
      }
      description = {
        type         = "semantic_text"
        inference_id = ".jina-embeddings-v5-text-small"
      }
      text = {
        type         = "semantic_text"
        inference_id = ".jina-embeddings-v5-text-small"
      }
    }
  })
}

resource "elasticstack_elasticsearch_security_api_key" "connector" {
  name = "${var.project_name}-connector"

  role_descriptors = jsonencode({
    connector = {
      cluster = ["monitor", "manage_connector"]
      indices = [{
        names      = [var.index_name, ".elastic-connectors*"]
        privileges = ["all"]
      }]
    }
  })

  depends_on = [null_resource.connector_registration]
}
