variable "elastic_cloud_api_key" {
  description = "Elastic Cloud API key"
  type        = string
  sensitive   = true
}

variable "elastic_region" {
  description = "Elastic Cloud region ID"
  type        = string
  default     = "aws-eu-west-2"
}

variable "project_name" {
  description = "Name applied to the Elastic project and AWS resources"
  type        = string
  default     = "orchestrate-relay"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-2"
}

variable "division" {
  description = "Org-required division tag value"
  type        = string
}

variable "org" {
  description = "Org-required org tag value"
  type        = string
}

variable "team" {
  description = "Org-required team tag value"
  type        = string
}

variable "servicenow_url" {
  description = "ServiceNow PDI instance URL"
  type        = string
}

variable "servicenow_username" {
  description = "ServiceNow username for connector basic auth"
  type        = string
}

variable "servicenow_password" {
  description = "ServiceNow password for connector basic auth"
  type        = string
  sensitive   = true
}

variable "orchestrate_url" {
  description = "IBM Watson Orchestrate instance URL"
  type        = string
}

variable "orchestrate_api_key" {
  description = "IBM Watson Orchestrate API key"
  type        = string
  sensitive   = true
}
