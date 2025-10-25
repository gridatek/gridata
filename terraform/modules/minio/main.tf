resource "helm_release" "minio" {
  name       = "minio"
  repository = "https://charts.min.io/"
  chart      = "minio"
  version    = var.chart_version
  namespace  = var.namespace

  values = [
    templatefile("${path.module}/values.yaml", {
      environment      = var.environment
      replicas         = var.replicas
      storage_class    = var.storage_class
      storage_size     = var.storage_size
      root_user        = var.root_user
      ingress_host     = var.ingress_host
      console_host     = var.console_host
      enable_tls       = var.enable_tls
    })
  ]

  set_sensitive {
    name  = "rootPassword"
    value = var.root_password
  }

  depends_on = [var.namespace_dependency]
}

# Create initial buckets via Kubernetes job
resource "kubernetes_job_v1" "minio_setup" {
  metadata {
    name      = "minio-setup"
    namespace = var.namespace
  }

  spec {
    template {
      metadata {
        labels = {
          app = "minio-setup"
        }
      }

      spec {
        restart_policy = "Never"

        container {
          name  = "mc"
          image = "minio/mc:latest"

          command = ["/bin/sh", "-c"]
          args = [
            <<-EOT
              mc alias set minio http://minio:9000 ${var.root_user} ${var.root_password}
              mc mb --ignore-existing minio/gridata-raw
              mc mb --ignore-existing minio/gridata-staging
              mc mb --ignore-existing minio/gridata-curated
              mc mb --ignore-existing minio/gridata-archive
              mc mb --ignore-existing minio/gridata-checkpoints
              mc ilm import minio/gridata-raw < /config/lifecycle-raw.json
              mc ilm import minio/gridata-archive < /config/lifecycle-archive.json
            EOT
          ]

          env {
            name  = "MC_HOST_minio"
            value = "http://${var.root_user}:${var.root_password}@minio:9000"
          }

          volume_mount {
            name       = "config"
            mount_path = "/config"
          }
        }

        volume {
          name = "config"

          config_map {
            name = kubernetes_config_map_v1.minio_config.metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [helm_release.minio]
}

# Lifecycle policies
resource "kubernetes_config_map_v1" "minio_config" {
  metadata {
    name      = "minio-lifecycle-config"
    namespace = var.namespace
  }

  data = {
    "lifecycle-raw.json" = jsonencode({
      Rules = [
        {
          ID     = "move-to-archive"
          Status = "Enabled"
          Filter = {
            Prefix = ""
          }
          Transition = {
            Days         = 90
            StorageClass = "STANDARD_IA"
          }
        },
        {
          ID     = "delete-old-data"
          Status = "Enabled"
          Filter = {
            Prefix = ""
          }
          Expiration = {
            Days = 365
          }
        }
      ]
    })

    "lifecycle-archive.json" = jsonencode({
      Rules = [
        {
          ID     = "delete-archive"
          Status = "Enabled"
          Filter = {
            Prefix = ""
          }
          Expiration = {
            Days = 730
          }
        }
      ]
    })
  }
}
