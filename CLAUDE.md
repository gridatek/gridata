# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Gridata** is an enterprise-ready, cloud-native big data platform built on Apache Spark, Apache Iceberg, MinIO, Airflow, Terraform, and HashiCorp Vault. The platform automates end-to-end data processing from raw file ingestion through to curated outputs.

## Architecture Philosophy

The platform follows these core principles:
- **Event-driven orchestration**: Files dropped into designated folders trigger Airflow DAGs that manage the entire pipeline
- **Immutable infrastructure**: All components provisioned via Terraform with reproducible deployments
- **Security by design**: Centralized secrets management with Vault, least-privilege access, TLS everywhere
- **Schema evolution**: Apache Iceberg provides ACID transactions, time-travel, and schema changes without breaking downstream consumers
- **Idempotent processing**: All operations designed for safe retries and exactly-once semantics

## Key Components & Their Relationships

**Data Flow Chain**:
Drop Folder → Airflow Detection → Validation → MinIO (raw/) → Spark Processing → Iceberg Tables → MinIO (curated/) → Consumers

**Infrastructure Stack**:
- **Kubernetes**: Container orchestration platform hosting all services (Airflow, Spark, MinIO, DataHub, Vault)
- **Helm**: Package manager for deploying and managing Kubernetes applications
- **Airflow**: Orchestrator using sensors to detect files, triggers Spark jobs, manages retries and lineage
- **MinIO**: S3-compatible object storage with buckets: `raw/`, `staging/`, `curated/`, `archive/`
- **Apache Iceberg**: Table format enabling snapshots, rollbacks, and atomic commits
- **Apache Spark**: Processing engine (batch and Structured Streaming) writing to Iceberg tables
- **DataHub**: Metadata platform for data discovery, lineage tracking, and governance
- **Terraform**: Infrastructure provisioning organized as modules per component
- **HashiCorp Vault**: Secrets management using AppRole/Kubernetes auth for dynamic credentials

## DAG Patterns

When working with Airflow DAGs in this platform:

1. **file_watch_ingest**: Sensor → validate → ingest → trigger process_and_publish
2. **process_and_publish**: Start Spark job → wait → quality checks → publish
3. **historical_backfill**: Parameterized for replaying data over date ranges
4. **schema_evolution_migration**: Handles Iceberg schema changes and backfills

Use `KubernetesPodOperator` for Spark job submission. Prefer event-driven triggers (MinIO notifications → Kafka/SQS → Airflow) over long-polling sensors for production scale.

## Spark Job Design Patterns

- Package jobs as Docker images or JARs stored in private registry
- Use Structured Streaming with micro-batches for near-real-time processing
- Write to Iceberg using `.writeTo(table).append()` or `.overwrite()` for atomic commits
- Store checkpoints in MinIO for Structured Streaming jobs
- Write rejected/quarantined records to `raw/rejected/` with provenance metadata
- Tune executors based on data volume; enable dynamic allocation

## Iceberg Table Strategy

- Organize tables by domain namespace (e.g., `sales.transactions_v1`)
- Partition by date (`dt`) and optionally hash-bucket high-cardinality columns
- Schedule periodic compaction using `rewrite_data_files` and `rewrite_manifests`
- Maintain snapshot retention window to enable time-travel and rollback
- Use snapshot IDs for emergency rollbacks in production incidents

## Terraform Module Structure

The infrastructure follows this module organization:
- `modules/kubernetes/`: K8s cluster provisioning (EKS/GKE/AKS or self-managed)
- `modules/minio/`: MinIO Helm deployment, buckets, lifecycle policies, SSE/TLS config
- `modules/airflow/`: Airflow Helm chart with KubernetesExecutor, Vault integration, DataHub lineage plugin
- `modules/spark_cluster/`: Spark operator Helm chart and CRDs for Spark-on-K8s
- `modules/vault/`: Vault Helm deployment with auto-unseal, AppRole configuration
- `modules/datahub/`: DataHub Helm chart (GMS, frontend, Kafka, Elasticsearch, MySQL)
- `modules/monitoring/`: Prometheus, Grafana, Alertmanager Helm charts and logging pipeline
- `envs/`: Separate configurations for dev/staging/prod environments

