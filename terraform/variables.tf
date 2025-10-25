variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "cluster_version" {
  description = "Kubernetes cluster version"
  type        = string
  default     = "1.28"
}

variable "node_pools" {
  description = "Node pool configurations"
  type = map(object({
    instance_type = string
    min_size      = number
    max_size      = number
    desired_size  = number
  }))

  default = {
    system = {
      instance_type = "t3.medium"
      min_size      = 2
      max_size      = 4
      desired_size  = 2
    }
    airflow = {
      instance_type = "t3.large"
      min_size      = 2
      max_size      = 6
      desired_size  = 2
    }
    spark = {
      instance_type = "r5.xlarge"
      min_size      = 0
      max_size      = 10
      desired_size  = 2
    }
    data_services = {
      instance_type = "r5.large"
      min_size      = 3
      max_size      = 6
      desired_size  = 3
    }
  }
}

variable "enable_datahub" {
  description = "Enable DataHub deployment"
  type        = bool
  default     = true
}

variable "enable_monitoring" {
  description = "Enable monitoring stack"
  type        = bool
  default     = true
}

variable "domain_name" {
  description = "Base domain name for services"
  type        = string
  default     = "gridata.company.com"
}
