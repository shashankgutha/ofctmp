kubectl run elastic-agent \
  --image=docker.elastic.co/elastic-agent/elastic-agent:8.17.3 \
  --env="FLEET_ENROLL=1" \
  --env="FLEET_INSECURE=true" \
  --env="FLEET_URL=http://fleet-svc.es-fleet:80" \
  --env="FLEET_ENROLLMENT_TOKEN=xxxxxxx" \
  --restart=Always
