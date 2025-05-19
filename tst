agent.config:
  synthetics.throttling:
    browser:
      enabled: true
      max_active_jobs: 1  # Allow only 1 browser synthetic test to run at a time
