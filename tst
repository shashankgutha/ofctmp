receivers:
  github:
    # GitHub API token - use environment variable for security
    github_token: ${GITHUB_TOKEN}
    
    # Organizations to collect metrics from
    orgs:
      - name: "your-org-name"
        # Optional: specify repositories within the org
        # If not specified, all accessible repos will be monitored
        repositories:
          - "repo1"
          - "repo2"
    
    # Individual repositories (if not part of an org or additional repos)
    repos:
      - name: "owner/repository-name"
      - name: "another-owner/another-repo"
    
    # Collection interval
    collection_interval: 60s
    
    # Metrics to collect (all are enabled by default)
    metrics:
      github.repository.count:
        enabled: true
      github.repository.contributor.count:
        enabled: true
      github.pull_request.count:
        enabled: true
      github.pull_request.time_open:
        enabled: true
      github.pull_request.time_to_merge:
        enabled: true
      github.issue.count:
        enabled: true
      github.issue.time_open:
        enabled: true
      github.commit.count:
        enabled: true
      github.branch.count:
        enabled: true
      github.branch.time_since_last_commit:
        enabled: true

processors:
  # Add resource attributes
  resource:
    attributes:
      - key: service.name
        value: github-metrics
        action: upsert
      - key: service.version
        value: "1.0.0"
        action: upsert
  
  # Batch processor for efficiency
  batch:
    timeout: 10s
    send_batch_size: 1024
    send_batch_max_size: 2048

  # Memory limiter to prevent OOM
  memory_limiter:
    limit_mib: 256

exporters:
  # Console exporter for debugging
  logging:
    loglevel: info
  
  # Prometheus exporter
  prometheus:
    endpoint: "0.0.0.0:8889"
    namespace: github_metrics
    const_labels:
      environment: production
  
  # OTLP exporter (e.g., for Jaeger, Grafana Cloud, etc.)
  otlp:
    endpoint: "http://localhost:4317"
    tls:
      insecure: true
  
  # File exporter for local storage
  file:
    path: ./github-metrics.json

service:
  pipelines:
    metrics:
      receivers: [github]
      processors: [memory_limiter, resource, batch]
      exporters: [logging, prometheus, file]
      # Add otlp to exporters list if using OTLP endpoint
  
  # Extensions for health checks and performance
  extensions: [health_check, pprof]
  
  # Telemetry configuration
  telemetry:
    logs:
      level: info
    metrics:
      address: 0.0.0.0:8888

extensions:
  health_check:
    endpoint: 0.0.0.0:13133
  pprof:
    endpoint: 0.0.0.0:1777
