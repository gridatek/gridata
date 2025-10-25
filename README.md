# Gridata - Enterprise Big Data Platform

> Enterprise-ready, cloud-native big data platform built on Apache Spark, Apache Iceberg, MinIO, Airflow, Terraform, and HashiCorp Vault.

[![CI/CD](https://github.com/your-org/Gridata/workflows/Gridata%20CI/CD/badge.svg)](https://github.com/your-org/Gridata/actions)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## Overview

Gridata automates end-to-end data processing from raw file ingestion through to curated outputs. The platform is designed for enterprise use with built-in governance, security, and observability.

### Key Features

- **Event-driven orchestration** - Airflow DAGs automatically triggered by file arrivals
- **Schema evolution** - Apache Iceberg provides ACID transactions and time-travel capabilities
- **Metadata governance** - DataHub for data discovery, lineage, and compliance
- **Infrastructure as Code** - Full Terraform deployment with Helm charts
- **Security by design** - HashiCorp Vault for secrets, TLS everywhere
- **Cloud-portable** - Runs on AWS EKS, GCP GKE, Azure AKS, or on-premises Kubernetes

## Architecture

```
Drop Folder → Airflow → MinIO (S3) → Spark → Iceberg Tables → DataHub → Consumers
                ↓
            Vault (Secrets)
                ↓
         Prometheus/Grafana (Monitoring)
```

### Technology Stack

| Component | Technology | Purpose |
|-----------|------------|---------|
| **Orchestration** | Apache Airflow | Workflow management and scheduling |
| **Processing** | Apache Spark | Distributed data processing |
| **Storage** | MinIO | S3-compatible object storage |
| **Table Format** | Apache Iceberg | ACID transactions, schema evolution |
| **Metadata** | DataHub | Data catalog and lineage |
| **Secrets** | HashiCorp Vault | Secrets management |
| **Infrastructure** | Terraform + Helm | Infrastructure as Code |
| **Monitoring** | Prometheus + Grafana | Metrics and dashboards |

## Quick Start

### Prerequisites

- Docker & Docker Compose
- Kubernetes cluster (for production) or Minikube/Kind (for local)
- Terraform >= 1.5.0
- Helm >= 3.0
- AWS CLI (if deploying to AWS)

### Local Development

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-org/Gridata.git
   cd Gridata
   ```

2. **Start local environment with Docker Compose**
   ```bash
   docker-compose up -d
   ```

3. **Access services**
   - Airflow: http://localhost:8080 (admin/admin)
   - MinIO Console: http://localhost:9001 (minioadmin/minioadmin123)
   - Spark Master: http://localhost:8081

4. **Generate sample e-commerce data**
   ```bash
   cd data/samples
   pip install faker pandas pyarrow
   python generate_sample_data.py
   ```

5. **Upload sample data to MinIO**
   ```bash
   mc alias set local http://localhost:9000 minioadmin minioadmin123
   mc cp data/samples/orders.jsonl local/Gridata-raw/raw/ecommerce/orders/2024-01-01/
   ```

6. **Trigger Airflow DAG**
   ```bash
   # Access Airflow UI and enable the ecommerce_orders_pipeline DAG
   ```

### Production Deployment

1. **Configure AWS credentials**
   ```bash
   export AWS_PROFILE=your-profile
   ```

2. **Initialize Terraform**
   ```bash
   cd terraform/envs/prod
   terraform init
   ```

3. **Review and apply infrastructure**
   ```bash
   terraform plan
   terraform apply
   ```

4. **Access deployed services**
   ```bash
   # Get service URLs
   terraform output
   ```

## Project Structure

```
Gridata/
├── terraform/              # Infrastructure as Code
│   ├── modules/           # Reusable Terraform modules
│   │   ├── kubernetes/    # EKS/GKE cluster
│   │   ├── minio/         # Object storage
│   │   ├── airflow/       # Workflow orchestration
│   │   ├── spark-operator/# Spark on K8s
│   │   ├── vault/         # Secrets management
│   │   ├── datahub/       # Metadata catalog
│   │   └── monitoring/    # Prometheus/Grafana
│   └── envs/              # Environment configs
│       ├── dev/
│       ├── staging/
│       └── prod/
├── helm/                  # Helm chart values
│   └── values/
│       ├── dev/
│       ├── staging/
│       └── prod/
├── airflow/               # Airflow DAGs and plugins
│   ├── dags/
│   │   ├── ecommerce_orders_pipeline.py
│   │   └── ecommerce_customer_360.py
│   ├── plugins/
│   └── tests/
├── spark-jobs/            # Spark application code
│   ├── src/
│   │   ├── process_orders.py
│   │   ├── customer_360.py
│   │   └── quality_checks.py
│   └── tests/
├── data/                  # Data schemas and samples
│   ├── schemas/
│   │   ├── orders.json
│   │   └── customers.json
│   └── samples/
│       └── generate_sample_data.py
├── docker-compose.yml     # Local development stack
├── .github/
│   └── workflows/
│       └── ci.yml         # CI/CD pipeline
└── README.md
```

## E-commerce Use Case

The platform includes a complete e-commerce analytics pipeline:

### Data Sources
- **Orders** - Transaction data with items, payments, shipping
- **Customers** - Demographics and preferences
- **Products** - Catalog with categories and pricing
- **Clickstream** - User behavior and page views

### Pipelines

1. **Order Processing Pipeline** (`ecommerce_orders_pipeline`)
   - Ingests raw orders from MinIO
   - Validates and cleanses data
   - Calculates derived metrics
   - Writes to Iceberg curated layer
   - Publishes metadata to DataHub

2. **Customer 360 Pipeline** (`ecommerce_customer_360`)
   - Joins customer demographics with order history
   - Aggregates clickstream behavior
   - Calculates customer lifetime value (CLV)
   - Segments customers by value and activity
   - Identifies churn risk

### Data Quality
- Row count validation
- Schema compliance checks
- Business rule validation
- Outlier detection
- Rejected records logged to `Gridata-raw/rejected/`

## Development Workflow

### Adding a New Pipeline

1. **Create Airflow DAG**
   ```python
   # airflow/dags/my_new_pipeline.py
   from airflow import DAG
   from datetime import datetime

   dag = DAG(
       'my_new_pipeline',
       start_date=datetime(2024, 1, 1),
       schedule_interval='@daily'
   )
   ```

2. **Create Spark job**
   ```python
   # spark-jobs/src/my_transform.py
   from pyspark.sql import SparkSession

   spark = SparkSession.builder.appName("MyTransform").getOrCreate()
   # Add transformation logic
   ```

3. **Write tests**
   ```python
   # spark-jobs/tests/test_my_transform.py
   def test_transformation():
       # Add unit tests
       pass
   ```

4. **Deploy**
   ```bash
   git add .
   git commit -m "Add new pipeline"
   git push
   # CI/CD pipeline will test and deploy
   ```

### Running Tests

```bash
# Terraform validation
terraform fmt -check -recursive
terraform validate

# Airflow DAG tests
cd airflow
pytest tests/

# Spark job tests
cd spark-jobs
pytest tests/

# Integration tests
docker-compose up -d
pytest integration-tests/
```

## Monitoring and Observability

### Metrics
- Airflow task success/failure rates
- Spark job execution times
- MinIO storage usage
- DataHub metadata freshness

### Dashboards
- Airflow: Built-in UI at `/admin`
- Spark: History server at `/spark-history`
- Grafana: Custom dashboards for platform health
- DataHub: Data lineage and quality dashboards

### Alerts
- Failed DAG runs
- Spark job failures
- Vault seal status
- Storage capacity thresholds

## Security

### Secrets Management
All secrets stored in HashiCorp Vault:
- MinIO access keys
- Database credentials
- API tokens
- Encryption keys

### Access Control
- Kubernetes RBAC for service accounts
- Vault policies for least-privilege access
- DataHub policies for metadata access

### Data Protection
- TLS encryption for all inter-service communication
- Server-side encryption for MinIO objects
- PII classification and masking via DataHub

## Troubleshooting

### Common Issues

**Airflow DAG not triggering**
```bash
# Check S3 sensor
kubectl logs -n airflow <pod-name> -c airflow-worker
# Verify MinIO file path matches sensor key
```

**Spark job failing**
```bash
# Check driver logs
kubectl logs -n spark-operator <spark-driver-pod>
# Verify MinIO credentials
kubectl get secret -n spark-operator spark-s3-creds
```

**DataHub metadata not updating**
```bash
# Check ingestion logs
kubectl logs -n datahub <datahub-actions-pod>
# Manually trigger ingestion
kubectl exec -n datahub <datahub-gms-pod> -- datahub ingest -c /config/recipe.yml
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- **Documentation**: See [CLAUDE.md](CLAUDE.md) and [Technical Design](technical_design_spark_big_data_platform_terraform_vault_min_io_iceberg_airflow.md)
- **Issues**: Report bugs via [GitHub Issues](https://github.com/your-org/Gridata/issues)
- **Discussions**: Join our [Slack community](https://your-org.slack.com/channels/Gridata)

## Roadmap

### Current (MVP)
- ✅ Core infrastructure (Kubernetes, MinIO, Airflow, Spark)
- ✅ Basic e-commerce pipelines
- ✅ Local development environment

### Phase 2 (Q2 2024)
- [ ] DataHub full deployment
- [ ] Streaming ingestion with Kafka
- [ ] Advanced data quality framework
- [ ] Multi-environment CI/CD

### Phase 3 (Q3 2024)
- [ ] ML feature store integration
- [ ] Multi-region replication
- [ ] Advanced RBAC and governance
- [ ] Cost optimization

---

Built with ❤️ by the Gridata Team
