# Gridata Data Flow Architecture

## Overview

This document describes the end-to-end data flow through the Gridata platform, from ingestion to consumption.

## E-commerce Order Processing Flow

### Complete Pipeline

```
┌──────────────────────────────────────────────────────────────────┐
│ 1. DATA INGESTION                                                │
│                                                                   │
│  File Drop (CSV/JSON/Parquet)                                   │
│         │                                                         │
│         ▼                                                         │
│  MinIO Raw Bucket (gridata-raw/)                                │
│         │                                                         │
│         └─> Path: raw/ecommerce/orders/YYYY-MM-DD/              │
└──────────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────────────┐
│ 2. DETECTION                                                      │
│                                                                   │
│  Airflow S3KeySensor                                             │
│         │                                                         │
│         ├─> Polling: Every 60 seconds                           │
│         ├─> Timeout: 1 hour                                     │
│         └─> Pattern: orders.parquet                             │
└──────────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────────────┐
│ 3. VALIDATION                                                     │
│                                                                   │
│  PythonOperator (validate_order_file)                           │
│         │                                                         │
│         ├─> Check file exists                                   │
│         ├─> Validate file size (> 0, < 10GB)                   │
│         ├─> Schema validation (optional)                        │
│         └─> Checksum verification                               │
│                                                                   │
│  On Failure: Move to raw/rejected/                              │
└──────────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────────────┐
│ 4. SPARK PROCESSING                                              │
│                                                                   │
│  SparkKubernetesOperator                                         │
│         │                                                         │
│         ├─> Read from gridata-raw                               │
│         ├─> Apply transformations:                              │
│         │   ├─ Parse timestamps                                 │
│         │   ├─ Calculate totals                                 │
│         │   ├─ Categorize orders                                │
│         │   ├─ Handle nulls                                     │
│         │   └─ Add metadata                                     │
│         │                                                         │
│         └─> Write to Iceberg:                                   │
│             ├─ Table: gridata.ecommerce.orders                  │
│             ├─ Format: Parquet                                  │
│             ├─ Partitions: year, month                          │
│             └─ Mode: CreateOrReplace                            │
└──────────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────────────┐
│ 5. DATA QUALITY CHECKS                                           │
│                                                                   │
│  SparkKubernetesOperator (quality_checks)                       │
│         │                                                         │
│         ├─> Row count validation                                │
│         ├─> Null percentage check                               │
│         ├─> Value range validation                              │
│         ├─> Duplicate detection                                 │
│         └─> Business rule validation                            │
│                                                                   │
│  On Failure: Rollback Iceberg snapshot                          │
└──────────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────────────┐
│ 6. METADATA PUBLISHING                                           │
│                                                                   │
│  PythonOperator (publish_to_datahub)                            │
│         │                                                         │
│         ├─> Dataset URN                                         │
│         ├─> Schema metadata                                     │
│         ├─> Ownership info                                      │
│         ├─> Tags (ecommerce, production)                        │
│         └─> Lineage relationships                               │
└──────────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────────────┐
│ 7. DOWNSTREAM TRIGGER                                            │
│                                                                   │
│  SimpleHttpOperator (trigger_analytics)                         │
│         │                                                         │
│         └─> Notify downstream systems                           │
│             ├─ BI refresh                                       │
│             ├─ ML model retraining                              │
│             └─ Report generation                                │
└──────────────────────────────────────────────────────────────────┘
```

## Customer 360 Flow

### Multi-Source Join Pipeline

