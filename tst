# fleet-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fleet-server
  namespace: your-namespace
spec:
  replicas: 1
  selector:
    matchLabels:
      app: fleet-server
  template:
    metadata:
      labels:
        app: fleet-server
    spec:
      containers:
      - name: fleet-server
        image: docker.elastic.co/beats/elastic-agent:8.9.0
        env:
        - name: FLEET_SERVER_ENABLE
          value: "true"
        - name: FLEET_URL
          value: "https://fleet-server-service.your-namespace.svc:8220"
        - name: FLEET_SERVER_CERT
          value: "/usr/share/elastic-agent/fleet.crt"
        - name: FLEET_SERVER_CERT_KEY
          value: "/usr/share/elastic-agent/fleet.key"
        - name: FLEET_ENROLL
          value: "1"
        - name: FLEET_ENROLLMENT_TOKEN
          valueFrom:
            secretKeyRef:
              name: fleet-enrollment-token
              key: enrollment-token
        - name: FLEET_SERVER_ELASTICSEARCH_HOST
          value: "http://elasticsearch-master:9200"  # Adjust to your ES service
        ports:
        - containerPort: 8220
          name: https
        volumeMounts:
        - name: certs
          mountPath: /usr/share/elastic-agent
          readOnly: true
      volumes:
      - name: certs
        secret:
          secretName: fleet-cert
