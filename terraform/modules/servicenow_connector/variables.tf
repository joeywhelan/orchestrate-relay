variable "project_name" {
  type    = string
  default = "orchestrate-relay"
}

variable "elasticsearch_endpoint" {
  type = string
}

variable "elasticsearch_username" {
  type      = string
  sensitive = true
}

variable "elasticsearch_password" {
  type      = string
  sensitive = true
}

variable "servicenow_url" {
  type = string
}

variable "servicenow_username" {
  type = string
}

variable "servicenow_password" {
  type      = string
  sensitive = true
}

variable "connector_id" {
  type    = string
  default = "servicenow-demo-connector"
}

variable "connector_display_name" {
  type    = string
  default = "Content synced from ServiceNow"
}

variable "index_name" {
  type    = string
  default = "search-servicenow-demo"
}
