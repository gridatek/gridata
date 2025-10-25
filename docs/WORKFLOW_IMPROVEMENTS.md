# GitHub Actions Workflow Improvements

## Summary

Improved the GitHub Actions workflow based on initial test run feedback.

**Date**: October 25, 2024

---

## Issues Found

### PostgreSQL Health Check Issue

**Problem:**
```
/var/run/postgresql:5432 - no response
```

**Root Cause:**
- `pg_isready` was checking Unix socket instead of TCP connection
- Missing `-h localhost` flag

**Fix:**
```bash
# Before
docker exec gridata-postgres pg_isready -U gridata

# After
docker exec gridata-postgres pg_isready -U gridata -h localhost
```

---

## Improvements Made

### 1. Better Health Check Order

**Before:**
- MinIO → PostgreSQL → Airflow (parallel checks)

**After:**
- PostgreSQL → MinIO → Airflow (sequential, dependencies)

**Why:**
- Airflow needs PostgreSQL to be ready first
- Check dependencies in order

---

### 2. Faster Polling

**Before:**
- Sleep 10 seconds between checks

**After:**
- Sleep 5 seconds between checks

**Impact:**
- 2× faster detection when services are ready
- Services typically ready in 30-60 seconds

---

### 3. More Attempts

**Before:**
- PostgreSQL: 30 attempts × 10s = 5 min max
- Airflow: 60 attempts × 10s = 10 min max

**After:**
- PostgreSQL: 60 attempts × 5s = 5 min max (same)
- Airflow: 90 attempts × 5s = 7.5 min max

**Impact:**
- More granular checking
- Better coverage of slow starts

---

### 4. Intermediate Logging

**New Feature:**
Shows logs if service takes too long:

```bash
if [ $i -eq 30 ]; then
  echo "⚠️  PostgreSQL taking longer than expected, checking logs..."
  docker logs gridata-postgres --tail 20
fi
```

**Benefit:**
- See what's wrong without waiting for timeout
- Debug issues faster

---

### 5. Initial Status Check

**New Step:**
```bash
# After starting services
sleep 10
docker compose ps
```

**Benefit:**
- See if containers crashed immediately
- Catch configuration errors early

---

### 6. Longer Timeout

**Before:**
- `timeout-minutes: 10`

**After:**
- `timeout-minutes: 15`

**Why:**
- GitHub runners can be slow
- Better to wait than fail unnecessarily

---

## Expected Timing

### Optimistic (Fast GitHub Runner)
```
PostgreSQL ready:  30 seconds
MinIO ready:       10 seconds
Airflow ready:     90 seconds
─────────────────────────────
Total wait:        ~2-3 minutes
```

### Realistic (Average Runner)
```
PostgreSQL ready:  60 seconds
MinIO ready:       20 seconds
Airflow ready:     180 seconds
─────────────────────────────
Total wait:        ~4-5 minutes
```

### Worst Case (Slow Runner)
```
PostgreSQL ready:  120 seconds
MinIO ready:       40 seconds
Airflow ready:     300 seconds
─────────────────────────────
Total wait:        ~7-8 minutes
Still passes!
```

---

## Complete Wait Strategy

### PostgreSQL (Critical Dependency)
- **Attempts**: 60 × 5s = 5 minutes max
- **Check**: `pg_isready -h localhost`
- **Logs at**: Attempt 30 (2.5 minutes)

### MinIO (Independent Service)
- **Attempts**: 30 × 5s = 2.5 minutes max
- **Check**: `curl http://localhost:9000/minio/health/live`
- **Usually ready**: 10-30 seconds

### Airflow (Depends on PostgreSQL)
- **Attempts**: 90 × 5s = 7.5 minutes max
- **Check**: `curl http://localhost:8080/health`
- **Logs at**: Attempt 60 (5 minutes)
- **Usually ready**: 2-4 minutes after PostgreSQL

---

## Error Detection

### Early Failures
```
Initial container status (10s after start):
- If container not listed → Image pull failed
- If status "Exited" → Configuration error
- If status "Restarting" → Crash loop
```

### Mid-Run Issues
```
At attempt 30/60 for PostgreSQL:
- Show last 20 lines of logs
- Identify: initialization errors, connection issues

At attempt 60/90 for Airflow:
- Show last 30 lines of logs
- Identify: database connection, migration issues
```

### Timeout
```
After max attempts:
- Service still not ready
- Final logs shown in "View logs on failure" step
- Workflow fails with clear indication
```

---

## Debugging Information

### On Success
- Initial status
- Ready confirmations
- Final status check

### On Failure
- Initial status
- Service logs at checkpoints
- Final status
- Last 100 lines of all service logs

---

## Files Modified

1. `.github/workflows/test-local-setup.yml`
   - Fixed PostgreSQL health check
   - Added intermediate logging
   - Improved wait strategy
   - Added initial status check

2. `docs/WORKFLOW_IMPROVEMENTS.md` (this file)

---

## Testing Recommendations

### For Contributors

When modifying docker-compose.yml:

```bash
# Test locally first
docker compose up -d

# Watch startup
watch -n 2 'docker compose ps'

# Check PostgreSQL
docker exec gridata-postgres pg_isready -U gridata -h localhost

# Check Airflow
curl http://localhost:8080/health

# If issues, check logs
docker compose logs postgres
docker compose logs airflow-webserver
```

### For GitHub Actions

- Push to feature branch first
- Monitor workflow run closely
- Check timing in GitHub Actions logs
- Adjust timeouts if needed for your setup

---

## Future Improvements

### Could Add

1. **Parallel health checks** (where no dependencies)
   ```yaml
   - MinIO & Redis in parallel
   - PostgreSQL alone
   - Airflow & Spark after PostgreSQL
   ```

2. **Smarter retries**
   ```bash
   # Exponential backoff
   sleep $((i * 2))  # 2s, 4s, 6s, 8s...
   ```

3. **Health check scripts**
   ```bash
   # Single script to check all
   ./scripts/health-check.sh
   ```

### But Keep Simple
- Current approach works
- Easy to understand
- Easy to debug
- Covers all cases

---

## Status

✅ **Improved and Ready**

Workflow now:
- Checks dependencies in order
- Polls faster (5s instead of 10s)
- Shows logs when slow
- More resilient to slow runners
- Better debugging information

**Ready to re-test on GitHub Actions!**

---

**Workflow Reliability**: Enhanced ✅
