#!/bin/bash
# Test Gridata local environment setup
# Usage: ./scripts/test-local-setup.sh

set -e

FAILED=0
PASSED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🧪 Testing Gridata Local Environment"
echo "====================================="
echo ""

# Test function
test_service() {
    local name=$1
    local command=$2
    local expected=$3

    echo -n "Testing $name... "

    if eval "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}"
        ((PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}"
        echo "  Command: $command"
        ((FAILED++))
    fi
}

# Test Docker is running
echo "📦 Checking Prerequisites"
echo "-------------------------"
test_service "Docker daemon" "docker ps"
test_service "Docker Compose" "docker compose version"
echo ""

# Test containers are running
echo "🐳 Checking Containers"
echo "----------------------"
test_service "MinIO container" "docker ps | grep gridata-minio"
test_service "PostgreSQL container" "docker ps | grep gridata-postgres"
test_service "Redis container" "docker ps | grep gridata-redis"
test_service "Airflow webserver" "docker ps | grep gridata-airflow-webserver"
test_service "Airflow scheduler" "docker ps | grep gridata-airflow-scheduler"
test_service "Spark master" "docker ps | grep gridata-spark-master"
test_service "Spark worker" "docker ps | grep gridata-spark-worker"
test_service "Elasticsearch" "docker ps | grep gridata-elasticsearch"
echo ""

# Test service health
echo "❤️  Checking Service Health"
echo "---------------------------"
test_service "MinIO health endpoint" "curl -f http://localhost:9000/minio/health/live"
test_service "Airflow health endpoint" "curl -f http://localhost:8080/health"
test_service "Spark Master UI" "curl -f http://localhost:8081"
test_service "Elasticsearch health" "curl -f http://localhost:9200/_cluster/health"
echo ""

# Test PostgreSQL
echo "🐘 Checking PostgreSQL"
echo "----------------------"
test_service "PostgreSQL connection" "docker exec gridata-postgres pg_isready -U gridata"
test_service "Airflow database exists" "docker exec gridata-postgres psql -U gridata -lqt | grep -q airflow"
echo ""

# Test Redis
echo "📮 Checking Redis"
echo "-----------------"
test_service "Redis ping" "docker exec gridata-redis redis-cli ping | grep -q PONG"
echo ""

# Test MinIO buckets
echo "🪣 Checking MinIO Buckets"
echo "-------------------------"
test_service "gridata-raw bucket" "docker exec gridata-minio mc ls local/gridata-raw"
test_service "gridata-staging bucket" "docker exec gridata-minio mc ls local/gridata-staging"
test_service "gridata-curated bucket" "docker exec gridata-minio mc ls local/gridata-curated"
test_service "gridata-archive bucket" "docker exec gridata-minio mc ls local/gridata-archive"
echo ""

# Test Airflow
echo "🌬️  Checking Airflow"
echo "--------------------"
test_service "Airflow DB initialized" "docker exec gridata-airflow-webserver airflow db check"
test_service "Airflow DAGs loaded" "docker exec gridata-airflow-webserver airflow dags list | grep -q ecommerce"
echo ""

# Test Spark
echo "⚡ Checking Spark"
echo "----------------"
test_service "Spark master reachable" "docker exec gridata-spark-worker nc -z spark-master 7077"
echo ""

# Test sample data
echo "📊 Checking Sample Data"
echo "-----------------------"
test_service "Schema files exist" "ls schemas/avro/*.json"
test_service "Sample generator exists" "test -f schemas/samples/generate_sample_data.py"
echo ""

# Test volumes
echo "💾 Checking Docker Volumes"
echo "--------------------------"
test_service "minio-data volume" "docker volume inspect gridata_minio-data"
test_service "postgres-data volume" "docker volume inspect gridata_postgres-data"
test_service "airflow-logs volume" "docker volume inspect gridata_airflow-logs"
echo ""

# Test network
echo "🌐 Checking Network"
echo "-------------------"
test_service "gridata-network exists" "docker network inspect gridata-network"
echo ""

# Summary
echo "======================================"
echo "📊 Test Summary"
echo "======================================"
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
    echo ""
    echo "Your Gridata local environment is ready to use!"
    echo ""
    echo "Next steps:"
    echo "  • Access Airflow: http://localhost:8080 (admin/admin)"
    echo "  • Access MinIO: http://localhost:9001 (minioadmin/minioadmin123)"
    echo "  • Enable and run the 'ecommerce_orders_pipeline' DAG"
    echo ""
    exit 0
else
    echo -e "${RED}❌ Some tests failed!${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "  • Check if all services started: docker compose ps"
    echo "  • View logs: docker compose logs [service-name]"
    echo "  • Restart services: docker compose restart"
    echo "  • See docs/LINUX_LOCAL_SETUP.md for troubleshooting guide"
    echo ""
    exit 1
fi
