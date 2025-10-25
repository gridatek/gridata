# Gridata - Makefile for common development tasks

.PHONY: help setup local-up local-down test clean deploy-dev deploy-integration deploy-staging deploy-prod

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

setup: ## Install dependencies for local development
	@echo "Installing Python dependencies..."
	pip install -r spark-jobs/requirements.txt
	pip install -r airflow/requirements.txt
	@echo "Installing pre-commit hooks..."
	pre-commit install
	@echo "Setup complete!"

local-up: ## Start local development environment
	@echo "Starting Gridata local environment..."
	@bash scripts/setup-local-env.sh

local-down: ## Stop local development environment
	@echo "Stopping Gridata local environment..."
	docker-compose down

local-clean: ## Stop and remove all local data
	@echo "Cleaning Gridata local environment..."
	docker-compose down -v
	rm -rf airflow/logs/*
	rm -rf schemas/samples/*.parquet schemas/samples/*.csv schemas/samples/*.jsonl

test: ## Run all tests
	@echo "Running Terraform validation..."
	terraform fmt -check -recursive terraform/
	cd terraform && terraform validate
	@echo "Running Airflow DAG tests..."
	cd airflow && pytest tests/ -v
	@echo "Running Spark job tests..."
	cd spark-jobs && pytest tests/ -v
	@echo "All tests passed!"

test-airflow: ## Run Airflow tests only
	cd airflow && pytest tests/ -v --cov=dags

test-spark: ## Run Spark tests only
	cd spark-jobs && pytest tests/ -v --cov=src

lint: ## Run linters
	@echo "Linting Python code..."
	flake8 airflow/dags/ spark-jobs/src/
	black --check airflow/dags/ spark-jobs/src/
	@echo "Linting Terraform..."
	terraform fmt -check -recursive terraform/

format: ## Format code
	@echo "Formatting Python code..."
	black airflow/dags/ spark-jobs/src/
	@echo "Formatting Terraform..."
	terraform fmt -recursive terraform/

generate-data: ## Generate sample e-commerce data
	@echo "Generating sample data..."
	cd schemas/samples && python generate_sample_data.py

deploy-dev: ## Deploy to development environment
	@bash scripts/deploy-dev.sh

deploy-integration: ## Deploy to integration environment
	@echo "Deploying to integration..."
	cd terraform/envs/integration && terraform init && terraform apply

deploy-staging: ## Deploy to staging environment
	@echo "Deploying to staging..."
	cd terraform/envs/staging && terraform init && terraform apply

deploy-prod: ## Deploy to production environment
	@echo "Deploying to production..."
	@echo "⚠️  WARNING: This will deploy to production!"
	@read -p "Are you sure? (type 'yes' to continue): " confirm && [ "$$confirm" = "yes" ]
	cd terraform/envs/prod && terraform init && terraform apply

build-spark: ## Build Spark jobs Docker image
	@echo "Building Spark jobs Docker image..."
	docker build -t gridata/spark-jobs:latest spark-jobs/

push-spark: build-spark ## Build and push Spark jobs Docker image
	@echo "Pushing Spark jobs Docker image..."
	docker tag gridata/spark-jobs:latest $$REGISTRY/gridata/spark-jobs:latest
	docker push $$REGISTRY/gridata/spark-jobs:latest

logs-airflow: ## View Airflow logs
	docker-compose logs -f airflow-webserver airflow-scheduler

logs-spark: ## View Spark logs
	docker-compose logs -f spark-master spark-worker

logs-minio: ## View MinIO logs
	docker-compose logs -f minio

clean: ## Clean temporary files
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete
	find . -type f -name "*.log" -delete
	rm -rf .pytest_cache
	rm -rf airflow/.pytest_cache
	rm -rf spark-jobs/.pytest_cache

docs: ## Generate documentation
	@echo "Documentation available in:"
	@echo "  - README.md"
	@echo "  - CLAUDE.md"
	@echo "  - technical_design_spark_big_data_platform_terraform_vault_min_io_iceberg_airflow.md"

.DEFAULT_GOAL := help
