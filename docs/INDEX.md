# Gridata Documentation Index

## 📋 Complete File Listing

### Root Documentation
- [README.md](../README.md) - Project homepage
- [CLAUDE.md](../CLAUDE.md) - AI assistant guidance
- [LICENSE](../LICENSE) - MIT License
- [Technical Design](../technical_design_spark_big_data_platform_terraform_vault_min_io_iceberg_airflow.md) - Full technical specification

### Project Overview
- [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md) - Complete project summary
- [RENAME_COMPLETE.md](RENAME_COMPLETE.md) - Glacier → Gridata rename log
- [VERIFICATION_REPORT.txt](VERIFICATION_REPORT.txt) - Project verification

### Getting Started
- [Quick Start Guide](guides/GETTING_STARTED.md) - Run Gridata in 15 minutes
- [Makefile Reference](../Makefile) - Common commands

### Architecture Documentation
- [System Architecture Overview](architecture/overview.md) - High-level design
- [Data Flow Architecture](architecture/data-flow.md) - Pipeline flows
- [Infrastructure Design](architecture/infrastructure.md) - Kubernetes & Terraform (Coming soon)
- [Security Architecture](architecture/security.md) - Security design (Coming soon)

### User Guides
- [Getting Started](guides/GETTING_STARTED.md) - Initial setup
- [Contributing Guide](guides/CONTRIBUTING.md) - How to contribute
- [Local Development](guides/local-development.md) - Docker Compose setup (Coming soon)
- [Deployment Guide](guides/deployment.md) - Production deployment (Coming soon)
- [Troubleshooting](guides/troubleshooting.md) - Common issues (Coming soon)

### API Reference
- [Airflow DAGs](api/airflow-dags.md) - DAG API reference (Coming soon)
- [Spark Jobs](api/spark-jobs.md) - Spark application API (Coming soon)
- [DataHub Recipes](api/datahub-recipes.md) - Metadata ingestion (Coming soon)

### Deployment Documentation
- [Kubernetes](deployment/kubernetes.md) - K8s deployment (Coming soon)
- [Terraform](deployment/terraform.md) - Infrastructure provisioning (Coming soon)
- [Monitoring](deployment/monitoring.md) - Observability setup (Coming soon)

## 📁 Code Documentation

### Terraform Modules
Located in `terraform/modules/`:
- [kubernetes/](../terraform/modules/kubernetes/) - EKS/GKE cluster
- [minio/](../terraform/modules/minio/) - Object storage
- [airflow/](../terraform/modules/airflow/) - Orchestration
- [spark-operator/](../terraform/modules/spark-operator/) - Spark on K8s
- [vault/](../terraform/modules/vault/) - Secrets management
- [datahub/](../terraform/modules/datahub/) - Metadata catalog
- [monitoring/](../terraform/modules/monitoring/) - Observability

### Airflow DAGs
Located in `airflow/dags/`:
- [ecommerce_orders_pipeline.py](../airflow/dags/ecommerce_orders_pipeline.py) - Order processing
- [ecommerce_customer_360.py](../airflow/dags/ecommerce_customer_360.py) - Customer analytics

### Spark Jobs
Located in `spark-jobs/src/`:
- [process_orders.py](../spark-jobs/src/process_orders.py) - Order transformation
- [customer_360.py](../spark-jobs/src/customer_360.py) - Customer 360 view

### DataHub Recipes
Located in `storage/ingestion/`:
- [iceberg_ingestion.yml](../storage/ingestion/iceberg_ingestion.yml) - Iceberg metadata
- [airflow_ingestion.yml](../storage/ingestion/airflow_ingestion.yml) - Airflow lineage
- [s3_ingestion.yml](../storage/ingestion/s3_ingestion.yml) - MinIO catalog

### Data Schemas
Located in `schemas/avro/`:
- [orders.json](../schemas/avro/orders.json) - Order schema (Avro)
- [customers.json](../schemas/avro/customers.json) - Customer schema (Avro)

### Scripts
Located in `scripts/`:
- [setup-local-env.sh](../scripts/setup-local-env.sh) - Local environment setup
- [deploy-dev.sh](../scripts/deploy-dev.sh) - Development deployment

## 🔍 Finding Information

### By Role

**Data Engineers**
1. [System Architecture](architecture/overview.md)
2. [Data Flow](architecture/data-flow.md)
3. [Airflow DAGs](../airflow/dags/)
4. [Spark Jobs](../spark-jobs/src/)

**DevOps Engineers**
1. [Infrastructure Design](architecture/infrastructure.md)
2. [Kubernetes Deployment](deployment/kubernetes.md)
3. [Terraform Modules](../terraform/modules/)
4. [Monitoring Setup](deployment/monitoring.md)

**Developers**
1. [Getting Started](guides/GETTING_STARTED.md)
2. [Contributing Guide](guides/CONTRIBUTING.md)
3. [Local Development](guides/local-development.md)
4. [API Reference](api/)

**Data Analysts**
1. [Project Summary](PROJECT_SUMMARY.md)
2. [Data Flow](architecture/data-flow.md)
3. [Sample Data](../schemas/samples/)

## 📚 External Resources

### Technology Documentation
- [Apache Airflow](https://airflow.apache.org/docs/)
- [Apache Spark](https://spark.apache.org/docs/latest/)
- [Apache Iceberg](https://iceberg.apache.org/docs/latest/)
- [DataHub](https://datahubproject.io/docs/)
- [MinIO](https://min.io/docs/minio/linux/index.html)
- [HashiCorp Vault](https://developer.hashicorp.com/vault/docs)
- [Kubernetes](https://kubernetes.io/docs/)
- [Terraform](https://developer.hashicorp.com/terraform/docs)

### Community
- [GitHub Repository](https://github.com/your-org/gridata)
- [Issues](https://github.com/your-org/gridata/issues)
- [Discussions](https://github.com/your-org/gridata/discussions)

---

**Documentation Version**: 1.0
**Last Updated**: October 2024
**Maintained By**: Gridata Team
