variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "cluster_version" {
  description = "Kubernetes cluster version"
  type        = string
}

variable "enable_cluster_autoscaler" {
  description = "Enable cluster autoscaler"
  type        = bool
}

variable "airflow_replicas" {
  description = "Number of Airflow webserver/scheduler replicas"
  type        = number
}

variable "airflow_worker_replicas" {
  description = "Number of Airflow worker replicas"
  type        = number
}

variable "spark_driver_memory" {
  description = "Spark driver memory"
  type        = string
}

variable "spark_executor_memory" {
  description = "Spark executor memory"
  type        = string
}

variable "spark_executor_instances" {
  description = "Number of Spark executor instances"
  type        = number
}

variable "minio_replicas" {
  description = "Number of MinIO replicas"
  type        = number
}

variable "minio_storage_size" {
  description = "MinIO storage size per node"
  type        = string
}

variable "datahub_replicas" {
  description = "Number of DataHub replicas"
  type        = number
}

variable "enable_monitoring" {
  description = "Enable Prometheus/Grafana monitoring"
  type        = bool
}

variable "prometheus_retention" {
  description = "Prometheus data retention period"
  type        = string
}