Use remote state backend (Terraform Cloud, S3+DynamoDB) with separate workspaces per environment.

## Vault Secrets Organization

Secrets are organized by logical paths:
- `secret/data/minio/<env>/<service>`
- `secret/data/spark/<env>/<service>`
- `secret/data/db/<env>/<service>`

Services authenticate via Kubernetes auth (for pods) or AppRole (external services). Implement dynamic secrets for databases and schedule rotation for static keys.

## Security Requirements

- All inter-service traffic uses TLS; prefer mTLS where possible
- Apply least-privilege IAM policies; use short-lived credentials
- Deploy in private subnets with security groups/firewalls
- Classify PII fields and apply masking/encryption at rest
- Capture data lineage in Airflow metadata store

## Operations Runbook

**File Processing Failure**:
1. Check Airflow DAG `file_watch_ingest` status
2. Review sensor logs for detection confirmation
3. Examine validation task logs; move failed files to `raw/rejected/`
4. For Spark failures, check driver/executor logs and resubmit via DAG backfill

**Emergency Rollback**:
Use Iceberg snapshot rollback: identify snapshot ID and revert the affected table using Iceberg's time-travel capabilities.

## DataHub Integration

DataHub serves as the metadata catalog and governance layer:
- **Discovery**: Search across datasets, pipelines, schemas, and columns
- **Lineage**: Visualize data flow from source files → Spark → Iceberg → consumers
- **Governance**: Manage ownership, PII classification, glossary terms, compliance tags

**Metadata ingestion sources**:
- Iceberg tables (auto-discover schemas, partitions, snapshots)
- Airflow DAGs (task dependencies and dataset lineage via plugin)
- Spark jobs (column-level transformations via lineage listener)
- MinIO buckets (custom ingestion for object metadata)

**Best practices**:
- Run DataHub ingestion recipes as Airflow DAGs for consistency
- Use Impact Analysis before schema changes to understand downstream effects
- Emit data quality check results to DataHub as assertions
- Integrate DataHub search into internal portals for self-service discovery

## Local Development and Testing

Gridata supports local development for fast iteration and testing:

**Local environment options**:
- **Minikube/Kind/k3d**: Run full platform on local Kubernetes cluster
- **Docker Compose**: Lightweight alternative for component-level development
- **Tilt**: Hot-reload development with automatic rebuilds on code changes

**CI/CD testing strategy**:
1. **Unit tests**: DAG structure, Spark transformations, Terraform validation
2. **Integration tests**: End-to-end DAG runs in ephemeral K8s namespaces
3. **Security scans**: checkov for Terraform, trivy for container images
4. **Smoke tests**: Post-deployment health checks for all services

**CI pipeline stages**:
- Validate: Terraform fmt/validate, DAG syntax, unit tests
- Integration: Deploy to ephemeral namespace, run E2E tests, cleanup
- Deploy Staging: Terraform plan → apply, Helm upgrades, smoke tests
- Deploy Production: Manual approval, blue/green deployment, validation

All tests run in isolated environments to prevent interference and enable parallel execution.

## Development Phases

**MVP (4–8 weeks)** - Current focus:
- Kubernetes cluster setup via Terraform
- Core Helm deployments: MinIO, Airflow, Spark operator, Vault
- Basic AppRole/Kubernetes auth with MinIO credentials
- End-to-end DAG: file detection → validation → Spark batch → Iceberg write → quality checks → publish
- Prometheus + Grafana monitoring and centralized logging

**Phase 2 (8–12 weeks)**:
- DataHub deployment with Iceberg and Airflow metadata ingestion
- Spark lineage tracking to DataHub
- Streaming ingestion with Structured Streaming + Kafka
- Advanced CI/CD with policy-as-code (tflint, checkov, conftest)
- Iceberg compaction and optimization jobs

**Phase 3 (12+ weeks)**:
- DataHub governance: business glossary, data quality integration, impact analysis
- RBAC for datasets via DataHub policies
- Multi-region replication
- Advanced data quality framework (Great Expectations + DataHub)
