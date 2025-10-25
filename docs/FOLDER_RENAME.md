# Folder Structure Renamed

## Summary

Renamed project folders for better clarity and naming consistency.

**Date**: October 25, 2024

---

## Changes Made

### Folder Renames

| Old Name | New Name | Purpose |
|----------|----------|---------|
| `data/` | `schemas/` | Data schemas and sample generators |
| `data/schemas/` | `schemas/avro/` | Avro schema definitions |
| `data/samples/` | `schemas/samples/` | Sample data generators |
| `datahub/` | `storage/` | Storage metadata configurations |
| `datahub/recipes/` | `storage/ingestion/` | DataHub ingestion recipes |

---

## New Folder Structure

```
gridata/
├── schemas/                    # Data Schemas & Samples
│   ├── avro/                  # Avro schema definitions
│   │   ├── orders.json       # Order schema
│   │   └── customers.json    # Customer schema
│   │
│   └── samples/               # Sample data generation
│       └── generate_sample_data.py
│
├── storage/                    # Storage Metadata Configuration
│   └── ingestion/             # DataHub ingestion recipes
│       ├── iceberg_ingestion.yml
│       ├── airflow_ingestion.yml
│       └── s3_ingestion.yml
```

---

## Rationale

### Before (Confusing)
- `data/` - Sounded like it contained actual data, but it had schemas
- `datahub/` - Not clear it was about storage metadata

### After (Clear)
- `schemas/` - Clearly contains schema definitions
- `storage/` - Clearly about storage metadata and ingestion

---

## Files Updated

All references updated in:
- ✅ Python files (`.py`)
- ✅ YAML files (`.yml`, `.yaml`)
- ✅ Shell scripts (`.sh`)
- ✅ Markdown documentation (`.md`)
- ✅ Text files (`.txt`)
- ✅ Makefile
- ✅ CLAUDE.md
- ✅ .gitignore

### Specific Path Updates

| Old Path | New Path |
|----------|----------|
| `data/schemas/` | `schemas/avro/` |
| `data/samples/` | `schemas/samples/` |
| `datahub/recipes/` | `storage/ingestion/` |

---

## Updated Files Count

- **19 files** with `data/` references updated
- **11 files** with `datahub/` references updated
- **Total**: 30 files updated across the codebase

---

## Verification

```bash
# Verify new structure
ls -la schemas/
ls -la storage/

# Check for old references (should be none)
grep -r "data/schemas" . --include="*.py" --include="*.yml" --include="*.md"
grep -r "datahub/recipes" . --include="*.py" --include="*.yml" --include="*.md"
```

---

## Examples of Updated References

### Makefile
```makefile
# Before
generate-data: ## Generate sample e-commerce data
	cd data/samples && python generate_sample_data.py

# After
generate-data: ## Generate sample e-commerce data
	cd schemas/samples && python generate_sample_data.py
```

### Documentation (INDEX.md)
```markdown
# Before
- [Order Schema](../data/schemas/orders.json)
- [DataHub Recipes](../datahub/recipes/)

# After
- [Order Schema](../schemas/avro/orders.json)
- [DataHub Ingestion](../storage/ingestion/)
```

### README.md
```markdown
# Before
├── data/            Schemas & samples
├── datahub/         Metadata management

# After
├── schemas/         Data schemas & sample generators
├── storage/         Storage metadata configurations
```

---

## Impact

### No Breaking Changes
All internal references have been updated. No impact on:
- External APIs
- MinIO bucket names
- Iceberg table names
- Airflow DAG definitions
- Kubernetes deployments

### Better Clarity
- **Developers** immediately understand `schemas/` contains data schemas
- **DevOps** understand `storage/` is about storage metadata
- **New team members** have clearer mental model of project structure

---

## Related Documentation

- See [PROJECT_STATUS.md](PROJECT_STATUS.md) for overall project status
- See [INTEGRATION_ENV_ADDED.md](INTEGRATION_ENV_ADDED.md) for environment additions
- See [RENAME_COMPLETE.md](RENAME_COMPLETE.md) for Glacier→Gridata rename

---

**Status**: ✅ Complete

All folders renamed and references updated successfully.
