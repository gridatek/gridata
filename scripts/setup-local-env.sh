#!/bin/bash
# Setup local Gridata development environment

set -e

echo "🏔️  Setting up Gridata local development environment..."

# Check prerequisites
command -v docker >/dev/null 2>&1 || { echo "❌ Docker is required but not installed. Aborting." >&2; exit 1; }
command -v docker-compose >/dev/null 2>&1 || { echo "❌ Docker Compose is required but not installed. Aborting." >&2; exit 1; }

echo "✅ Prerequisites check passed"

# Create required directories
echo "📁 Creating local directories..."
mkdir -p data/samples
mkdir -p airflow/logs
mkdir -p spark-jobs/logs

# Start Docker Compose services
echo "🐳 Starting Docker Compose services..."
docker-compose up -d

# Wait for services to be healthy
echo "⏳ Waiting for services to be ready..."
sleep 10

# Check MinIO health
echo "🪣 Checking MinIO..."
until curl -f http://localhost:9000/minio/health/live >/dev/null 2>&1; do
    echo "  Waiting for MinIO..."
    sleep 5
done
echo "✅ MinIO is ready"

# Check Postgres health
echo "🐘 Checking PostgreSQL..."
until docker exec gridata-postgres pg_isready -U gridata >/dev/null 2>&1; do
    echo "  Waiting for PostgreSQL..."
    sleep 5
done
echo "✅ PostgreSQL is ready"

# Check Airflow health
echo "🌬️  Checking Airflow..."
until curl -f http://localhost:8080/health >/dev/null 2>&1; do
    echo "  Waiting for Airflow..."
    sleep 5
done
echo "✅ Airflow is ready"

# Generate sample data
echo "📊 Generating sample e-commerce data..."
cd data/samples
pip install -q faker pandas pyarrow >/dev/null 2>&1
python generate_sample_data.py
cd ../..
echo "✅ Sample data generated"

# Upload sample data to MinIO
echo "⬆️  Uploading sample data to MinIO..."
docker run --rm --network gridata-network \
    -v $(pwd)/data/samples:/data \
    minio/mc:latest sh -c "
    mc alias set local http://minio:9000 minioadmin minioadmin123 && \
    mc cp /data/orders.jsonl local/gridata-raw/raw/ecommerce/orders/2024-01-01/ && \
    mc cp /data/customers.parquet local/gridata-raw/raw/ecommerce/customers/ && \
    mc cp /data/products.parquet local/gridata-raw/raw/ecommerce/products/ && \
    mc cp /data/clickstream.parquet local/gridata-raw/raw/ecommerce/clickstream/
"
echo "✅ Sample data uploaded to MinIO"

echo ""
echo "🎉 Gridata local environment is ready!"
echo ""
echo "📍 Access services at:"
echo "  • Airflow UI:      http://localhost:8080 (admin/admin)"
echo "  • MinIO Console:   http://localhost:9001 (minioadmin/minioadmin123)"
echo "  • Spark Master:    http://localhost:8081"
echo "  • PostgreSQL:      localhost:5432 (gridata/gridata123)"
echo ""
echo "🚀 Next steps:"
echo "  1. Open Airflow UI and enable 'ecommerce_orders_pipeline' DAG"
echo "  2. Manually trigger the DAG or wait for schedule"
echo "  3. Monitor progress in Airflow UI"
echo "  4. View data in MinIO Console"
echo ""
echo "📚 Documentation:"
echo "  • README.md - Project overview"
echo "  • CLAUDE.md - AI assistant guidance"
echo "  • Technical Design - Complete architecture"
echo ""
