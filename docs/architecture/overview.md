# Gridata System Architecture

## Overview

Gridata is an enterprise-ready, cloud-native big data platform designed for automated data processing from raw ingestion to curated analytics. This document provides a comprehensive overview of the system architecture.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                       Data Producers                            │
│              (Files, APIs, Streaming Sources)                   │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Ingestion Layer                             │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐                 │
│  │ Drop     │    │  SFTP    │    │  Kafka   │                 │
│  │ Folders  │    │ Gateway  │    │ Topics   │                 │
│  └─────┬────┘    └─────┬────┘    └─────┬────┘                 │
└────────┼───────────────┼───────────────┼──────────────────────┘
         │               │               │
         └───────────────┼───────────────┘
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Storage Layer (MinIO)                         │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐      │
│  │   Raw    │  │ Staging  │  │ Curated  │  │ Archive  │      │
│  │ Bucket   │  │ Bucket   │  │ Bucket   │  │ Bucket   │      │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘      │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│              Orchestration Layer (Airflow)                      │
│  ┌──────────────────────────────────────────────────┐          │
│  │  DAGs: Scheduling, Sensors, Task Management      │          │
│  └──────────────────────────────────────────────────┘          │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│               Processing Layer (Spark)                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐      │
│  │Transform │  │Aggregate │  │  Join    │  │ Enrich   │      │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘      │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│              Table Layer (Apache Iceberg)                       │
│  ┌──────────────────────────────────────────────────┐          │
│  │  ACID Transactions, Schema Evolution, Snapshots  │          │
│  └──────────────────────────────────────────────────┘          │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│            Metadata Layer (DataHub)                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐      │
│  │Discovery │  │ Lineage  │  │Governance│  │ Quality  │      │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘      │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                  Consumption Layer                              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐      │
│  │    BI    │  │    ML    │  │   APIs   │  │ Reports  │      │
│  │  Tools   │  │Notebooks │  │          │  │          │      │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘      │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                   Cross-Cutting Concerns                        │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐      │
│  │  Vault   │  │Monitoring│  │  Logging │  │ Security │      │
│  │ Secrets  │  │Prometheus│  │   EFK    │  │   RBAC   │      │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘      │
└─────────────────────────────────────────────────────────────────┘
```

## Core Components

### 1. Container Orchestration - Kubernetes

**Purpose**: Host all platform services with orchestration, scaling, and self-healing.

**Key Features**:
- Multi-node pool architecture (system, airflow, spark, data services)
- Horizontal Pod Autoscaling (HPA)
- Pod Disruption Budgets (PDB) for HA
- Network policies for security
- Resource quotas and limits

**Namespaces**:
- `airflow` - Workflow orchestration
- `spark-operator` - Spark applications
- `minio` - Object storage
- `datahub` - Metadata catalog
- `vault` - Secrets management
- `monitoring` - Observability stack
- `ingress` - Ingress controllers

### 2. Object Storage - MinIO

**Purpose**: S3-compatible data lake storage.

**Bucket Structure**:
- `gridata-raw/` - Raw incoming data
- `gridata-staging/` - Intermediate processing
- `gridata-curated/` - Final analytics-ready data
- `gridata-archive/` - Long-term retention
- `gridata-checkpoints/` - Spark streaming checkpoints

**Features**:
- Distributed mode (4+ nodes) for HA
- Server-side encryption (SSE)
- Lifecycle policies for data retention
- Versioning and replication
- S3 API compatibility

### 3. Workflow Orchestration - Apache Airflow

**Purpose**: Schedule and manage data pipelines.

**Architecture**:
- Scheduler (2+ replicas for HA)
- Webserver (2+ replicas)
- KubernetesExecutor for dynamic scaling
- PostgreSQL metadata database
- Git-sync for DAG deployment

**Key Capabilities**:
- Event-driven triggers (S3KeySensor)
- Retry logic with exponential backoff
- Task dependencies (DAG structure)
- XCom for metadata passing
- Integration with Vault for secrets

### 4. Processing Engine - Apache Spark

**Purpose**: Distributed data transformation and analytics.

**Deployment**:
- Spark Operator on Kubernetes
- Dynamic executor allocation
- SparkApplication CRDs
- History server for job analysis

**Job Types**:
- Batch processing (historical data)
- Structured Streaming (near-real-time)
- Iceberg writes (ACID transactions)

### 5. Table Format - Apache Iceberg

**Purpose**: ACID-compliant data lake tables with schema evolution.

**Features**:
- Snapshot isolation
- Time-travel queries
- Schema evolution (add/remove/rename columns)
- Hidden partitioning
- Metadata tracking

**Table Organization**:
```
gridata.{namespace}.{table}
├── gridata.ecommerce.orders
├── gridata.ecommerce.customers
├── gridata.analytics.customer_360
└── gridata.analytics.sales_metrics
```

### 6. Metadata Catalog - DataHub

**Purpose**: Centralized metadata management and governance.

**Components**:
- GMS (Backend API)
- Frontend (React UI)
- Kafka (Metadata events)
- Elasticsearch (Search)
- MySQL (Metadata storage)

**Capabilities**:
- Data discovery & search
- Lineage visualization
- Ownership & stewardship
- Data quality tracking
- Compliance tagging

### 7. Secrets Management - HashiCorp Vault

**Purpose**: Centralized secrets and encryption key management.

**Features**:
- Dynamic secrets generation
- Secret rotation
- Kubernetes auth integration
- AppRole for external services
- Auto-unseal with cloud KMS

**Secret Paths**:
```
secret/data/minio/{env}/{service}
secret/data/spark/{env}/{service}
secret/data/db/{env}/{service}
```

### 8. Monitoring - Prometheus + Grafana

**Purpose**: Metrics collection and visualization.

**Stack**:
- Prometheus - Metrics collection
- Grafana - Dashboards & visualization
- Alertmanager - Alert routing
- Node exporters - Host metrics
- Service monitors - Application metrics

### 9. Infrastructure - Terraform

**Purpose**: Infrastructure as Code for reproducible deployments.

**Module Structure**:
```
modules/
├── kubernetes/    # EKS/GKE cluster
├── minio/         # Object storage
├── airflow/       # Orchestration
├── spark-operator/# Processing
├── vault/         # Secrets
├── datahub/       # Metadata
└── monitoring/    # Observability
```

## Design Principles

### 1. Cloud-Native
- Kubernetes-based deployment
- Container-first architecture
- Cloud-agnostic design
- Horizontal scalability

### 2. Event-Driven
- File arrival triggers processing
- Kafka for event streaming
- Async processing patterns
- Decoupled components

### 3. Immutable Infrastructure
- Infrastructure as Code (Terraform)
- Immutable container images
- GitOps for deployments
- Version-controlled configs

### 4. Security by Design
- Secrets in Vault (never in code)
- TLS everywhere
- Least-privilege access (RBAC)
- Network policies
- Audit logging

### 5. Schema Evolution
- Iceberg for backward compatibility
- Versioned schemas
- Migration support
- No breaking changes

### 6. Observability
- Metrics (Prometheus)
- Logs (EFK/Loki)
- Traces (future: OpenTelemetry)
- Dashboards (Grafana)
- Alerts (Alertmanager)

## Data Flow Patterns

### Batch Processing
```
File Drop → S3 Sensor → Validation → Spark Batch → Iceberg Write → Quality Check → Publish
```

### Near-Real-Time Streaming
```
Kafka Topic → Spark Streaming → Micro-batches → Iceberg Append → DataHub Update
```

### Customer 360 (Multi-Source Join)
```
Customers + Orders + Clickstream → Spark Join → Aggregations → Customer 360 Table
```

## Scalability

### Horizontal Scaling
- **Airflow**: Add scheduler/worker replicas
- **Spark**: Dynamic executor allocation
- **MinIO**: Add storage nodes
- **DataHub**: Scale GMS/frontend pods

### Vertical Scaling
- Adjust pod resource requests/limits
- Use node pools with appropriate instance types
- Tune JVM settings for Spark

## High Availability

### Service HA
- Multiple replicas for stateless services
- PodDisruptionBudgets
- Multi-AZ node distribution
- Health checks and readiness probes

### Data HA
- MinIO erasure coding
- Iceberg snapshot retention
- Database replication
- Backup strategies (Velero)

## Security Architecture

### Authentication
- Kubernetes ServiceAccounts
- Vault AppRole/Kubernetes auth
- SSO via OIDC/SAML (DataHub, Airflow)

### Authorization
- Kubernetes RBAC
- Vault policies
- DataHub access policies
- Network policies

### Encryption
- TLS for all inter-service communication
- Server-side encryption (MinIO)
- Secrets encryption (Vault)
- Encrypted backups

## Network Architecture

### Ingress
- NGINX/Traefik ingress controller
- TLS termination (cert-manager)
- OAuth2 proxy for SSO
- Rate limiting

### Service Mesh (Future)
- Istio/Linkerd for mTLS
- Traffic management
- Observability

## Disaster Recovery

### Backup Strategy
- Iceberg snapshot retention (30 days)
- Velero for K8s resource backups
- Database backups (automated)
- Configuration backups (Git)

### Recovery Procedures
- Iceberg table rollback
- Kubernetes resource restore
- Database point-in-time recovery
- Documented runbooks

## Performance Considerations

### Spark Optimization
- Partition pruning
- Predicate pushdown
- Dynamic allocation
- Shuffle optimization
- Broadcast joins

### Iceberg Optimization
- Compaction jobs
- Metadata cleanup
- Partition evolution
- File size management

### Caching
- Spark RDD caching
- Iceberg metadata caching
- DataHub query caching

## Future Enhancements

### Phase 2
- Kafka integration for streaming
- Great Expectations for data quality
- MLflow for ML lifecycle
- Trino for federated queries

### Phase 3
- Multi-region deployment
- Service mesh (Istio)
- Real-time OLAP (Druid)
- Feature store
- Data mesh architecture

## Related Documentation

- [Data Flow](data-flow.md) - Detailed data pipeline flows
- [Infrastructure](infrastructure.md) - Terraform & Kubernetes details
- [Security](security.md) - Security architecture & best practices
- [Deployment Guide](../guides/deployment.md) - Production deployment

---

**Last Updated**: October 2024
**Version**: 1.0
