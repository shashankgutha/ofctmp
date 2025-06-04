apiVersion: operators.elastic.co/v1
kind: Elasticsearch
metadata:
  name: my-es-cluster
  namespace: my-elasticsearch-namespace
spec:
  configuration:
    storage:
      useDynamicProvisioning: true
      storageClassName: my-es-storage-class
      size: "10Gi" # Specify the required storage size
    snapshot_storage:
      useDynamicProvisioning: true
      storageClassName: my-es-snapshot-storage-class
      size: "50Gi" # Specify the required storage size for snapshots
