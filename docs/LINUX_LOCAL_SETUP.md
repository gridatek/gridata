# Gridata - Linux Local Setup Guide

Complete guide to running Gridata locally on Linux systems.

**Date**: October 25, 2024
**Tested On**: Ubuntu 22.04, Debian 11, Fedora 38

---

## Prerequisites

### Required Software

1. **Docker** (20.10+)
   ```bash
   # Ubuntu/Debian
   sudo apt-get update
   sudo apt-get install docker.io docker-compose-plugin

   # Fedora/RHEL
   sudo dnf install docker docker-compose

   # Start Docker
   sudo systemctl start docker
   sudo systemctl enable docker

   # Add your user to docker group (logout/login required)
   sudo usermod -aG docker $USER
   newgrp docker  # or logout and login
   ```

2. **Docker Compose** (2.0+)
   ```bash
   # Check if installed
   docker compose version

   # If not available, install standalone
   sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
   sudo chmod +x /usr/local/bin/docker-compose
   ```

3. **Python 3.9+** (for sample data generation)
   ```bash
   # Ubuntu/Debian
   sudo apt-get install python3 python3-pip python3-venv

   # Fedora/RHEL
   sudo dnf install python3 python3-pip

   # Verify
   python3 --version
   ```

4. **Git**
   ```bash
   # Ubuntu/Debian
   sudo apt-get install git

   # Fedora/RHEL
   sudo dnf install git
   ```

### Optional Tools

- **`curl`** - For health checks
- **`jq`** - For JSON parsing
- **`make`** - For using Makefile commands

```bash
# Ubuntu/Debian
sudo apt-get install curl jq make

# Fedora/RHEL
sudo dnf install curl jq make
```

---

## Quick Start (Automated)

### Option 1: Using Makefile (Recommended)

```bash
# Clone repository
git clone https://github.com/your-org/gridata.git
cd gridata

# Start everything (this will take 5-10 minutes first time)
make local-up
```

That's it! The script will:
- ✅ Check prerequisites
- ✅ Start all Docker services
- ✅ Wait for services to be healthy
- ✅ Generate sample e-commerce data
- ✅ Upload data to MinIO
- ✅ Display access URLs

### Option 2: Manual Script Execution

```bash
# Make script executable
chmod +x scripts/setup-local-env.sh

# Run setup
./scripts/setup-local-env.sh
```

---

## Manual Setup (Step-by-Step)

If you prefer manual control or troubleshooting:

### Step 1: Start Docker Services

```bash
# Start all services in background
docker compose up -d

# View logs (optional)
docker compose logs -f
```

**Services Started:**
- MinIO (S3 storage) - Ports 9000, 9001
- PostgreSQL (metadata) - Port 5432
- Redis (cache) - Port 6379
- Airflow Webserver - Port 8080
- Airflow Scheduler
- Spark Master - Port 8081, 7077
- Spark Worker
- Elasticsearch - Port 9200
- Zookeeper - Port 2181
- Kafka - Port 9092

### Step 2: Wait for Services

```bash
# Check service status
docker compose ps

# All services should show "Up" or "Up (healthy)"
# This may take 2-3 minutes
```

### Step 3: Verify MinIO

```bash
# Test MinIO API
curl -f http://localhost:9000/minio/health/live

# Should return 200 OK
```

### Step 4: Verify PostgreSQL

```bash
# Test Postgres connection
docker exec gridata-postgres pg_isready -U gridata

# Should output: "gridata-postgres:5432 - accepting connections"
```

### Step 5: Verify Airflow

```bash
# Test Airflow webserver
curl -f http://localhost:8080/health

# Should return JSON with "healthy" status
```

### Step 6: Generate Sample Data

```bash
cd schemas/samples

# Create virtual environment (recommended)
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install faker pandas pyarrow

# Generate data
python generate_sample_data.py

# Verify files created
ls -lh *.parquet *.jsonl

# Deactivate venv
deactivate
cd ../..
```

### Step 7: Upload Data to MinIO

```bash
# Using MinIO client container
docker run --rm --network gridata-network \
    -v $(pwd)/schemas/samples:/data \
    minio/mc:latest sh -c "
    mc alias set local http://minio:9000 minioadmin minioadmin123 && \
    mc cp /data/orders.jsonl local/gridata-raw/raw/ecommerce/orders/2024-01-01/ && \
    mc cp /data/customers.parquet local/gridata-raw/raw/ecommerce/customers/ && \
    mc cp /data/products.parquet local/gridata-raw/raw/ecommerce/products/ && \
    mc cp /data/clickstream.parquet local/gridata-raw/raw/ecommerce/clickstream/
"
```

---

## Accessing Services

### Web Interfaces

| Service | URL | Credentials |
|---------|-----|-------------|
| **Airflow UI** | http://localhost:8080 | admin / admin |
| **MinIO Console** | http://localhost:9001 | minioadmin / minioadmin123 |
| **Spark Master UI** | http://localhost:8081 | None |
| **Elasticsearch** | http://localhost:9200 | None |

### Database Connections

```bash
# PostgreSQL (Airflow metadata)
psql -h localhost -p 5432 -U gridata -d airflow
# Password: gridata123

# Redis
redis-cli -h localhost -p 6379
```

---

## Running Your First Pipeline

### 1. Access Airflow UI

Open browser: http://localhost:8080

### 2. Enable DAG

- Login with `admin` / `admin`
- Find DAG: `ecommerce_orders_pipeline`
- Toggle the switch to enable it
- Click the "Play" button to trigger manually

### 3. Monitor Execution

- Click on the DAG name
- View "Graph" or "Grid" view
- Watch tasks turn green as they complete
- Check logs for each task

### 4. Verify Results