```
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│  Customers  │  │   Orders    │  │ Clickstream │
│   Table     │  │   Table     │  │   Table     │
└──────┬──────┘  └──────┬──────┘  └──────┬──────┘
       │                │                │
       └────────────────┼────────────────┘
                        │
                        ▼
        ┌───────────────────────────────┐
        │ Spark Join Operations          │
        │                                │
        │ 1. Customer + Order Join       │
        │    ├─ Calculate metrics        │
        │    ├─ RFM analysis            │
        │    └─ Lifetime value          │
        │                                │
        │ 2. Add Clickstream             │
        │    ├─ Page views              │
        │    ├─ Session data            │
        │    └─ Conversion rates        │
        └────────────┬──────────────────┘
                     │
                     ▼
        ┌───────────────────────────────┐
        │ Customer 360 Enrichment        │
        │                                │
        │ ├─ Segmentation               │
        │ │  ├─ VIP                     │
        │ │  ├─ High Value              │
        │ │  ├─ Medium Value            │
        │ │  └─ Low Value               │
        │ │                              │
        │ ├─ Activity Status             │
        │ │  ├─ Active                  │
        │ │  ├─ At Risk                 │
        │ │  ├─ Dormant                 │
        │ │  └─ Churned                 │
        │ │                              │
        │ └─ Churn Risk Score           │
        └────────────┬──────────────────┘
                     │
                     ▼
        ┌───────────────────────────────┐
        │ Write to Iceberg               │
        │                                │
        │ Table: gridata.analytics       │
        │        .customer_360           │
        └───────────────────────────────┘
```

## Data Quality Workflow

### Validation & Remediation

```
┌────────────────┐
│ Incoming Data  │
└───────┬────────┘
        │
        ▼
┌────────────────────────────────────────┐
│ Schema Validation                       │
│ ├─ Column names                         │
│ ├─ Data types                           │
│ └─ Required fields                      │
└───────┬──────────────┬─────────────────┘
        │              │
        │ Valid        │ Invalid
        ▼              ▼
┌────────────┐  ┌──────────────────┐
│ Continue   │  │ Move to rejected/│
└─────┬──────┘  │ Send alert       │
      │         └──────────────────┘
      ▼
┌────────────────────────────────────────┐
│ Business Rules Validation               │
│ ├─ Value ranges                         │
│ ├─ Referential integrity                │
│ └─ Custom business logic                │
└───────┬──────────────┬─────────────────┘
        │              │
        │ Pass         │ Fail
        ▼              ▼
┌────────────┐  ┌──────────────────┐
│ Process    │  │ Quarantine       │
└─────┬──────┘  │ Log issue        │
      │         └──────────────────┘
      ▼
┌────────────────────────────────────────┐
│ Post-Processing Quality Checks          │
│ ├─ Row counts                           │
│ ├─ Null percentages                     │
│ ├─ Statistical profiling                │
│ └─ Outlier detection                    │
└───────┬──────────────┬─────────────────┘
        │              │
        │ Pass         │ Fail
        ▼              ▼
┌────────────┐  ┌──────────────────┐
│ Publish    │  │ Rollback Iceberg │
│ Metadata   │  │ Retry or Alert   │
└────────────┘  └──────────────────┘
```

## Streaming Data Flow (Future)

### Kafka → Spark Streaming → Iceberg

```
Kafka Topics
     │
     ├─> clickstream_events
     ├─> order_updates
     └─> inventory_changes
          │
          ▼
┌────────────────────────────────┐
│ Spark Structured Streaming      │
│                                 │
│ ├─ Micro-batch (10 seconds)   │
│ ├─ Watermarking                │
│ ├─ Stateful operations         │
│ └─ Checkpointing              │
└────────┬───────────────────────┘
         │
         ▼
┌────────────────────────────────┐
│ Iceberg Append                  │
│                                 │
│ ├─ ACID writes                 │
│ ├─ Exactly-once semantics      │
│ └─ Partition management        │
└────────┬───────────────────────┘
         │
         ▼
┌────────────────────────────────┐
│ Real-time Views                 │
│                                 │
│ ├─ Trino/Presto queries       │
│ ├─ BI dashboards               │
│ └─ Alerting                    │
└────────────────────────────────┘
```

## Data Lineage Tracking

### DataHub Lineage Capture

