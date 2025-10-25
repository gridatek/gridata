# Technical Design — Gridata

**Project summary**

Gridata is an enterprise-ready, cloud-native big data platform where raw files are placed into a drop folder and Airflow automatically orchestrates end-to-end processing: ingestion into MinIO (S3-compatible), table management with Apache Iceberg, processing with Apache Spark, and production of curated outputs. Infrastructure is provisioned with Terraform and secrets/keys are managed by HashiCorp Vault. The system supports both batch and streaming, is secure by design, supports schema evolution, and is built for reproducible deployments and observability.

---

## Table of contents
1. Goals & Non-goals
2. High-level architecture
3. Component responsibilities
4. Kubernetes and Helm deployment strategy
5. Data flow (step-by-step)
6. Airflow DAGs and orchestration patterns
7. Spark job design and best practices
8. Iceberg table design and partitioning strategy
9. MinIO layout and lifecycle policies
10. Terraform structure and modules
11. Vault design: secrets, policies, and rotation
12. DataHub: metadata management and data governance
13. CI/CD and testing strategy
14. Monitoring, logging, and alerting
15. Security & governance
16. Cost considerations
17. Deployment & operations runbook
18. MVP backlog & roadmap
19. Appendix: config snippets & sample DAG outline

---

## 1. Goals & Non-goals
**Goals**
- Automate: Detect new files in a folder and run a reproducible data pipeline via Airflow.
- Reliability: Exactly-once or idempotent processing where possible; ensure fault tolerance.
- Schema evolution: Support changing schemas via Iceberg.
- Security: Centralized secret management with Vault and least-privilege access patterns.
- Reproducible infrastructure via Terraform.
- Support both batch and streaming ingestion patterns.

**Non-goals (for initial phase)**
- Implementing full multi-region geo-replication.
- Real-time low-latency APIs (focus on micro-batch/near-real-time first).
- Advanced ML feature stores (focus on curated data tables first).

---

## 2. High-level architecture

(Visualize: Ingestion folder -> Airflow -> MinIO -> Iceberg metastore -> Spark -> Curated outputs -> Consumers)

Components:
- **Kubernetes**: Container orchestration platform hosting all services. Provides scheduling, auto-scaling, self-healing, and resource management.
- **Helm**: Package manager for Kubernetes. All platform components deployed as Helm charts for version control and reproducibility.
- **Airflow**: Orchestrator. Detects file drops, triggers ingestion and Spark jobs, manages retries and lineage metadata.
- **MinIO**: S3-compatible object store for raw and processed data.
- **Apache Iceberg**: Table format for data stored in MinIO, enabling time-travel, snapshots, and schema evolution.
- **Apache Spark**: Processing engine for batch/stream processing (use Spark Structured Streaming + Delta-like semantics via Iceberg).
- **DataHub**: Metadata platform for data discovery, lineage tracking, data governance, and cataloging datasets across the platform.
- **Terraform**: Provision infra (Kubernetes cluster, networking, node pools, IAM, storage classes, load balancers).
- **HashiCorp Vault**: Secrets, dynamic DB creds (if needed), encryption keys.
- **CI/CD**: GitHub Actions/GitLab CI/other pipelines to validate Terraform, run unit tests, build Spark images, deploy Airflow DAGs.
- **Monitoring**: Prometheus + Grafana, ELK/EFK for logging, and Airflow metrics.

---

## 3. Component responsibilities
- **Drop folder**: Could be a shared NFS, an SFTP endpoint, or MinIO prefix monitored by a connector. Acts as the source for new data arrivals.
- **Airflow**:
  - Sensors/watchers for new files (FileSensor for local/NFS, S3KeySensor for MinIO S3 API, or custom operator).
  - DAGs for ingestion, validation, Spark job submission, Iceberg commits, and publishing outputs.
  - Integration with Vault for secrets and MinIO credentials.
  - Submit Spark jobs via KubernetesExecutor / Spark-on-Kubernetes operator / Livy / Spark-submit on Yarn (choose based on infra).
- **MinIO**:
  - Buckets/prefixes: `raw/`, `staging/`, `curated/`, `archive/`.
  - Lifecycle rules for TTL and transition.
