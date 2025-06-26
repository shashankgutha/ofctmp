## Secret holding Fleet enrollment token
apiVersion: v1
kind: Secret
metadata:
  name: elastic-agent-fleet-token
  namespace: elastic-system
stringData:
  # Replace with your actual enrollment token
  ENROLLMENT_TOKEN: "<YOUR_ENROLLMENT_TOKEN>"
---
## Namespace for Elastic components
apiVersion: v1
kind: Namespace
metadata:
  name: elastic-system
---
## ServiceAccount with minimal privileges
aPIversion: v1
kind: ServiceAccount
metadata:
  name: elastic-agent
  namespace: elastic-system
---
## Role and RoleBinding (optional, adjust per your RBAC needs)
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: elastic-agent-role
  namespace: elastic-system
rules:
  - apiGroups: [""]
    resources: ["pods", "namespaces"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: elastic-agent-binding
  namespace: elastic-system
subjects:
  - kind: ServiceAccount
    name: elastic-agent
    namespace: elastic-system
roleRef:
  kind: Role
  name: elastic-agent-role
  apiGroup: rbac.authorization.k8s.io
---
## Deployment for Elastic Agent in Deployment mode
aPIversion: apps/v1
kind: Deployment
metadata:
  name: elastic-agent
  namespace: elastic-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: elastic-agent
  template:
    metadata:
      labels:
        app: elastic-agent
    spec:
      serviceAccountName: elastic-agent
      containers:
        - name: elastic-agent
          image: docker.elastic.co/beats/elastic-agent:8.10.0
          args:
            - "--deployment-mode=deployment"
            - "--fleet-server-es=http://elasticsearch.elastic-system.svc:9200"
            - "--fleet-server-service-token=$(ENROLLMENT_TOKEN)"
            - "--fleet-server-policy=default"
          env:
            - name: ENROLLMENT_TOKEN
              valueFrom:
                secretKeyRef:
                  name: elastic-agent-fleet-token
                  key: ENROLLMENT_TOKEN
          resources:
            limits:
              memory: 256Mi
              cpu: 200m
            requests:
              memory: 128Mi
              cpu: 100m
          volumeMounts:
            - name: data
              mountPath: /usr/share/elastic-agent/data
      volumes:
        - name: data
          emptyDir: {}
