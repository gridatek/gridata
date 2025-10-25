# Getting Started with Gridata

This guide will help you get Gridata up and running in under 15 minutes.

## Prerequisites

Before you begin, ensure you have:

- ✅ **Docker Desktop** (Windows/Mac) or Docker Engine (Linux)
- ✅ **Docker Compose** v2.0+
- ✅ **Python 3.11+** for sample data generation
- ✅ **Git** for cloning the repository
- ✅ At least **8GB RAM** and **50GB disk space** available

## Step-by-Step Setup

### 1. Clone the Repository

```bash
git clone https://github.com/your-org/gridata.git
cd gridata
```

### 2. Start Local Environment

We've provided an automated setup script that handles everything:

**On Linux/Mac:**
```bash
chmod +x scripts/setup-local-env.sh
./scripts/setup-local-env.sh
```

**On Windows (using Git Bash or WSL):**
```bash
bash scripts/setup-local-env.sh
```

**Or use Make:**
```bash
make local-up
```

This script will:
- ✅ Start all Docker containers (MinIO, PostgreSQL, Airflow, Spark, etc.)
- ✅ Create MinIO buckets
- ✅ Initialize Airflow database
- ✅ Generate sample e-commerce data
- ✅ Upload sample data to MinIO

### 3. Verify Services

After setup completes, verify all services are running:

```bash
docker-compose ps
```

You should see:
- ✅ `gridata-minio` - HEALTHY
- ✅ `gridata-postgres` - HEALTHY
- ✅ `gridata-airflow-webserver` - HEALTHY
- ✅ `gridata-airflow-scheduler` - RUNNING
- ✅ `gridata-spark-master` - RUNNING
- ✅ `gridata-spark-worker` - RUNNING

### 4. Access Web Interfaces

Open your browser and navigate to:

| Service | URL | Credentials |
|---------|-----|-------------|
| **Airflow** | http://localhost:8080 | admin / admin |
| **MinIO Console** | http://localhost:9001 | minioadmin / minioadmin123 |
| **Spark Master** | http://localhost:8081 | N/A |

### 5. Run Your First Pipeline

#### Enable the DAG

