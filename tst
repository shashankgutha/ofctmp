
apiVersion: apps/v1
kind: Deployment
metadata:
  name: elastic-agent
  namespace: default # Change this to your desired namespace
spec:
  replicas: 1 # Adjust as needed
  selector:
    matchLabels:
      app: elastic-agent
  template:
    metadata:
      labels:
        app: elastic-agent
    spec:
      serviceAccountName: elastic-agent # Create this ServiceAccount if it doesn't exist
      containers:
      - name: elastic-agent
        image: docker.elastic.co/elasticagent/elastic-agent:8.17.3 # Use your Elastic Stack version
        env:
          - name: FLEET_URL
            value: "https://fleet-server.default.svc:8220" # Replace with your Fleet Server URL
          - name: FLEET_ENROLLMENT_TOKEN
            valueFrom:
              secretKeyRef:
                name: elastic-agent-enrollment-token # Secret containing your enrollment token
                key: token
          # If using custom CA for Fleet Server, mount it and reference it here
          # - name: FLEET_SERVER_CA_TRUSTED_FINGERPRINT
          #   value: "<YOUR_FLEET_SERVER_CA_FINGERPRINT>"
          # Or if you have the CA cert mounted:
          # - name: FLEET_SERVER_CA_PATH
          #   value: "/etc/pki/fleet-server/ca.crt"
        # volumeMounts:
        #   - name: elastic-agent-certs
        #     mountPath: /etc/pki/fleet-server
        #     readOnly: true
      # volumes:
      #   - name: elastic-agent-certs
      #     secret:
      #       secretName: fleet-server-ca-cert # Secret containing the Fleet Server CA certificate




---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: elastic-agent
  namespace: default # Change this to your desired namespace




---
apiVersion: v1
kind: Secret
metadata:
  name: elastic-agent-enrollment-token
  namespace: default # Change this to your desired namespace
type: Opaque
data:
  token: <BASE64_ENCODED_ENROLLMENT_TOKEN> # Replace with your base64 encoded enrollment token


