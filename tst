# First, install the ECK operator
# kubectl create -f https://download.elastic.co/downloads/eck/2.10.0/crds.yaml
# kubectl apply -f https://download.elastic.co/downloads/eck/2.10.0/operator.yaml

---
apiVersion: elasticsearch.k8s.elastic.co/v1
kind: Elasticsearch
metadata:
  name: elasticsearch-cluster
  namespace: elastic-system
spec:
  version: 8.11.0
  
  # Define node sets for the cluster
  nodeSets:
  - name: master-nodes
    count: 3
    config:
      # Master-eligible nodes
      node.roles: ["master", "data", "ingest"]
      # Cluster settings
      cluster.name: elasticsearch-cluster
      network.host: 0.0.0.0
      discovery.seed_hosts: ["elasticsearch-cluster-es-master-nodes-0.elasticsearch-cluster-es-master-nodes.elastic-system.svc.cluster.local", "elasticsearch-cluster-es-master-nodes-1.elasticsearch-cluster-es-master-nodes.elastic-system.svc.cluster.local", "elasticsearch-cluster-es-master-nodes-2.elasticsearch-cluster-es-master-nodes.elastic-system.svc.cluster.local"]
      cluster.initial_master_nodes: ["elasticsearch-cluster-es-master-nodes-0", "elasticsearch-cluster-es-master-nodes-1", "elasticsearch-cluster-es-master-nodes-2"]
      # JVM heap size (adjust based on your medium instance requirements)
      ES_JAVA_OPTS: "-Xms2g -Xmx2g"
    
    podTemplate:
      spec:
        containers:
        - name: elasticsearch
          resources:
            requests:
              memory: 4Gi
              cpu: 1000m
            limits:
              memory: 4Gi
              cpu: 2000m
        # Anti-affinity to ensure nodes are spread across different Kubernetes nodes
        affinity:
          podAntiAffinity:
            requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchLabels:
                  elasticsearch.k8s.elastic.co/cluster-name: elasticsearch-cluster
              topologyKey: kubernetes.io/hostname
    
    volumeClaimTemplates:
    - metadata:
        name: elasticsearch-data
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 100Gi
        storageClassName: fast-ssd  # Adjust based on your storage class

  # HTTP service configuration
  http:
    service:
      spec:
        type: LoadBalancer  # or ClusterIP if you prefer internal access only
        ports:
        - port: 9200
          targetPort: 9200

---
# Optional: Kibana for cluster management
apiVersion: kibana.k8s.elastic.co/v1
kind: Kibana
metadata:
  name: kibana
  namespace: elastic-system
spec:
  version: 8.11.0
  count: 1
  elasticsearchRef:
    name: elasticsearch-cluster
  
  podTemplate:
    spec:
      containers:
      - name: kibana
        resources:
          requests:
            memory: 1Gi
            cpu: 500m
          limits:
            memory: 2Gi
            cpu: 1000m

  http:
    service:
      spec:
        type: LoadBalancer
        ports:
        - port: 5601
          targetPort: 5601

---
# Namespace for the elastic components
apiVersion: v1
kind: Namespace
metadata:
  name: elastic-system
