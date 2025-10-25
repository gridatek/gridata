variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
  default     = "airflow"
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "chart_version" {
  description = "Airflow Helm chart version"
  type        = string
  default     = "1.11.0"
}

variable "executor" {
  description = "Airflow executor type"
  type        = string
  default     = "KubernetesExecutor"
}

variable "scheduler_replicas" {
  description = "Number of scheduler replicas"
  type        = number
  default     = 2
}

variable "webserver_replicas" {
  description = "Number of webserver replicas"
  type        = number
  default     = 2
}

variable "worker_replicas" {
  description = "Number of worker replicas (for CeleryExecutor)"
  type        = number
  default     = 3
}

variable "storage_class" {
  description = "Storage class for persistent volumes"
  type        = string
  default     = "fast-ssd"
}

variable "fernet_key" {
  description = "Fernet key for encrypting secrets"
  type        = string
  sensitive   = true
}

variable "webserver_secret" {
  description = "Webserver secret key"
  type        = string
  sensitive   = true
}

variable "ingress_host" {
  description = "Ingress hostname for Airflow webserver"
  type        = string
}

variable "enable_tls" {
  description = "Enable TLS for Airflow"
  type        = bool
  default     = true
}

variable "minio_endpoint" {
  description = "MinIO endpoint"
  type        = string
}

variable "minio_access_key" {
  description = "MinIO access key"
  type        = string
  sensitive   = true
}

variable "minio_secret_key" {
  description = "MinIO secret key"
  type        = string
  sensitive   = true
}

variable "vault_addr" {
  description = "Vault address"
  type        = string
}

variable "datahub_gms_url" {
  description = "DataHub GMS URL"
  type        = string
  default     = "http://datahub-gms.datahub.svc.cluster.local:8080"
}

variable "git_sync_repo" {
  description = "Git repository for DAGs sync"
  type        = string
  default     = ""
}

variable "git_sync_branch" {
  description = "Git branch for DAGs sync"
  type        = string
  default     = "main"
}

variable "git_sync_username" {
  description = "Git username"
  type        = string
  default     = ""
  sensitive   = true
}

variable "git_sync_password" {
  description = "Git password/token"
  type        = string
  default     = ""
  sensitive   = true
}

variable "namespace_dependency" {
  description = "Namespace resource dependency"
  type        = any
  default     = null
}