**In MinIO Console:**
- Go to http://localhost:9001
- Login: minioadmin / minioadmin123
- Navigate to `gridata-curated` bucket
- Look for processed data in `warehouse/` folder

**In Airflow:**
- Check task logs for Spark job output
- Verify data quality check results

---

## Common Commands

### View Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f airflow-webserver
docker compose logs -f spark-master
docker compose logs -f minio

# Last 100 lines
docker compose logs --tail=100 airflow-scheduler
```

### Restart Services

```bash
# Restart specific service
docker compose restart airflow-webserver

# Restart all
docker compose restart
```

### Stop Environment

```bash
# Stop all services (keeps data)
docker compose stop

# Or using make
make local-down
```

### Clean Everything

```bash
# Stop and remove all containers + volumes (DELETES ALL DATA)
docker compose down -v

# Or using make
make local-clean
```

### Execute Commands in Containers

```bash
# Airflow CLI
docker exec -it gridata-airflow-webserver airflow dags list

# Check Spark
docker exec -it gridata-spark-master spark-submit --version

# MinIO CLI
docker exec -it gridata-minio mc ls local/
```

---

## Troubleshooting

### Issue: Port Already in Use

**Error:**
```
Error starting userland proxy: listen tcp4 0.0.0.0:8080: bind: address already in use
```

**Solution:**
```bash
# Find what's using the port
sudo lsof -i :8080
# Or
sudo netstat -tulpn | grep :8080

# Kill the process or change docker-compose.yml port mapping
# Example: "8081:8080" instead of "8080:8080"
```

### Issue: Permission Denied on Docker

**Error:**
```
permission denied while trying to connect to the Docker daemon socket
```

**Solution:**
```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Logout and login, or run:
newgrp docker

# Verify
docker ps
```

### Issue: Services Not Healthy

**Check logs:**
```bash
docker compose ps  # Check status
docker compose logs postgres  # Example: check postgres
```

**Common fixes:**
```bash
# Insufficient memory
docker system prune -a  # Clean up old containers/images

# Corrupted volumes
docker compose down -v  # Remove volumes
docker compose up -d    # Restart fresh
```

### Issue: Airflow Database Not Initialized

**Error in logs:**
```
sqlalchemy.exc.OperationalError: (psycopg2.OperationalError) FATAL: database "airflow" does not exist
```

**Solution:**
```bash
# Reinitialize Airflow database
docker compose down
docker volume rm gridata_postgres-data
docker compose up -d
```

### Issue: Sample Data Generation Fails

**Error:**
```
ModuleNotFoundError: No module named 'faker'
```

**Solution:**
```bash
cd schemas/samples
pip3 install --user faker pandas pyarrow
python3 generate_sample_data.py
```

### Issue: MinIO Upload Fails

**Error:**
```
mc: Unable to get bucket location
```

**Solution:**
```bash
# Wait for MinIO to be fully ready
sleep 10

# Or check MinIO logs
docker compose logs minio

# Verify buckets exist
docker exec gridata-minio mc ls local/
```

---

## Performance Tuning

### For Low-End Systems (4GB RAM)

Edit `docker-compose.yml`:

```yaml
# Reduce Elasticsearch memory
elasticsearch:
  environment:
    - ES_JAVA_OPTS=-Xms256m -Xmx256m

# Reduce Spark worker
spark-worker:
  environment:
    SPARK_WORKER_MEMORY: 1G
    SPARK_WORKER_CORES: 1
```

### For High-End Systems (16GB+ RAM)

```yaml
# Increase Elasticsearch
elasticsearch:
  environment:
    - ES_JAVA_OPTS=-Xms2g -Xmx2g

# Increase Spark
spark-worker:
  environment:
    SPARK_WORKER_MEMORY: 4G
    SPARK_WORKER_CORES: 4
```

---

## Development Workflow

### 1. Modify DAGs

```bash
# Edit DAG files
vim airflow/dags/ecommerce_orders_pipeline.py

# Airflow auto-reloads (wait 30 seconds)
# Or restart scheduler
docker compose restart airflow-scheduler
```

### 2. Modify Spark Jobs

```bash
# Edit Spark job
vim spark-jobs/src/process_orders.py

# Submit job manually
docker exec -it gridata-spark-master spark-submit \
  --master spark://spark-master:7077 \
  /opt/spark-jobs/src/process_orders.py
```

### 3. Run Tests

```bash
# Airflow DAG tests
cd airflow
pytest tests/ -v

# Spark job tests
cd spark-jobs
pytest tests/ -v
```

---

## Next Steps

1. ✅ Services running
2. ✅ Sample data loaded
3. ✅ First pipeline executed

**Continue with:**
- Read [GETTING_STARTED.md](guides/GETTING_STARTED.md) for feature walkthrough
- Read [CONTRIBUTING.md](guides/CONTRIBUTING.md) for development guidelines
- Explore [architecture documentation](architecture/overview.md)
- Try the Customer 360 pipeline
- Customize for your own data

---

## Clean Shutdown

```bash
# Stop services gracefully
docker compose stop

# Or stop and remove containers (keeps volumes/data)
docker compose down

# Or remove everything including data
docker compose down -v
```

---

## System Requirements

### Minimum
- **CPU**: 2 cores
- **RAM**: 4 GB
- **Disk**: 10 GB free
- **OS**: Linux kernel 3.10+

### Recommended
- **CPU**: 4+ cores
- **RAM**: 8+ GB
- **Disk**: 20+ GB free SSD
- **OS**: Ubuntu 22.04 LTS or similar

---

## Support

- **Issues**: Check [troubleshooting section](#troubleshooting) above
- **Documentation**: See `docs/` folder
- **GitHub**: Report issues at https://github.com/your-org/gridata/issues

---

**Happy Data Processing!** 🏔️