- **Iceberg**:
  - Tables reside on MinIO with metadata stored either in a Hive metastore (MySQL/Postgres) or a catalog (AWS Glue-like or Iceberg's REST catalog).
  - Use Iceberg's snapshotting for safe commits and rollbacks.
- **Spark**:
  - Structured Streaming for near-real-time.
  - Batch jobs for historical reprocess.
  - Writes go to Iceberg tables.
- **Vault**:
  - Store MinIO access keys, DB credentials, Kafka credentials, and any API keys.
  - Use AppRole (or Kubernetes auth) for Airflow & Spark to obtain secrets dynamically.
- **DataHub**:
  - Central metadata repository for all datasets, pipelines, and schemas.
  - Ingest metadata from Iceberg, Airflow, Spark, and MinIO.
  - Provide search and discovery UI for data consumers.
  - Track column-level lineage from source files through transformations to curated tables.
  - Manage data ownership, tags, glossary terms, and data quality metadata.

---

## 4. Kubernetes and Helm deployment strategy

**Why Kubernetes + Helm**
- **Kubernetes** provides container orchestration, enabling portability across cloud providers (AWS EKS, GCP GKE, Azure AKS) or on-premises.
- **Helm** packages applications as reusable charts, enabling versioned deployments, easy rollbacks, and environment-specific configurations.
- All Gridata components (Airflow, Spark, MinIO, DataHub, Vault, monitoring) run as containerized workloads on Kubernetes.

**Kubernetes cluster architecture**
- **Node pools**:
  - **System pool**: Dedicated nodes for K8s system components (kube-system, ingress controllers, cert-manager).
  - **Airflow pool**: Nodes for Airflow scheduler, webserver, and workers (KubernetesExecutor spawns ephemeral pods).
  - **Spark pool**: Auto-scaling node pool for Spark executors (driver and executors as K8s pods).
  - **Data services pool**: Nodes for MinIO, DataHub backend services (MySQL, Elasticsearch, Kafka).
  - **Monitoring pool**: Nodes for Prometheus, Grafana, Loki, Alertmanager.

- **Namespaces**:
  - `airflow`: Airflow scheduler, webserver, workers, DAG processors.
  - `spark-operator`: Spark operator and Spark application pods.
  - `minio`: MinIO instances and buckets.
  - `datahub`: DataHub GMS, frontend, Kafka, Elasticsearch, MySQL.
  - `vault`: Vault cluster and unsealing mechanisms.
  - `monitoring`: Prometheus, Grafana, Alertmanager, logging stack.
  - `ingress`: Ingress controllers (NGINX/Traefik) and cert-manager for TLS.

**Helm chart strategy**
Use official Helm charts where available; customize via `values.yaml` files:
- **Airflow**: `apache-airflow/airflow` (official chart)
  - Configure KubernetesExecutor for dynamic pod spawning
  - Integrate with Vault via init containers for secret injection
  - Enable DataHub lineage plugin
  - Configure persistent volumes for logs and DAGs

- **Spark Operator**: `spark-operator/spark-operator`
  - Deploy Spark operator for managing SparkApplication CRDs
  - Configure RBAC for Spark drivers/executors
  - Set up Spark history server for job monitoring

- **MinIO**: `minio/minio` or `bitnami/minio`
  - Deploy in distributed mode (4+ nodes) for HA
  - Configure persistent volumes (SSD storage class for performance)
  - Enable TLS and server-side encryption
  - Set up lifecycle policies via MinIO admin

- **DataHub**: `datahub/datahub`
  - Deploy GMS (backend), frontend, Kafka, Elasticsearch, MySQL
  - Configure SSO (OIDC/SAML)
  - Integrate with Vault for database credentials
  - Set up ingress with TLS

- **Vault**: `hashicorp/vault`
  - Deploy in HA mode with Raft storage backend
  - Configure Kubernetes auth method
  - Auto-unseal using cloud KMS (AWS KMS, GCP KMS, Azure Key Vault)
  - Set up AppRole for non-K8s services

- **Monitoring**: `prometheus-community/kube-prometheus-stack`
  - Deploys Prometheus, Grafana, Alertmanager, and node exporters
  - Scrape metrics from all Gridata components
  - Configure custom dashboards for Airflow, Spark, MinIO, DataHub

**Helm values management**
Organize values files by environment:
```
helm/
  ├─ charts/           # Custom charts (if any)
  ├─ values/
  │   ├─ dev/
  │   │   ├─ airflow-values.yaml
  │   │   ├─ spark-operator-values.yaml
  │   │   ├─ minio-values.yaml
  │   │   ├─ datahub-values.yaml
  │   │   └─ vault-values.yaml
  │   ├─ staging/
  │   └─ prod/
  └─ scripts/
      ├─ deploy-all.sh
      └─ rollback.sh
```

Use Terraform `helm_release` resources to deploy charts:
```hcl
resource "helm_release" "airflow" {
  name       = "airflow"
  repository = "https://airflow.apache.org"
  chart      = "airflow"
  version    = "1.14.0"
  namespace  = "airflow"

  values = [
    file("${path.module}/values/${var.environment}/airflow-values.yaml")
  ]

  set_sensitive {
    name  = "fernetKey"
    value = vault_generic_secret.airflow_fernet.data["key"]
  }
}
```

**Kubernetes resource quotas and limits**
- Set resource requests/limits for all pods to ensure QoS
- Use PodDisruptionBudgets (PDB) for HA services (Airflow scheduler, MinIO, DataHub GMS)
- Configure HorizontalPodAutoscaler (HPA) for Airflow workers and Spark executors
- Use NetworkPolicies to restrict inter-namespace traffic

**Storage strategy**
- **Persistent Volumes**: Use cloud-native storage classes (AWS EBS gp3, GCP PD-SSD, Azure Premium SSD)
- **MinIO storage**: Dedicated storage class with high IOPS for object store
- **Airflow logs/DAGs**: ReadWriteMany PVC for shared logs (EFS, GCS Filestore, Azure Files)
- **DataHub metadata**: High-performance storage for MySQL and Elasticsearch
- **Backup strategy**: Velero for K8s cluster backups, periodic snapshots of PVs

**Ingress and networking**
- Deploy NGINX Ingress Controller or Traefik in `ingress` namespace
- Configure DNS records pointing to load balancer:
  - `airflow.Gridata.company.com` → Airflow webserver
  - `datahub.Gridata.company.com` → DataHub frontend
  - `minio-api.Gridata.company.com` → MinIO API
  - `minio-console.Gridata.company.com` → MinIO console
  - `vault.Gridata.company.com` → Vault UI
  - `grafana.Gridata.company.com` → Grafana dashboards

- Use cert-manager with Let's Encrypt or corporate CA for automatic TLS certificate management
- Implement OAuth2 Proxy for SSO across services

**Deployment workflow**
1. Terraform provisions K8s cluster, node pools, networking, IAM roles
2. Terraform deploys base services: Vault, cert-manager, ingress controller
3. Vault is initialized and unsealed; secrets are populated
4. Terraform deploys platform services via Helm: MinIO, Airflow, Spark operator, DataHub
5. Terraform deploys monitoring stack: Prometheus, Grafana, Loki
6. Airflow DAGs are deployed via Git-sync sidecar or CI/CD pipeline
7. DataHub ingestion recipes are scheduled as Airflow DAGs

**Upgrade strategy**
- Use Helm chart versioning for controlled upgrades
- Test upgrades in dev/staging before prod
- Use `helm diff` plugin to preview changes
- Implement blue/green deployments for critical services (Airflow, DataHub)
- Maintain rollback plan (previous Helm release revision)

**High availability and disaster recovery**
- Multi-AZ deployment for K8s control plane and node pools
- MinIO in distributed mode with erasure coding for data durability
- Airflow with multiple schedulers (HA mode with `scheduler_replicas: 2+`)
- DataHub with replicated MySQL and Elasticsearch clusters
- Vault in HA mode with Raft consensus
- Regular backups of Vault data, DataHub metadata, and Airflow metadata DB
- Documented disaster recovery runbook with RTO/RPO targets

---

## 5. Data flow (step-by-step)
1. **Drop**: Producer drops `file.csv` (or parquet/json) into a designated folder or `minio://incoming/tenantX/2025-10-25/`.
2. **Detect**: Airflow sensor detects the new file (S3KeySensor or a MinIO event trigger to an SQS/Kafka topic which Airflow consumes).
3. **Validate**: Airflow runs lightweight validation (schema check, checksum, virus scan) in a short task; on failure, move file to `raw/rejected/` and alert.
4. **Ingest**: Move/copy file to `raw/` bucket/prefix in MinIO (if not already there) and create a staging record.
5. **Register**: For structured formats, create or update Iceberg staging table metadata (or place under staging prefix for Spark to pick up).
6. **Process**: Trigger Spark job (batch or structured streaming micro-batch) to read from `raw/`, clean, enrich (lookup calls, joins), and write into Iceberg `staging` or `curated` table using atomic Iceberg commits.
7. **Quality checks**: After write, run data quality checks (row counts, null thresholds, distribution checks). If checks fail, trigger rollback or quarantine snapshot.
8. **Publish**: If quality checks pass, Airflow tags the dataset as `published`, moves output to `curated/` and registers dataset metadata in DataHub (schema, lineage, ownership, tags).
9. **Notify**: Trigger downstream notifications (webhooks, message bus) and make data available for consumers (BI, ML training, APIs). DataHub provides discovery interface for consumers to find and understand datasets.

---

## 5. Airflow DAGs and orchestration patterns
**DAGs to create (examples)**
- `file_watch_ingest`: sensor -> validate -> ingest -> trigger `process_and_publish`.
- `process_and_publish`: start Spark job -> wait for completion -> run quality checks -> publish.
- `historical_backfill`: parametrized DAG for replaying historical data over a date range.
- `schema_evolution_migration`: handles Iceberg schema changes and backfills.

**Operators & execution**
- Use `KubernetesPodOperator` or submit via `spark-submit` to a Spark-on-K8s cluster. Alternatively use `SparkKubernetesOperator` (custom) or Livy operator.
- Implement clear task-level retries and use idempotent tasks (e.g., use `if not exists` or snapshot ids for writes).
- Use XComs minimally; prefer metadata store for dataset state.

**Sensor choice**
- Prefer event-driven (MinIO notifications -> Kafka/SQS -> Airflow trigger) for scale; only use long-polling sensors for small-scale PoCs.

---

## 6. Spark job design and best practices
- Use **Spark Structured Streaming** where near-real-time behavior is required; use micro-batches writing to Iceberg.
- Job packaging: Build Docker images for Spark jobs or use pre-built jars; store artifacts in private registry.
- Resource sizing: Tune executors, cores, and memory based on data volume; enable dynamic allocation.
- Data serialization: Prefer Parquet/ORC for columnar storage; use Parquet with Iceberg.
- Checkpointing: For streaming use stable checkpointing locations in MinIO and manage retention.
- Idempotency: Write to Iceberg using `write().to(table)` with proper `overwrite` or `append` semantics and transaction-aware commits.
- Side outputs: For rejects/quarantined rows write to `raw/rejected/` with provenance metadata.

---

## 7. Iceberg table design and partitioning strategy
- Use Iceberg to manage table schema and partitioning.
- Table layout:
  - Database/namespace per domain (e.g., `sales`, `analytics`).
  - Table names e.g., `sales.transactions_v1`.
- Partitioning: Prefer partitioning by date (`dt`) and possibly hashed bucket on high-card columns for evenly distributed files.
- Compaction and optimization:
  - Schedule periodic compaction/optimization jobs (rewrite data files, remove small files).
  - Use Iceberg `rewrite_data_files` and `rewrite_manifests` utilities.
- Time travel & rollback: Keep snapshots for a retention window to allow rollback.

---

## 8. MinIO layout and lifecycle policies
**Bucket structure**
- `company-data-raw` — `/domain/source/date/...`
- `company-data-staging` — intermediate files
- `company-data-curated` — final Iceberg-backed data
- `company-data-archive` — older snapshots and backups

**Policies**
- Lifecycle rules to move older raw files to `archive/` after X days and to delete after Y days.
- Enforce server-side encryption (SSE) and TLS for MinIO access.

---

## 9. Terraform structure and modules
**Repo layout** (example)
```
terraform/
  ├─ modules/
  │   ├─ minio/
  │   ├─ airflow/
  │   ├─ spark_cluster/
  │   ├─ vault/
  │   ├─ datahub/
  │   └─ monitoring/
  ├─ envs/
  │   ├─ prod/
  │   └─ dev/
  └─ main.tf
```

**Module responsibilities**
- `minio`: deploy MinIO (helm chart on k8s or managed object store), buckets, policies.
- `airflow`: deploy Airflow with executor type (KubernetesExecutor recommended), connections configured to use Vault for secrets, DataHub lineage plugin enabled.
- `spark_cluster`: provision Spark resources (K8s cluster + Spark operator or EMR/Dataproc if using cloud managed).
- `vault`: deploy Vault cluster with auto-unseal (KMS) and configure AppRoles.
- `datahub`: deploy DataHub (GMS, frontend, Kafka, Elasticsearch, MySQL), configure ingestion sources, SSO integration.
- `monitoring`: Prometheus, Grafana, Alertmanager, and logging pipeline.

**State strategy**
- Use remote state (Terraform Cloud, S3 + DynamoDB lock, or a supported backend).
- Keep separate workspaces for `dev`, `staging`, `prod`.

---

## 10. Vault design: secrets, policies, and rotation
- Auth methods: Kubernetes auth for pods, AppRole for external services.
- Secrets layout (logical paths):
  - `secret/data/minio/<env>/<service>`
  - `secret/data/spark/<env>/<service>`
  - `secret/data/db/<env>/<service>`
- Policies & least privilege: Create fine-grained policies per service role.
- Rotation: Use dynamic secrets for DBs where possible; schedule periodic rotation for static keys.
- Encryption keys: Optionally store or generate envelope keys in Vault to encrypt objects written to MinIO.

---

## 11. DataHub: metadata management and data governance

**Purpose**
DataHub serves as the central metadata catalog and governance layer for Gridata, enabling:
- **Data discovery**: Search for datasets, pipelines, schemas, and columns across the platform.
- **Lineage tracking**: Visualize end-to-end data flow from source files → Spark transformations → Iceberg tables → downstream consumers.
- **Data governance**: Manage ownership, stewardship, data classification (PII/sensitive), glossary terms, and compliance tags.
- **Data quality visibility**: Surface quality check results, profiling stats, and data freshness metrics.
- **Schema evolution tracking**: Monitor schema changes over time for Iceberg tables.

**Architecture integration**
- DataHub runs as containerized services (GMS backend, frontend, Kafka, Elasticsearch, MySQL/Postgres for metadata storage).
- Deploy via Helm chart on Kubernetes alongside other platform components.
- Integrate with Vault for database credentials and API tokens.

**Metadata ingestion sources**
1. **Iceberg tables**: Use DataHub's Iceberg ingestion source to auto-discover tables, schemas, partitions, and snapshot history.
2. **Airflow**: Deploy DataHub's Airflow plugin/lineage backend to capture DAG structure, task dependencies, and dataset lineage from Airflow operations.
3. **Spark jobs**: Instrument Spark jobs with DataHub's Spark lineage listener to capture read/write operations and column-level transformations.
4. **MinIO**: Custom ingestion to catalog buckets, prefixes, and object metadata (via S3 API or MinIO event notifications).

**Ingestion patterns**
- **Scheduled ingestion**: Run DataHub ingestion recipes via cron or Airflow DAGs (daily/hourly) to sync metadata.
- **Real-time lineage**: Use DataHub's OpenLineage integration or custom emit events from Airflow tasks and Spark jobs on completion.
- **Schema registry**: Optionally integrate schema registries (Confluent Schema Registry for Kafka topics) if adding streaming sources.

**DataHub features to leverage**
- **Business glossary**: Define business terms and link to technical datasets (e.g., "Customer Lifetime Value" → `analytics.customer_ltv` table).
- **Data ownership**: Assign owners and stewards to datasets with LDAP/AD integration or manual assignment.
- **Tags and domains**: Organize datasets by domain (Sales, Marketing, Finance) and apply tags (PII, GDPR, experimental).
- **Data quality integration**: Push Great Expectations or custom quality check results to DataHub as assertions.
- **Documentation**: Enrich datasets with README-style documentation, field descriptions, and usage examples.

**Access control**
- DataHub supports policies for view/edit permissions on metadata.
- Integrate with corporate SSO (OIDC/SAML) for authentication.
- Use Vault to store DataHub's GMS API tokens and database credentials.

**Lineage example workflow**
1. Airflow DAG `file_watch_ingest` runs; DataHub captures:
   - Input: `minio://company-data-raw/sales/2025-10-25/transactions.parquet`
   - Transformation: `airflow.file_watch_ingest.validate_file` task
   - Output: `staging.sales.transactions_raw` (Iceberg table)
2. Spark job processes data; DataHub captures:
   - Input: `staging.sales.transactions_raw`
   - Transformation: `spark_job.clean_and_enrich` with column mappings
   - Output: `curated.sales.transactions_v1` (Iceberg table)
3. BI tool queries `curated.sales.transactions_v1`; lineage shows full path from raw file → staging → curated → consumption.

**Terraform module for DataHub**
```hcl
module "datahub" {
  source = "./modules/datahub"

  namespace           = "datahub"
  helm_chart_version  = "0.4.x"

  # Backend storage
  mysql_host          = module.rds.endpoint
  mysql_credentials   = vault_generic_secret.datahub_db.data

  # Elasticsearch for search
  elasticsearch_host  = module.elasticsearch.endpoint

  # Kafka for metadata change events
  kafka_bootstrap     = module.kafka.bootstrap_servers

  # SSO configuration
  oidc_enabled        = true
  oidc_provider_url   = var.oidc_provider

  # Ingress
  ingress_enabled     = true
  ingress_host        = "datahub.Gridata.company.com"
  tls_enabled         = true
}
```

**Ingestion recipe example (Iceberg)**
```yaml
# datahub_ingestion_iceberg.yml
source:
  type: iceberg
  config:
    catalog:
      type: rest
      uri: http://iceberg-catalog:8181

    # MinIO/S3 connection
    s3:
      endpoint: https://minio.Gridata.internal
      access_key_id: ${VAULT_MINIO_ACCESS_KEY}
      secret_access_key: ${VAULT_MINIO_SECRET_KEY}

    # Tables to ingest
    table_pattern:
      allow:
        - "sales.*"
        - "analytics.*"
      deny:
        - "*.temp_*"

sink:
  type: datahub-rest
  config:
    server: http://datahub-gms:8080
    token: ${VAULT_DATAHUB_TOKEN}
```

**Best practices**
- Run DataHub ingestion as Airflow DAGs for consistency with platform orchestration.
- Use DataHub's Impact Analysis to understand downstream effects before schema changes.
- Regularly review and clean up stale metadata (archived tables, deprecated pipelines).
- Emit custom events for critical business metrics (data freshness SLAs, row counts).
- Integrate DataHub search into internal wikis/portals as the "data portal" for self-service analytics.

---

## 13. CI/CD and testing strategy

**Local development environment**
Enable developers to run Gridata locally for fast feedback and testing:

1. **Minikube/Kind/k3d**: Lightweight local Kubernetes cluster
   ```bash
   # Start local K8s cluster
   minikube start --cpus=4 --memory=8192 --disk-size=50g
   # Or use kind
   kind create cluster --config kind-config.yaml
   ```

2. **Docker Compose alternative**: For non-K8s local development
   ```yaml
   # docker-compose.local.yml
   services:
     minio:
       image: minio/minio
       ports: ["9000:9000", "9001:9001"]
       environment:
         MINIO_ROOT_USER: minioadmin
         MINIO_ROOT_PASSWORD: minioadmin
       command: server /data --console-address ":9001"

     postgres:
       image: postgres:14
       environment:
         POSTGRES_USER: airflow
         POSTGRES_PASSWORD: airflow
         POSTGRES_DB: airflow

     airflow-webserver:
       image: apache/airflow:2.7.0
       ports: ["8080:8080"]
       environment:
         AIRFLOW__CORE__EXECUTOR: LocalExecutor
         AIRFLOW__DATABASE__SQL_ALCHEMY_CONN: postgresql+psycopg2://airflow:airflow@postgres/airflow
       depends_on: [postgres, minio]

     spark-master:
       image: bitnami/spark:3.5
       ports: ["8081:8080", "7077:7077"]
       environment:
         SPARK_MODE: master

     datahub-gms:
       image: linkedin/datahub-gms:latest
       ports: ["8080:8080"]
       depends_on: [postgres, elasticsearch, kafka]
   ```

3. **Tilt for hot-reload development**: Automate local K8s deployment with live updates
   ```python
   # Tiltfile
   k8s_yaml(helm(
     'helm/charts/airflow',
     values=['helm/values/dev/airflow-values.yaml']
   ))

   docker_build('Gridata/spark-jobs', './spark-jobs')
   k8s_resource('airflow-webserver', port_forwards='8080:8080')
   ```

4. **LocalStack for AWS services**: Mock S3, SQS, SNS for AWS-specific integrations
   ```bash
   docker run -d -p 4566:4566 localstack/localstack
   ```

**Testing pyramid**

1. **Unit tests**:
   - **Airflow DAGs**: Test DAG structure, task dependencies, retries
     ```python
     # tests/dags/test_file_watch_ingest.py
     def test_dag_structure():
         dag = DagBag().get_dag('file_watch_ingest')
         assert len(dag.tasks) == 4
         assert 'validate' in dag.task_ids
     ```

   - **Spark jobs**: Test transformations with small datasets
     ```python
     # tests/spark/test_clean_and_enrich.py
     def test_cleaning_logic(spark_session):
         input_df = spark_session.createDataFrame([...])
         output_df = clean_and_enrich(input_df)
         assert output_df.count() == expected_count
     ```

   - **Terraform modules**: Unit tests with `terraform validate` and `tflint`
     ```bash
     terraform -chdir=modules/minio validate
     tflint --module modules/minio
     ```

2. **Integration tests**:
   - **End-to-end DAG runs**: Deploy to local/dev K8s and trigger DAG with test data
   - **Spark integration**: Submit Spark jobs to local cluster, validate output in MinIO
   - **DataHub ingestion**: Run ingestion recipes against local Iceberg tables

3. **Contract tests**:
   - **Schema validation**: Ensure Iceberg table schemas match expectations
   - **API contracts**: Validate DataHub API responses with schema definitions

4. **Smoke tests**:
   - **Post-deployment**: Check service health endpoints after deployment
   ```bash
   curl https://airflow.Gridata.dev/health
   curl https://datahub.Gridata.dev/health
   ```

**CI/CD pipeline architecture**

```
┌─────────────┐
│ Git Push    │
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────────┐
│ CI Stage 1: Validate & Test         │
├─────────────────────────────────────┤
│ • Terraform fmt/validate/tflint     │
│ • Airflow DAG syntax/structure tests│
│ • Spark unit tests (pytest)         │
│ • Docker image builds               │
│ • Security scans (checkov, trivy)   │
└──────┬──────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────┐
│ CI Stage 2: Integration Tests (Dev) │
├─────────────────────────────────────┤
│ • Deploy to ephemeral K8s namespace │
│ • Run end-to-end DAG tests          │
│ • Validate Spark job outputs        │
│ • DataHub metadata ingestion test   │
│ • Cleanup ephemeral resources       │
└──────┬──────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────┐
│ CD Stage 1: Deploy to Staging       │
├─────────────────────────────────────┤
│ • Terraform plan (require approval) │
│ • Terraform apply to staging        │
│ • Helm upgrade staging releases     │
│ • Run smoke tests                   │
└──────┬──────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────┐
│ CD Stage 2: Deploy to Production    │
├─────────────────────────────────────┤
│ • Manual approval required          │
│ • Terraform plan (require approval) │
│ • Blue/green or canary deployment   │
│ • Helm upgrade prod releases        │
│ • Post-deployment validation        │
│ • Rollback on failure               │
└─────────────────────────────────────┘
```

**GitHub Actions example**
```yaml
# .github/workflows/ci.yml
name: Gridata CI/CD

on:
  push:
    branches: [main, develop]
  pull_request:

jobs:
  validate-terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: hashicorp/setup-terraform@v2
      - run: terraform fmt -check -recursive
      - run: terraform -chdir=terraform validate
      - uses: terraform-linters/setup-tflint@v3
      - run: tflint --recursive

  test-airflow-dags:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      - run: pip install -r airflow/requirements-dev.txt
      - run: pytest airflow/tests/

  test-spark-jobs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-python@v4
      - run: pip install pyspark pytest
      - run: pytest spark-jobs/tests/

  security-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: bridgecrewio/checkov-action@master
        with:
          directory: terraform/
          framework: terraform

  integration-test:
    needs: [validate-terraform, test-airflow-dags, test-spark-jobs]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: helm/kind-action@v1
      - run: |
          kubectl create namespace Gridata-ci
          helm install airflow apache-airflow/airflow -n Gridata-ci -f helm/values/ci/airflow-values.yaml
          # Run integration tests
          pytest integration-tests/ --namespace=Gridata-ci
          # Cleanup
          kubectl delete namespace Gridata-ci

  deploy-staging:
    if: github.ref == 'refs/heads/develop'
    needs: integration-test
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - uses: actions/checkout@v3
      - uses: hashicorp/setup-terraform@v2
      - run: |
          cd terraform/envs/staging
          terraform init
          terraform plan -out=tfplan
          terraform apply tfplan

  deploy-production:
    if: github.ref == 'refs/heads/main'
    needs: integration-test
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v3
      - uses: hashicorp/setup-terraform@v2
      - run: |
          cd terraform/envs/prod
          terraform init
          terraform plan -out=tfplan
          # Requires manual approval in GitHub
          terraform apply tfplan
```

**Testing best practices**
- Run tests in isolated K8s namespaces (ephemeral environments)
- Use test data fixtures that mirror production structure but with small volumes
- Mock external dependencies (APIs, third-party services) in unit tests
- Maintain test coverage targets: 80%+ for critical paths
- Run DAG validation on every commit to catch syntax errors early
- Use pre-commit hooks for Terraform formatting and DAG linting
- Implement contract tests for Iceberg schema evolution
- Run chaos engineering tests in staging (pod failures, network partitions)

---

## 14. Monitoring, logging, and alerting
- **Metrics**: Airflow task durations/failures, Spark job metrics (executor usage, GC, shuffle), MinIO ops per second, Iceberg compaction stats, DataHub ingestion lag and search query performance.
- **Logs**: Centralize logs with EFK stack (Elasticsearch/Fluentd/Kibana) or Loki + Grafana.
- **Alerts**: Airflow task failures, repeated Spark job failures, Vault unseal or auth issues, MinIO storage thresholds, DataHub ingestion failures or metadata staleness.
- **Dashboards**: Build out operational dashboards in Grafana for cluster health and job-level dashboards for data teams. Use DataHub dashboards for data quality and lineage visibility.

---

## 13. Security & governance
- TLS for all traffic, mTLS between components if possible.
- IAM: least privilege for services; short-lived credentials.
- Network: use private subnets where possible; restrict access with security groups/firewalls.
- Data governance: capture lineage in DataHub from Airflow and Spark; track dataset owners, stewards, SLAs, and compliance tags.
- PII handling: classify sensitive fields and apply masking/encryption at rest.

---

## 14. Cost considerations
- Choose appropriate compute sizes; use spot/preemptible nodes for non-urgent processing.
- Retention policies on MinIO to save storage costs.
- Use autoscaling for Spark worker pools.
- Consider managed cloud services (e.g., EMR, Dataproc) if operational cost of self-managing K8s + Spark is high.

---

## 15. Deployment & operations runbook
**On new file arrival - quick runbook**
1. Check Airflow DAG `file_watch_ingest` status.
2. Inspect sensor logs to confirm detection.
3. If ingestion fails, check validation task logs; move file to `raw/rejected/` if necessary and notify owner.
4. If Spark job fails, check Spark driver/executor logs and resubmit via DAG backfill after fix.

**Emergency rollback**
- Use Iceberg snapshot rollback to revert to a previous snapshot ID for a specific table.

---

## 16. MVP backlog & roadmap
**MVP (4–8 weeks)**
- Terraform modules for MinIO + Airflow + Spark cluster (minimal).
- Vault with a basic AppRole/Kubernetes auth and one secret path for MinIO creds.
- Airflow DAG: detect local/minio file -> validate -> run Spark batch job -> write Iceberg table -> quality checks -> publish.
- Basic monitoring (Prometheus + Grafana) and logging.

**Phase 2 (8–12 weeks)**
- Deploy DataHub with Iceberg and Airflow metadata ingestion.
- Add streaming ingestion (Structured Streaming + MinIO/Kafka).
- Advanced CI/CD and policy-as-code.
- Compaction/optimization jobs for Iceberg.
- Implement Spark lineage tracking to DataHub.

**Phase 3 (12+ weeks)**
- DataHub governance features: business glossary, data quality integration, impact analysis.
- RBAC for datasets via DataHub policies.
- Multi-region replication.
- Advanced data quality framework (Great Expectations + DataHub).

---

## 17. Appendix: config snippets & sample DAG outline
**Sample Airflow DAG outline (pseudocode)**
```python
with DAG('file_watch_ingest', ...) as dag:
    wait_for_file = S3KeySensor(bucket='company-data-raw', key='incoming/{{ ds }}/', ...)
    validate = PythonOperator(task_id='validate_file', python_callable=validate_file)
    ingest = PythonOperator(task_id='move_to_raw', python_callable=copy_to_raw)
    trigger_process = TriggerDagRunOperator(task_id='start_process', trigger_dag_id='process_and_publish')

    wait_for_file >> validate >> ingest >> trigger_process
```

**Sample Terraform module inputs**
```hcl
module "minio" {
  source = "./modules/minio"
  bucket_names = ["company-data-raw", "company-data-curated"]
  tls_enabled = true
}
```

**Iceberg write (Spark pseudocode)**
```scala
spark.read.format("parquet").load("s3a://company-data-raw/path")
  .transform(cleaning)
  .writeTo("catalog.db.table").append()
```

---

# Closing notes
This document provides a practical, deployable design that balances operational complexity with enterprise needs. If you'd like, I can:
- Turn any single section into a detailed implementation playbook (e.g., Terraform module for MinIO + Vault),
- Produce concrete Airflow DAG code and Spark job templates,
- Generate a prioritized sprint backlog for the MVP.

Tell me which section you'd like implemented first.