```
┌──────────────────────────────────────────────┐
│ Source: raw/ecommerce/orders/                │
│ Type: File                                    │
└────────────┬─────────────────────────────────┘
             │
             ▼ (read by)
┌──────────────────────────────────────────────┐
│ Job: airflow.ecommerce_orders_pipeline       │
│      .process_orders_spark                   │
│ Type: Spark Application                      │
└────────────┬─────────────────────────────────┘
             │
             ▼ (writes to)
┌──────────────────────────────────────────────┐
│ Table: gridata.ecommerce.orders              │
│ Type: Iceberg Table                          │
└────────────┬─────────────────────────────────┘
             │
             ▼ (consumed by)
┌──────────────────────────────────────────────┐
│ Downstream:                                   │
│ ├─ BI Dashboard (Orders Analysis)           │
│ ├─ Customer 360 Pipeline                    │
│ └─ Revenue Reports                           │
└──────────────────────────────────────────────┘
```

## Error Handling Flow

### Failure Recovery

```
Task Failure
     │
     ├─ Retry (3 attempts with exponential backoff)
     │       │
     │       ├─ Attempt 1: Immediate
     │       ├─ Attempt 2: 5 minutes
     │       └─ Attempt 3: 15 minutes
     │
     └─ Still Failing?
             │
             ├─> Alert (PagerDuty/Email)
             ├─> Log to monitoring
             └─> Move data to rejected/
                      │
                      └─> Manual review
                            │
                            ├─ Fix and replay
                            └─ Or discard
```

## Iceberg Snapshot Management

### Time-Travel & Rollback

```
┌─────────────────────────────────┐
│ Snapshot Timeline                │
│                                  │
│ S1 ──> S2 ──> S3 ──> S4 ──> S5 │
│ Day1  Day2  Day3  Day4  Day5    │
│                   │              │
│                   └──> Bad Data  │
└─────────────────────────────────┘
                    │
                    ▼
        ┌───────────────────────┐
        │ Quality Check Fails   │
        └───────────┬───────────┘
                    │
                    ▼
        ┌───────────────────────┐
        │ Rollback to S3        │
        │                       │
        │ ALTER TABLE ... SET   │
        │ TBLPROPERTIES (       │
        │   'snapshot-id'='S3'  │
        │ )                     │
        └───────────────────────┘
```

## Performance Optimization Flow

### Spark Job Optimization

```
Read Phase
    │
    ├─ Partition Pruning
    │  └─ Read only relevant partitions
    │
    ├─ Predicate Pushdown
    │  └─ Filter at source
    │
    └─ Column Pruning
       └─ Read only required columns
            │
            ▼
Transform Phase
    │
    ├─ Broadcast Joins
    │  └─ Small tables to all executors
    │
    ├─ Repartition
    │  └─ Optimize shuffle operations
    │
    └─ Cache
       └─ Reuse intermediate results
            │
            ▼
Write Phase
    │
    ├─ Coalesce
    │  └─ Optimize file sizes
    │
    ├─ Dynamic Partition Overwrite
    │  └─ Write only changed partitions
    │
    └─ Iceberg ACID Write
       └─ Atomic commit
```

## Monitoring Data Flow

### Observability Pipeline

```
All Services
     │
     ├─> Metrics (Prometheus)
     │   ├─ Airflow task duration
     │   ├─ Spark job metrics
     │   ├─ MinIO throughput
     │   └─ DataHub queries
     │
     ├─> Logs (EFK/Loki)
     │   ├─ Application logs
     │   ├─ Error traces
     │   └─ Audit logs
     │
     └─> Alerts (Alertmanager)
         ├─ Task failures
         ├─ Quality check failures
         ├─ Resource saturation
         └─> PagerDuty/Email
```

## Related Documentation

- [System Architecture](overview.md) - High-level architecture
- [Infrastructure](infrastructure.md) - Kubernetes & Terraform
- [API Reference](../api/airflow-dags.md) - DAG customization

---

**Last Updated**: October 2024
**Version**: 1.0
