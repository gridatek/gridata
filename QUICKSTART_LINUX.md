# Gridata - Linux Quick Start

**Get Gridata running locally on Linux in 5 minutes!**

---

## Prerequisites

```bash
# Install Docker and Docker Compose
sudo apt-get update && sudo apt-get install -y docker.io docker-compose-plugin

# Start Docker
sudo systemctl start docker
sudo usermod -aG docker $USER && newgrp docker

# Install Python 3
sudo apt-get install -y python3 python3-pip
```

---

## One-Command Setup

```bash
# Clone and start everything
git clone https://github.com/your-org/gridata.git
cd gridata
make local-up
```

**That's it!** ✨

The script will:
- Start all services (MinIO, Postgres, Airflow, Spark, etc.)
- Generate sample e-commerce data
- Upload data to MinIO
- Display access URLs

**Time: ~5-10 minutes** (first time, downloading Docker images)

---

## Access Services

| Service | URL | Login |
|---------|-----|-------|
| **Airflow** | http://localhost:8080 | admin / admin |
| **MinIO Console** | http://localhost:9001 | minioadmin / minioadmin123 |
| **Spark UI** | http://localhost:8081 | - |

---

## Run Your First Pipeline

1. Open **Airflow**: http://localhost:8080
2. Find DAG: `ecommerce_orders_pipeline`
3. Toggle **ON** (switch on left)
4. Click **▶ Play** button to trigger
5. Watch tasks turn green! ✅

---

## Common Commands

```bash
# Check service status
docker compose ps

# View logs
docker compose logs -f airflow-webserver

# Stop environment (keeps data)
make local-down

# Clean everything (deletes data)
make local-clean

# Test setup
make local-test

# Restart specific service
docker compose restart airflow-scheduler
```

---

## Troubleshooting

### Port already in use?
```bash
# Change ports in docker-compose.yml
# Example: "8081:8080" instead of "8080:8080"
```

### Services not starting?
```bash
# Check logs
docker compose logs postgres
docker compose logs airflow-webserver

# Clean restart
docker compose down -v
docker compose up -d
```

### Permission denied?
```bash
# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

---

## Next Steps

- **Full Guide**: [docs/LINUX_LOCAL_SETUP.md](docs/LINUX_LOCAL_SETUP.md)
- **Getting Started**: [docs/guides/GETTING_STARTED.md](docs/guides/GETTING_STARTED.md)
- **Architecture**: [docs/architecture/overview.md](docs/architecture/overview.md)

---

## System Requirements

- **Minimum**: 2 CPU cores, 4 GB RAM, 10 GB disk
- **Recommended**: 4+ CPU cores, 8+ GB RAM, 20+ GB SSD
- **OS**: Ubuntu 22.04, Debian 11, Fedora 38, or similar

---

## Help

- **Issues?** Check [docs/LINUX_LOCAL_SETUP.md](docs/LINUX_LOCAL_SETUP.md) troubleshooting section
- **Questions?** Open an issue on GitHub

---

**Happy Data Processing!** 🚀
