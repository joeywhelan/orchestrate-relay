variable "project_name" {
  description = "Name of the Elastic Serverless Elasticsearch project"
  type        = string
  default     = "orchestrate-relay"
}

variable "region" {
  description = "Elastic Cloud region ID"
  type        = string
  default     = "aws-eu-west-2"
}
