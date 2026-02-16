# Testing Guide

> Documentation version: **v0.2.0**

## Install test dependencies

```bash
python3 -m pip install -r backend/requirements-dev.txt
```

## Fast local workflow

```bash
make test-fast
```

Runs `unit`, `api`, and `regression` markers only.

## Full default suite (excluding stress)

```bash
make test
```

## Integration suite

```bash
make test-integration
```

## Stress suite (manual/opt-in)

```bash
make test-stress
```

## Coverage report

```bash
make coverage
```

Coverage XML is written to `backend/coverage.xml`.

## Pre-commit hooks

```bash
pre-commit install
pre-commit run --all-files
```

Configured hooks run:

- YAML/conflict hygiene checks
- backend compile check
- fast backend pytest gate
