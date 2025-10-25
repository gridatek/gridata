resource "helm_release" "airflow" {
  name       = "airflow"
  repository = "https://airflow.apache.org"
  chart      = "airflow"
  version    = var.chart_version
  namespace  = var.namespace

  values = [
    templatefile("${path.module}/values.yaml", {
      environment        = var.environment
      executor          = var.executor
      scheduler_replicas = var.scheduler_replicas
      webserver_replicas = var.webserver_replicas
      worker_replicas    = var.worker_replicas
      storage_class      = var.storage_class
      fernet_key        = var.fernet_key
      webserver_secret  = var.webserver_secret
      ingress_host      = var.ingress_host
      enable_tls        = var.enable_tls
      minio_endpoint    = var.minio_endpoint
      minio_access_key  = var.minio_access_key
      minio_secret_key  = var.minio_secret_key
      vault_addr        = var.vault_addr
      datahub_gms_url   = var.datahub_gms_url
    })
  ]

  set_sensitive {
    name  = "fernetKey"
    value = var.fernet_key
  }

  set_sensitive {
    name  = "webserverSecretKey"
    value = var.webserver_secret
  }

  depends_on = [var.namespace_dependency]
}

# Airflow connections via Kubernetes secrets
resource "kubernetes_secret_v1" "airflow_connections" {
  metadata {
    name      = "airflow-connections"
    namespace = var.namespace
  }

  data = {
    AIRFLOW_CONN_MINIO_DEFAULT = base64encode(
      "s3://${var.minio_access_key}:${var.minio_secret_key}@?host=${var.minio_endpoint}&schema=http"
    )

    AIRFLOW_CONN_SPARK_DEFAULT = base64encode(
      "spark://spark-master:7077"
    )

    AIRFLOW_CONN_DATAHUB_REST_DEFAULT = base64encode(
      "datahub-rest://${var.datahub_gms_url}"
    )

    AIRFLOW_CONN_POSTGRES_METADATA = base64encode(
      "postgresql://airflow:airflow@postgres:5432/airflow"
    )
  }

  type = "Opaque"
}

# Git-sync for DAGs
resource "kubernetes_secret_v1" "git_sync" {
  count = var.git_sync_repo != "" ? 1 : 0

  metadata {
    name      = "airflow-git-sync"
    namespace = var.namespace
  }

  data = {
    GIT_SYNC_REPO     = base64encode(var.git_sync_repo)
    GIT_SYNC_BRANCH   = base64encode(var.git_sync_branch)
    GIT_SYNC_DEPTH    = base64encode("1")
    GIT_SYNC_WAIT     = base64encode("60")
    GIT_SYNC_USERNAME = base64encode(var.git_sync_username)
    GIT_SYNC_PASSWORD = base64encode(var.git_sync_password)
  }

  type = "Opaque"
}
