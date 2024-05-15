output "proxy_url" {
  description = "DNS name for the lb that fronts the read replicas"
  value       = aws_lb.read_replica.dns_name
}