variable "project_name" {
  type    = string
  default = "orchestrate-relay"
}

variable "elasticsearch_endpoint" {
  type = string
}

variable "connector_id" {
  type = string
}

variable "connector_api_key" {
  type      = string
  sensitive = true
}

variable "subnet_ids" {
  type = list(string)
}

variable "connector_sg_id" {
  type = string
}

variable "division" {
  type = string
}

variable "org" {
  type = string
}

variable "team" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.small"
}

variable "connector_image" {
  type    = string
  default = "docker.elastic.co/integrations/elastic-connectors:9.4.3"
}
