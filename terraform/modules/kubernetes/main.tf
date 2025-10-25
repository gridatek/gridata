locals {
  cluster_name = "gridata-${var.environment}"
}

# EKS Cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  cluster_endpoint_public_access  = var.environment == "dev"
  cluster_endpoint_private_access = true

  # Cluster addons
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  # Node groups
  eks_managed_node_groups = {
    system = {
      name = "system-pool"

      instance_types = [var.node_pools["system"].instance_type]

      min_size     = var.node_pools["system"].min_size
      max_size     = var.node_pools["system"].max_size
      desired_size = var.node_pools["system"].desired_size

      labels = {
        role = "system"
      }

      taints = []
    }

    airflow = {
      name = "airflow-pool"

      instance_types = [var.node_pools["airflow"].instance_type]

      min_size     = var.node_pools["airflow"].min_size
      max_size     = var.node_pools["airflow"].max_size
      desired_size = var.node_pools["airflow"].desired_size

      labels = {
        role = "airflow"
      }

      taints = [{
        key    = "dedicated"
        value  = "airflow"
        effect = "NoSchedule"
      }]
    }

    spark = {
      name = "spark-pool"

      instance_types = [var.node_pools["spark"].instance_type]

      min_size     = var.node_pools["spark"].min_size
      max_size     = var.node_pools["spark"].max_size
      desired_size = var.node_pools["spark"].desired_size

      labels = {
        role = "spark"
      }

      taints = [{
        key    = "dedicated"
        value  = "spark"
        effect = "NoSchedule"
      }]
    }

    data_services = {
      name = "data-services-pool"

      instance_types = [var.node_pools["data_services"].instance_type]

      min_size     = var.node_pools["data_services"].min_size
      max_size     = var.node_pools["data_services"].max_size
      desired_size = var.node_pools["data_services"].desired_size

      labels = {
        role = "data-services"
      }

      taints = []
    }
  }

  tags = var.tags
}

# StorageClass for fast SSD storage
resource "kubernetes_storage_class_v1" "fast_ssd" {
  metadata {
    name = "fast-ssd"
  }

  storage_provisioner = "ebs.csi.aws.com"
  volume_binding_mode = "WaitForFirstConsumer"

  parameters = {
    type      = "gp3"
    iops      = "3000"
    throughput = "125"
    encrypted = "true"
  }
}

# Namespaces
resource "kubernetes_namespace_v1" "namespaces" {
  for_each = toset([
    "airflow",
    "spark-operator",
    "minio",
    "datahub",
    "vault",
    "monitoring",
    "ingress"
  ])

  metadata {
    name = each.value

    labels = {
      environment = var.environment
      managed-by  = "terraform"
    }
  }
}