1. Go to **Airflow UI** (http://localhost:8080)
2. Login with `admin` / `admin`
3. Find the `ecommerce_orders_pipeline` DAG
4. Toggle the switch to **enable** it

#### Trigger Manual Run

1. Click on the DAG name
2. Click the **▶ Play** button (top right)
3. Select "Trigger DAG"
4. Watch the pipeline execute in real-time!

#### Monitor Progress

- **Graph View**: See task dependencies and status
- **Task Logs**: Click on a task to view detailed logs
- **MinIO**: Check the `gridata-curated` bucket for output data

### 6. Explore the Data

#### View Raw Data in MinIO

1. Go to **MinIO Console** (http://localhost:9001)
2. Navigate to `gridata-raw` bucket
3. Browse: `raw/ecommerce/orders/2024-01-01/`
4. You'll see the uploaded sample data

#### View Processed Data

After the pipeline runs successfully:
1. Go to `gridata-curated` bucket
2. Browse: `warehouse/ecommerce/orders/`
3. See partitioned Iceberg tables

#### Query with Spark

Access the Spark container:
```bash
docker exec -it gridata-spark-master /bin/bash
```

Start PySpark:
```bash
pyspark --packages org.apache.iceberg:iceberg-spark-runtime-3.5_2.12:1.4.2 \
  --conf spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions \
  --conf spark.sql.catalog.gridata=org.apache.iceberg.spark.SparkCatalog \
  --conf spark.sql.catalog.gridata.type=hadoop \
  --conf spark.sql.catalog.gridata.warehouse=s3a://gridata-curated/warehouse \
  --conf spark.hadoop.fs.s3a.endpoint=http://minio:9000 \
  --conf spark.hadoop.fs.s3a.access.key=minioadmin \
  --conf spark.hadoop.fs.s3a.secret.key=minioadmin123 \
  --conf spark.hadoop.fs.s3a.path.style.access=true \
  --conf spark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem
```

Query the data:
```python
# Read Iceberg table
df = spark.table("gridata.ecommerce.orders")

# Show schema
df.printSchema()

# Show sample data
df.show()

# Run analytics
df.groupBy("order_category").count().show()

# Calculate total revenue
df.selectExpr("sum(order_total) as total_revenue").show()
```

### 7. Run the Customer 360 Pipeline

Once order data is processed:

1. Go to **Airflow UI**
2. Enable `ecommerce_customer_360` DAG
3. Trigger it manually
4. This builds a comprehensive customer view

The pipeline will:
- Join customer demographics with orders
- Aggregate clickstream behavior
- Calculate Customer Lifetime Value (CLV)
- Segment customers by value and activity
- Identify churn risk

## Understanding the Data Flow

```
1. Raw Files (CSV/JSON/Parquet)
   ↓
2. Drop in MinIO bucket (gridata-raw)
   ↓
3. Airflow S3KeySensor detects file
   ↓
4. Validation Task checks schema
   ↓
5. Spark Job processes & transforms
   ↓
6. Write to Iceberg table (ACID transaction)
   ↓
7. Data Quality Checks
   ↓
8. Publish metadata to DataHub
   ↓
9. Available for consumption
```

## Common Tasks

### Generate More Sample Data

```bash
cd schemas/samples
python generate_sample_data.py
```

### Upload Custom Data

```bash
# Install MinIO client
docker run --rm -it --network gridata-network \
  -v $(pwd)/your-data:/data \
  minio/mc:latest sh

# Inside container
mc alias set local http://minio:9000 minioadmin minioadmin123
mc cp /data/your-file.parquet local/gridata-raw/raw/custom/
```

### View Airflow Logs

```bash
# All Airflow logs
make logs-airflow

# Or specific service
docker-compose logs -f airflow-scheduler
```

### View Spark Logs

```bash
make logs-spark
```

### Restart Services

```bash
docker-compose restart
```

### Stop Everything

```bash
make local-down
```

### Clean All Data

```bash
make local-clean
```

## Troubleshooting

### Airflow Web UI not loading

```bash
# Check if container is running
docker ps | grep airflow-webserver

# Check logs
docker logs gridata-airflow-webserver

# Restart
docker-compose restart airflow-webserver
```

### MinIO connection refused

```bash
# Verify MinIO is running
docker ps | grep minio

# Check health
curl http://localhost:9000/minio/health/live

# Restart
docker-compose restart minio
```

### Spark job fails

```bash
# Check Spark master logs
docker logs gridata-spark-master

# Check if worker is connected
# Go to http://localhost:8081 and verify worker count
```

### Database connection errors

```bash
# Verify PostgreSQL is running
docker exec gridata-postgres pg_isready -U gridata

# Restart database
docker-compose restart postgres
```

### Out of disk space

```bash
# Clean up Docker
docker system prune -a --volumes

# Remove old Airflow logs
rm -rf airflow/logs/*
```

## Next Steps

Now that you have Gridata running locally:

1. **📚 Read the Documentation**
   - [README.md](README.md) - Project overview
   - [CLAUDE.md](CLAUDE.md) - AI assistant guidance
   - [Technical Design](technical_design_spark_big_data_platform_terraform_vault_min_io_iceberg_airflow.md) - Complete architecture

2. **🔧 Customize Pipelines**
   - Modify existing DAGs in `airflow/dags/`
   - Add new Spark jobs in `spark-jobs/src/`
   - Update schemas in `schemas/avro/`

3. **🧪 Experiment**
   - Try different data volumes
   - Add new transformations
   - Create custom metrics

4. **☁️ Deploy to Cloud**
   - Review [deployment guide](README.md#production-deployment)
   - Configure AWS/GCP/Azure credentials
   - Run `make deploy-dev`

5. **🤝 Contribute**
   - See [CONTRIBUTING.md](CONTRIBUTING.md)
   - Submit issues and PRs
   - Share your use cases

## Quick Reference

### Useful Commands

```bash
# Start environment
make local-up

# Stop environment
make local-down

# Run all tests
make test

# Format code
make format

# Generate sample data
make generate-data

# View logs
make logs-airflow
make logs-spark
make logs-minio

# Clean everything
make local-clean
```

### Default Credentials

| Service | Username | Password |
|---------|----------|----------|
| Airflow | admin | admin |
| MinIO | minioadmin | minioadmin123 |
| PostgreSQL | gridata | gridata123 |

### Port Mapping

| Service | Port | URL |
|---------|------|-----|
| Airflow Web | 8080 | http://localhost:8080 |
| MinIO API | 9000 | http://localhost:9000 |
| MinIO Console | 9001 | http://localhost:9001 |
| Spark Master | 8081 | http://localhost:8081 |
| PostgreSQL | 5432 | localhost:5432 |
| Redis | 6379 | localhost:6379 |
| Elasticsearch | 9200 | http://localhost:9200 |

## Need Help?

- 📖 **Documentation**: Check the docs in this repo
- 🐛 **Issues**: [GitHub Issues](https://github.com/your-org/gridata/issues)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/your-org/gridata/discussions)
- 📧 **Email**: support@your-org.com

---

**Happy Data Processing! 🚀**
