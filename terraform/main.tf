terraform {
  required_version = ">= 1.6"

  required_providers {
    ec = {
      source  = "elastic/ec"
      version = "~> 0.12"
    }
    elasticstack = {
      source  = "elastic/elasticstack"
      version = "~> 0.14"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

provider "ec" {
  apikey = var.elastic_cloud_api_key
}

# Organization policy requires these tags on AWS resources.
locals {
  # plantimestamp() (not timestamp()) — default_tags require plan-time-known values
  keep_until = formatdate("YYYY-MM-DD", timeadd(plantimestamp(), "24h"))
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      division     = var.division
      org          = var.org
      team         = var.team
      project      = var.project_name
      "keep-until" = local.keep_until
    }
  }
}

module "elastic_serverless" {
  source       = "./modules/elastic_serverless"
  project_name = var.project_name
  region       = var.elastic_region
}

provider "elasticstack" {
  elasticsearch {
    endpoints = [module.elastic_serverless.elasticsearch_endpoint]
    username  = module.elastic_serverless.username
    password  = module.elastic_serverless.password
  }
}

module "aws_network" {
  source       = "./modules/aws_network"
  project_name = var.project_name
}

module "servicenow_connector" {
  source                 = "./modules/servicenow_connector"
  project_name           = var.project_name
  elasticsearch_endpoint = module.elastic_serverless.elasticsearch_endpoint
  elasticsearch_username = module.elastic_serverless.username
  elasticsearch_password = module.elastic_serverless.password
  servicenow_url         = var.servicenow_url
  servicenow_username    = var.servicenow_username
  servicenow_password    = var.servicenow_password
}

module "connector_agent" {
  source                 = "./modules/connector_agent"
  project_name           = var.project_name
  division               = var.division
  org                    = var.org
  team                   = var.team
  elasticsearch_endpoint = module.elastic_serverless.elasticsearch_endpoint
  connector_id           = module.servicenow_connector.connector_id
  connector_api_key      = module.servicenow_connector.connector_api_key
  subnet_ids             = module.aws_network.subnet_ids
  connector_sg_id        = module.aws_network.connector_sg_id
}
