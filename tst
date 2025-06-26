apiVersion: v1
kind: ServiceAccount
metadata:
  name: elastic-agent
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: elastic-agent
rules:
- apiGroups: [""]
  resources:
    - nodes
    - namespaces
    - events
    - pods
    - services
    - configmaps
    - persistentvolumes
    - persistentvolumeclaims
  verbs: ["get", "list", "watch"]
- apiGroups: ["extensions"]
  resources:
    - replicasets
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources:
    - statefulsets
    - deployments
    - replicasets
  verbs: ["get", "list", "watch"]
- apiGroups: ["batch"]
  resources:
    - jobs
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: elastic-agent
subjects:
- kind: ServiceAccount
  name: elastic-agent
  namespace: default
roleRef:
  kind: ClusterRole
  name: elastic-agent
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: v1
kind: Secret
metadata:
  name: elastic-agent-secret
  namespace: default
type: Opaque
stringData:
  enrollment-token: "YOUR_ENROLLMENT_TOKEN_HERE"
  fleet-url: "https://fleet-server:8220"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: elastic-agent
  namespace: default
  labels:
    app: elastic-agent
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
        image: docker.elastic.co/beats/elastic-agent:8.11.0
        env:
        - name: FLEET_ENROLLMENT_TOKEN
          valueFrom:
            secretKeyRef:
              name: elastic-agent-secret
              key: enrollment-token
        - name: FLEET_URL
          valueFrom:
            secretKeyRef:
              name: elastic-agent-secret
              key: fleet-url
        - name: FLEET_ENROLL
          value: "1"
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        resources:
          limits:
            memory: 500Mi
          requests:
            cpu: 100m
            memory: 200Mi
        volumeMounts:
        - name: agent-data
          mountPath: /usr/share/elastic-agent/data
      volumes:
      - name: agent-data
        emptyDir: {}
