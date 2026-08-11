output "vpc_id" {
  value = data.aws_vpc.default.id
}

output "subnet_ids" {
  value = data.aws_subnets.default.ids
}

output "connector_sg_id" {
  value = aws_security_group.connector.id
}
