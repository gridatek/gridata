output "cluster_endpoint" {
  description = "Kubernetes cluster endpoint"
  value       = module.kubernetes.cluster_endpoint
  sensitive   = true
}

output "cluster_name" {
  description = "Kubernetes cluster name"
  value       = module.kubernetes.cluster_name
}

output "airflow_url" {
  description = "Airflow webserver URL"
  value       = "https://airflow.${var.domain_name}"
}

output "datahub_url" {
  description = "DataHub frontend URL"
  value       = var.enable_datahub ? "https://datahub.${var.domain_name}" : null
}

output "grafana_url" {
  description = "Grafana dashboard URL"
  value       = var.enable_monitoring ? "https://grafana.${var.domain_name}" : null
}

output "minio_console_url" {
  description = "MinIO console URL"
  value       = "https://minio-console.${var.domain_name}"
}

output "vault_url" {
  description = "Vault UI URL"
  value       = "https://vault.${var.domain_name}"
}
