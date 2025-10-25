# Gridata Documentation

Welcome to the Gridata documentation! This folder contains comprehensive guides, architecture documentation, and reference materials.

## 📚 Documentation Structure

```
docs/
├── README.md                    # This file - documentation index
├── PROJECT_SUMMARY.md           # Complete project overview
├── architecture/                # Architecture & design docs
│   ├── overview.md             # System architecture overview
│   ├── data-flow.md            # Data flow diagrams
│   ├── infrastructure.md       # Infrastructure design
│   └── security.md             # Security architecture
├── guides/                      # User guides & tutorials
│   ├── GETTING_STARTED.md      # Quick start guide
│   ├── CONTRIBUTING.md         # Contribution guidelines
│   ├── local-development.md    # Local dev setup
│   ├── deployment.md           # Production deployment
│   └── troubleshooting.md      # Common issues & solutions
├── api/                         # API documentation
│   ├── airflow-dags.md         # DAG reference
│   ├── spark-jobs.md           # Spark job reference
│   └── datahub-recipes.md      # DataHub integration
└── deployment/                  # Deployment documentation
    ├── kubernetes.md           # Kubernetes deployment
    ├── terraform.md            # Terraform usage
    └── monitoring.md           # Observability setup
```

## 🚀 Quick Links

### Getting Started
- **[Quick Start](guides/GETTING_STARTED.md)** - Get Gridata running in 15 minutes
- **[Project Summary](PROJECT_SUMMARY.md)** - Complete project overview
- **[Contributing](guides/CONTRIBUTING.md)** - How to contribute

### Architecture
- **[System Architecture](architecture/overview.md)** - High-level design
- **[Data Flow](architecture/data-flow.md)** - Data pipeline architecture
- **[Infrastructure](architecture/infrastructure.md)** - Kubernetes & Terraform setup
- **[Security](architecture/security.md)** - Security design & best practices

### Guides
- **[Local Development](guides/local-development.md)** - Docker Compose setup
- **[Deployment Guide](guides/deployment.md)** - Deploy to AWS/GCP/Azure
- **[Troubleshooting](guides/troubleshooting.md)** - Common issues & fixes

### API Reference
- **[Airflow DAGs](api/airflow-dags.md)** - DAG reference & customization
- **[Spark Jobs](api/spark-jobs.md)** - Spark application API
- **[DataHub Recipes](api/datahub-recipes.md)** - Metadata ingestion

### Deployment
- **[Kubernetes](deployment/kubernetes.md)** - K8s deployment details
- **[Terraform](deployment/terraform.md)** - Infrastructure provisioning
- **[Monitoring](deployment/monitoring.md)** - Prometheus & Grafana setup

## 📖 Core Documentation

### Root Level Docs
Located in the project root:
- **[README.md](../README.md)** - Project homepage
- **[CLAUDE.md](../CLAUDE.md)** - AI assistant guidance
- **[LICENSE](../LICENSE)** - MIT License
- **[Technical Design](../technical_design_spark_big_data_platform_terraform_vault_min_io_iceberg_airflow.md)** - Detailed technical specification

## 🎯 Common Tasks

### For New Users
1. Read [Getting Started](guides/GETTING_STARTED.md)
2. Review [Project Summary](PROJECT_SUMMARY.md)
3. Follow [Local Development](guides/local-development.md)

### For Developers
1. Read [Contributing Guide](guides/CONTRIBUTING.md)
2. Review [System Architecture](architecture/overview.md)
3. Check [API Reference](api/airflow-dags.md)

### For DevOps
1. Review [Infrastructure Design](architecture/infrastructure.md)
2. Follow [Deployment Guide](guides/deployment.md)
3. Setup [Monitoring](deployment/monitoring.md)

## 🔍 Finding Information

### By Topic

**Installation & Setup**
- [Getting Started](guides/GETTING_STARTED.md)
- [Local Development](guides/local-development.md)
- [Deployment Guide](guides/deployment.md)

**Architecture & Design**
- [System Architecture](architecture/overview.md)
- [Data Flow](architecture/data-flow.md)
- [Infrastructure](architecture/infrastructure.md)

**Development**
- [Contributing](guides/CONTRIBUTING.md)
- [API Reference](api/airflow-dags.md)
- [Spark Jobs](api/spark-jobs.md)

**Operations**
- [Kubernetes](deployment/kubernetes.md)
- [Terraform](deployment/terraform.md)
- [Monitoring](deployment/monitoring.md)
- [Troubleshooting](guides/troubleshooting.md)

## 📝 Documentation Standards

When contributing documentation:

1. **Format**: Use Markdown (.md)
2. **Structure**: Clear headings, code examples, diagrams
3. **Style**: Clear, concise, actionable
4. **Examples**: Include working code snippets
5. **Links**: Internal links to related docs
6. **Updates**: Keep docs in sync with code

## 🤝 Contributing to Docs

Documentation improvements are always welcome! Please see [Contributing Guide](guides/CONTRIBUTING.md) for:
- Documentation style guide
- How to propose changes
- Review process

## 📧 Support

- **Issues**: [GitHub Issues](https://github.com/your-org/gridata/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-org/gridata/discussions)
- **Email**: support@your-org.com

---

**Documentation Version**: 1.0
**Last Updated**: October 2024
**Project**: Gridata Enterprise Big Data Platform
