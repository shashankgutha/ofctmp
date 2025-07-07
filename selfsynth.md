Overview
This document outlines the automated flow for managing Elastic Agent configurations through GitHub pull requests, validation, and deployment.

# Elastic Agent Git Workflow Project

## Project Structure

```
elastic-agent-config/
├── .github/
│   └── workflows/
│       └── elastic-agent-manager.yml
├── inputs/
│   ├── logs/
│   │   ├── apache.yml
│   │   └── nginx.yml
│   ├── metrics/
│   │   ├── system.yml
│   │   └── docker.yml
│   └── security/
│       └── auditd.yml
├── elastic-agent.yml
└── README.md
```

## Setup Instructions

### 1. Create Repository Structure

```bash
mkdir elastic-agent-config
cd elastic-agent-config
git init

# Create directories
mkdir -p .github/workflows
mkdir -p inputs/{logs,metrics,security}
```

### 2. Create Main Elastic Agent Configuration

Create `elastic-agent.yml`:

```yaml
# elastic-agent.yml
agent:
  download:
    source_uri: "https://artifacts.elastic.co/downloads/"
  monitoring:
    enabled: true
    logs: true
    metrics: true

inputs: []  # This will be populated automatically
```

### 3. Example Input Files

Create sample input files in appropriate folders:

**inputs/logs/apache.yml**
```yaml
type: filestream
id: apache-logs
enabled: true
paths:
  - /var/log/apache2/access.log
  - /var/log/apache2/error.log
processors:
  - add_host_metadata: ~
```

**inputs/metrics/system.yml**
```yaml
type: system/metrics
id: system-metrics
enabled: true
period: 10s
metricsets:
  - cpu
  - load
  - memory
  - network
  - process
  - process_summary
```

## How It Works

1. **User adds new input**: Create a new `.yml` file in any subfolder under `inputs/`
2. **Create PR**: Raise a pull request with the new input file
3. **Workflow triggers**: GitHub Actions automatically:
   - Validates YAML syntax
   - Appends new inputs to `elastic-agent.yml`
   - Commits changes back to the PR
   - Comments on PR with summary

## Usage Example

```bash
# Add a new input
mkdir -p inputs/databases
cat > inputs/databases/mysql.yml << EOF
type: mysql/metrics
id: mysql-metrics
enabled: true
hosts: ["tcp(127.0.0.1:3306)/"]
username: monitoring
password: secret
period: 10s
metricsets:
  - status
  - galera_status
EOF

# Commit and push
git add inputs/databases/mysql.yml
git commit -m "Add MySQL metrics input"
git push origin feature/add-mysql-metrics

# Create PR - workflow will automatically validate and update elastic-agent.yml
```

## Features

- ✅ Automatic YAML validation
- ✅ Appends new inputs to main config
- ✅ Commits changes back to PR
- ✅ PR comments with summary
- ✅ Supports nested folder structure
- ✅ No manual scripts needed
