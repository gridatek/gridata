variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
  default     = "minio"
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "chart_version" {
  description = "MinIO Helm chart version"
  type        = string
  default     = "5.0.14"
}

variable "replicas" {
  description = "Number of MinIO replicas"
  type        = number
  default     = 4
}

variable "storage_class" {
  description = "Storage class for MinIO PVCs"
  type        = string
  default     = "fast-ssd"
}

variable "storage_size" {
  description = "Storage size per MinIO instance"
  type        = string
  default     = "100Gi"
}

variable "root_user" {
  description = "MinIO root username"
  type        = string
  default     = "admin"
}

variable "root_password" {
  description = "MinIO root password"
  type        = string
  sensitive   = true
}

variable "ingress_host" {
  description = "Ingress hostname for MinIO API"
  type        = string
}

variable "console_host" {
  description = "Ingress hostname for MinIO console"
  type        = string
}

variable "enable_tls" {
  description = "Enable TLS for MinIO"
  type        = bool
  default     = true
}

variable "namespace_dependency" {
  description = "Namespace resource dependency"
  type        = any
  default     = null
}
