# Contributing to PayNext

Thank you for your interest in contributing to PayNext! This guide will help you get started.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How to Contribute](#how-to-contribute)
- [Development Setup](#development-setup)
- [Coding Standards](#coding-standards)
- [Testing Requirements](#testing-requirements)
- [Pull Request Process](#pull-request-process)
- [Documentation](#documentation)

## Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Follow community guidelines
- Report inappropriate behavior to maintainers

## How to Contribute

### Reporting Bugs

1. Check existing issues
2. Create detailed bug report
3. Include reproduction steps
4. Provide system information

### Suggesting Features

1. Search existing feature requests
2. Create feature proposal
3. Describe use case and benefits
4. Discuss with maintainers

### Contributing Code

1. Fork the repository
2. Create feature branch
3. Make changes
4. Write tests
5. Update documentation
6. Submit pull request

## Development Setup

```bash
# 1. Fork and clone
git clone https://github.com/YOUR_USERNAME/PayNext.git
cd PayNext

# 2. Add upstream remote
git remote add upstream https://github.com/quantsingularity/PayNext.git

# 3. Install dependencies
./scripts/dev_environment_setup.sh

# 4. Create feature branch
git checkout -b feature/my-new-feature
```

## Coding Standards

### Java Code Style

**Google Java Format**: All Java code must follow Google Java Format

```bash
# Format Java files
java -jar google-java-format.jar --replace src/**/*.java

# Check formatting
./scripts/lint-all.sh
```

**Key Conventions**:

- 2-space indentation
- No wildcard imports
- Descriptive variable names
- JavaDoc for public methods

### JavaScript/TypeScript Style

**Prettier**: All JS/TS code must use Prettier

```bash
# Format code
npm run prettier:fix

# Check formatting
npm run prettier:check
```

**Key Conventions**:

- 2-space indentation
- Single quotes
- Semicolons
- ES6+ features

### Python Style

**PEP 8**: Follow Python PEP 8 style guide

```bash
# Format Python code
black ml_services/

# Lint
flake8 ml_services/
```

## Testing Requirements

### Backend Tests

**Required Coverage**: 80% minimum

```bash
# Run all tests
cd backend
mvn test

# Run with coverage
mvn clean verify

# Check coverage report
open target/site/jacoco/index.html
```

### Frontend Tests

**Required Coverage**: 70% minimum

```bash
# Web frontend
cd web-frontend
npm test -- --coverage

# Mobile frontend
cd mobile-frontend
pnpm test --coverage
```

### Integration Tests

```bash
# Run integration tests
./scripts/run_tests.sh -t integration
```

## Pull Request Process

### Before Submitting

- [ ] Code follows style guidelines
- [ ] All tests pass
- [ ] New tests added for new features
- [ ] Documentation updated
- [ ] Commit messages are clear
- [ ] Branch is up to date with main

### PR Template

```markdown
## Description

Brief description of changes

## Type of Change

- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing

Describe testing performed

## Checklist

- [ ] Code follows style guidelines
- [ ] Tests added/updated
- [ ] Documentation updated
- [ ] No breaking changes
```

### Review Process

1. Submit PR
2. Automated checks run (CI/CD)
3. Code review by maintainers
4. Address feedback
5. Approval and merge

## Documentation

### Updating Documentation

When adding features, update:

1. **API Documentation** (`docs/API.md`)
2. **Usage Guide** (`docs/USAGE.md`)
3. **Configuration** (`docs/CONFIGURATION.md`)
4. **Examples** (`docs/examples/`)

### Documentation Standards

- Clear, concise language
- Working code examples
- Screenshots where helpful
- Keep TOC updated
- Test all examples

### Documenting New APIs

```markdown
### New Endpoint Name

| Property          | Value               |
| ----------------- | ------------------- |
| **Method**        | POST                |
| **Path**          | `/api/new-endpoint` |
| **Auth Required** | Yes                 |
| **Description**   | Brief description   |

**Request Parameters**

| Name   | Type   | Required? | Default | Description | Example |
| ------ | ------ | --------- | ------- | ----------- | ------- |
| param1 | string | Yes       | -       | Description | "value" |

**Example Request**

\`\`\`bash
curl -X POST http://localhost:8002/api/new-endpoint \
-H "Authorization: Bearer $TOKEN" \
-d '{"param1": "value"}'
\`\`\`
```

## Commit Message Guidelines

### Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- **feat**: New feature
- **fix**: Bug fix
- **docs**: Documentation only
- **style**: Formatting, missing semicolons
- **refactor**: Code restructuring
- **test**: Adding/updating tests
- **chore**: Maintenance tasks

### Examples

```
feat(payment): add multi-currency support

Added EUR, GBP, JPY currency support with automatic conversion rates

Closes #123

fix(auth): resolve JWT token expiry issue

Updated token expiration from 30min to 1 hour
Fixed refresh token generation

Fixes #456
```

## Branch Naming

- `feature/feature-name` - New features
- `fix/bug-description` - Bug fixes
- `docs/doc-updates` - Documentation
- `refactor/component-name` - Refactoring
- `test/test-description` - Tests only
