# Contributing to Gridata

Thank you for your interest in contributing to Gridata! This document provides guidelines and instructions for contributing.

## Code of Conduct

This project adheres to a Code of Conduct. By participating, you are expected to uphold this code.

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/your-username/gridata.git
   cd gridata
   ```
3. **Set up development environment**:
   ```bash
   make setup
   make local-up
   ```

## Development Workflow

### 1. Create a Feature Branch

```bash
git checkout -b feature/your-feature-name
```

Branch naming conventions:
- `feature/` - New features
- `bugfix/` - Bug fixes
- `hotfix/` - Urgent production fixes
- `docs/` - Documentation updates
- `refactor/` - Code refactoring

### 2. Make Your Changes

Follow these guidelines:

#### Python Code
- Follow PEP 8 style guide
- Use type hints where appropriate
- Write docstrings for functions and classes
- Format code with `black`:
  ```bash
  make format
  ```

#### Terraform Code
- Follow HashiCorp style guide
- Use meaningful variable names
- Add descriptions to all variables and outputs
- Format with `terraform fmt`:
  ```bash
  make format
  ```

#### Airflow DAGs
- Use descriptive DAG and task IDs
- Set appropriate retries and timeouts
- Add comprehensive docstrings
- Test DAG structure:
  ```bash
  make test-airflow
  ```

#### Spark Jobs
- Optimize for distributed processing
- Handle errors gracefully
- Log important operations
- Write unit tests:
  ```bash
  make test-spark
  ```

### 3. Write Tests

All code changes should include tests:

- **Unit tests**: Test individual functions/methods
- **Integration tests**: Test component interactions
- **DAG tests**: Validate DAG structure and dependencies

Run tests before committing:
```bash
make test
```

### 4. Commit Your Changes

Write clear, descriptive commit messages:

```bash
git add .
git commit -m "feat: add customer segmentation pipeline

- Implement RFM analysis
- Add customer tier classification
- Include data quality checks
- Update DataHub metadata"
```

Commit message format:
- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation changes
- `test:` - Test updates
- `refactor:` - Code refactoring
- `chore:` - Maintenance tasks

### 5. Push and Create Pull Request

```bash
git push origin feature/your-feature-name
```

Create a Pull Request on GitHub with:
- **Clear title** describing the change
- **Detailed description** of what and why
- **Link to related issues**
- **Screenshots** (if UI changes)
- **Test results**

## Pull Request Guidelines

### PR Checklist

- [ ] Code follows project style guidelines
- [ ] All tests pass locally
- [ ] New tests added for new functionality
- [ ] Documentation updated (if needed)
- [ ] No sensitive data (keys, passwords) in code
- [ ] Terraform changes include examples
- [ ] Breaking changes documented

### Review Process

1. **Automated checks** must pass (CI/CD pipeline)
2. **Code review** by at least one maintainer
3. **Testing** in development environment
4. **Approval** from codeowners
5. **Merge** to main branch

## Project Structure Guidelines

### Adding New Components

#### New Airflow DAG

1. Create DAG file in `airflow/dags/`
2. Follow naming convention: `{domain}_{pipeline_name}.py`
3. Add corresponding tests in `airflow/tests/`
4. Update documentation

#### New Spark Job

1. Create Python file in `spark-jobs/src/`
2. Create Kubernetes manifest in `spark-jobs/manifests/`
3. Add tests in `spark-jobs/tests/`
4. Update Dockerfile if new dependencies needed

#### New Terraform Module

1. Create module directory in `terraform/modules/`
2. Include: `main.tf`, `variables.tf`, `outputs.tf`, `README.md`
3. Add example usage in module README
4. Test in dev environment

### Documentation

Update documentation for:
- New features or capabilities
- API changes
- Configuration changes
- Breaking changes

Documentation locations:
- `README.md` - Project overview
- `CLAUDE.md` - AI assistant guidance
- Technical design doc - Architecture details
- Module READMEs - Specific component docs

## Testing

### Local Testing

```bash
# Run all tests
make test

# Run specific test suites
make test-airflow
make test-spark

# Run linters
make lint
```

### Integration Testing

```bash
# Start local environment
make local-up

# Test manually
# - Access Airflow UI
# - Trigger test DAGs
# - Verify outputs in MinIO

# Clean up
make local-down
```

## Code Review Standards

Reviewers check for:

### Code Quality
- Clear, readable code
- Proper error handling
- Efficient algorithms
- No code duplication

### Testing
- Adequate test coverage (>80%)
- Edge cases covered
- Tests are meaningful

### Security
- No hardcoded secrets
- Proper input validation
- Secure API usage
- PII handling compliance

### Performance
- Optimized queries
- Appropriate caching
- Resource limits set
- Scalability considered

## Getting Help

- **Questions**: Open a GitHub Discussion
- **Bugs**: File an issue with reproduction steps
- **Features**: Propose in GitHub Issues
- **Urgent**: Contact maintainers directly

## Recognition

Contributors are recognized in:
- Project README
- Release notes
- Annual contributor report

Thank you for contributing to Gridata! 🏔️
