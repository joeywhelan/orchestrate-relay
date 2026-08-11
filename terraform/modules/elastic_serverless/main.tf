terraform {
  required_providers {
    ec = {
      source  = "elastic/ec"
      version = "~> 0.12"
    }
  }
}

resource "ec_elasticsearch_project" "this" {
  name          = var.project_name
  region_id     = var.region
  optimized_for = "general_purpose"
}
