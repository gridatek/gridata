terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket         = "gridata-terraform-state-prod"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "gridata-terraform-locks"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "prod"
      Project     = "Gridata"
      ManagedBy   = "Terraform"
    }
  }
}

module "gridata" {
  source = "../.."

  environment = "prod"
  aws_region  = var.aws_region

  # Pass all variables from terraform.tfvars
  cluster_version          = var.cluster_version
  enable_cluster_autoscaler = var.enable_cluster_autoscaler
  airflow_replicas         = var.airflow_replicas
  airflow_worker_replicas  = var.airflow_worker_replicas
  spark_driver_memory      = var.spark_driver_memory
  spark_executor_memory    = var.spark_executor_memory
  spark_executor_instances = var.spark_executor_instances
  minio_replicas           = var.minio_replicas
  minio_storage_size       = var.minio_storage_size
  datahub_replicas         = var.datahub_replicas
  enable_monitoring        = var.enable_monitoring
  prometheus_retention     = var.prometheus_retention
}
