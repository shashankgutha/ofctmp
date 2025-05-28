# Replace <cluster-name> and <namespace> with your actual values
kubectl get secret <cluster-name>-es-http-certs-public -n <namespace> -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout | grep "Not After"

# Check transport certificates too
kubectl get secret <cluster-name>-es-transport-certs -n <namespace> -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout | grep "Not After"
