apiVersion: apps/v1
kind: Deployment
metadata:
  name: elastic-bulk-alert-log-ingest-api
  labels:
    app: elastic-bulk-alert-log-ingest-api
spec:
  replicas: 2
  selector:
    matchLabels:
      app: elastic-bulk-alert-log-ingest-api
  template:
    metadata:
      labels:
        app: elastic-bulk-alert-log-ingest-api
    spec:
      containers:
        - name: elastic-bulk-alert-log-ingest-api
          image: hub.comcast.net/efv-cloudplatform/elastic-bulk-alert-log-ingest-api:latest
          ports:
            - containerPort: 8080  # Change if your app runs on a different port
          env:
            - name: ENV_VAR_NAME  # Example env variable
              value: "value"
---
apiVersion: v1
kind: Service
metadata:
  name: elastic-bulk-alert-log-ingest-api
spec:
  selector:
    app: elastic-bulk-alert-log-ingest-api
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080  # Match with containerPort
  type: ClusterIP  # Change to LoadBalancer if external access is needed
