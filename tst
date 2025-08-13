extensions:
  health_check:
    endpoint: 0.0.0.0:13133
  pprof:
    endpoint: 0.0.0.0:1777
  zpages:
    endpoint: 0.0.0.0:55679

receivers:
  vcenter:
    endpoint: https://vcsa.hostname.localnet
    username: ${env:VCENTER_USERNAME}
    password: ${env:VCENTER_PASSWORD}
    collection_interval: 5m
    tls:
      insecure: false
      insecure_skip_verify: false
      ca_file: /path/to/ca.crt
      cert_file: /path/to/cert.crt
      key_file: /path/to/key.key
    metrics:
      vcenter.host.cpu.utilization:
        enabled: true
      vcenter.host.memory.utilization:
        enabled: true
      vcenter.vm.cpu.utilization:
        enabled: true
      vcenter.vm.memory.utilization:
        enabled: true

processors:
  batch:
    timeout: 1s
    send_batch_size: 1024
    send_batch_max_size: 2048

exporters:
  otlp:
    endpoint: http://your-observability-backend:4317
    tls:
      insecure: true
  
  # For Splunk Observability Cloud
  # splunk_hec:
  #   endpoint: https://ingest.us1.signalfx.com/v1/log
  #   token: ${env:SPLUNK_TOKEN}

  debug:
    verbosity: detailed

service:
  extensions: [health_check, pprof, zpages]
  pipelines:
    metrics:
      receivers: [vcenter]
      processors: [batch]
      exporters: [otlp, debug]
  
  telemetry:
    logs:
      level: info
