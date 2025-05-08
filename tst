I can see you're encountering a certificate expiration error when trying to work with OpenTelemetry components. The key issue appears in the terminal output:

```
Error from server (InternalError): error when creating "otel-receivers-traces.yaml": Internal error occurred: failed calling webhook "mopentelemetrycollector.kb.io": failed to call webhook: Post "https://otel-collector-operator-opentelemetry-operator-webhook.monitoring.svc:443/mutate-opentelemetry-io-v1alpha1-opentelemetrycollector": x509: certificate has expired or is not yet valid: current time 2025-05-08T12:35:18Z is after 2025-05-01T03:35:05Z
```

The certificate for the OpenTelemetry collector operator webhook has expired on May 1, 2025, and your current time is May 8, 2025.

Here's how to fix this issue:

1. First, check the certificate status of the webhook:

```bash
kubectl get secret -n monitoring | grep webhook
```

2. Restart the OpenTelemetry operator to trigger certificate renewal:

```bash
kubectl rollout restart deployment otel-collector-operator-opentelemetry-operator -n monitoring
```

3. Wait for the operator to regenerate the certificate (usually takes 1-2 minutes):

```bash
kubectl rollout status deployment otel-collector-operator-opentelemetry-operator -n monitoring
```

4. If that doesn't work, you may need to manually delete and recreate the certificate secret:

```bash
# Get the certificate secret name first
kubectl get secret -n monitoring | grep webhook

# Delete the expired certificate secret
kubectl delete secret [webhook-certificate-secret-name] -n monitoring

# Restart the operator again to generate a new certificate
kubectl rollout restart deployment otel-collector-operator-opentelemetry-operator -n monitoring
```

5. Once the operator is back up with a valid certificate, try applying your configuration again:

```bash
kubectl apply -f otel-receivers-traces.yaml
```

Let me know if you need more specific guidance based on your OpenTelemetry operator version or Kubernetes setup.
