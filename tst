// First, create the metrics index with mapping
PUT metrics-2024.02
{
  "mappings": {
    "properties": {
      "@timestamp": { "type": "date" },
      "host": {
        "properties": {
          "name": { "type": "keyword" }
        }
      },
      "status": {
        "properties": {
          "up": { "type": "integer" }
        }
      }
    }
  }
}

// Create the alerts index
PUT host-downtime-alerts
{
  "mappings": {
    "properties": {
      "host": { "type": "keyword" },
      "detection_time": { "type": "date" },
      "downtime_duration": { "type": "keyword" },
      "alert_timestamp": { "type": "date" }
    }
  }
}

// Insert sample metrics data (using _bulk API)
POST _bulk
{ "index": { "_index": "metrics-2024.02" }}
{ "@timestamp": "2024-02-03T10:00:00Z", "host": { "name": "server1" }, "status": { "up": 0 }}
{ "index": { "_index": "metrics-2024.02" }}
{ "@timestamp": "2024-02-03T10:05:00Z", "host": { "name": "server1" }, "status": { "up": 0 }}
{ "index": { "_index": "metrics-2024.02" }}
{ "@timestamp": "2024-02-03T10:10:00Z", "host": { "name": "server1" }, "status": { "up": 0 }}
{ "index": { "_index": "metrics-2024.02" }}
{ "@timestamp": "2024-02-03T10:15:00Z", "host": { "name": "server1" }, "status": { "up": 0 }}
{ "index": { "_index": "metrics-2024.02" }}
{ "@timestamp": "2024-02-03T10:20:00Z", "host": { "name": "server1" }, "status": { "up": 0 }}
{ "index": { "_index": "metrics-2024.02" }}
{ "@timestamp": "2024-02-03T10:25:00Z", "host": { "name": "server1" }, "status": { "up": 0 }}
{ "index": { "_index": "metrics-2024.02" }}
{ "@timestamp": "2024-02-03T10:00:00Z", "host": { "name": "server2" }, "status": { "up": 0 }}
{ "index": { "_index": "metrics-2024.02" }}
{ "@timestamp": "2024-02-03T10:05:00Z", "host": { "name": "server2" }, "status": { "up": 1 }}
{ "index": { "_index": "metrics-2024.02" }}
{ "@timestamp": "2024-02-03T10:10:00Z", "host": { "name": "server2" }, "status": { "up": 0 }}
{ "index": { "_index": "metrics-2024.02" }}
{ "@timestamp": "2024-02-03T10:15:00Z", "host": { "name": "server2" }, "status": { "up": 0 }}
{ "index": { "_index": "metrics-2024.02" }}
{ "@timestamp": "2024-02-03T10:20:00Z", "host": { "name": "server2" }, "status": { "up": 0 }}
{ "index": { "_index": "metrics-2024.02" }}
{ "@timestamp": "2024-02-03T10:25:00Z", "host": { "name": "server2" }, "status": { "up": 0 }}
{ "index": { "_index": "metrics-2024.02" }}
{ "@timestamp": "2024-02-03T10:00:00Z", "host": { "name": "server3" }, "status": { "up": 0 }}
{ "index": { "_index": "metrics-2024.02" }}
{ "@timestamp": "2024-02-03T10:05:00Z", "host": { "name": "server3" }, "status": { "up": 0 }}
{ "index": { "_index": "metrics-2024.02" }}
{ "@timestamp": "2024-02-03T10:10:00Z", "host": { "name": "server3" }, "status": { "up": 0 }}
{ "index": { "_index": "metrics-2024.02" }}
{ "@timestamp": "2024-02-03T10:15:00Z", "host": { "name": "server3" }, "status": { "up": 0 }}
{ "index": { "_index": "metrics-2024.02" }}
{ "@timestamp": "2024-02-03T10:20:00Z", "host": { "name": "server3" }, "status": { "up": 0 }}
{ "index": { "_index": "metrics-2024.02" }}
{ "@timestamp": "2024-02-03T10:25:00Z", "host": { "name": "server3" }, "status": { "up": 0 }}


{
  "trigger": {
    "schedule": {
      "interval": "5m"
    }
  },
  "input": {
    "search": {
      "request": {
        "indices": ["metrics-*"],
        "body": {
          "size": 0,
          "query": {
            "bool": {
              "must": [
                {
                  "range": {
                    "@timestamp": {
                      "gte": "now-30m",
                      "lte": "now"
                    }
                  }
                }
              ]
            }
          },
          "aggs": {
            "hosts": {
              "terms": {
                "field": "host.name",
                "size": 3000
              },
              "aggs": {
                "downtime_check": {
                  "stats": {
                    "field": "status.up"
                  }
                },
                "time_periods": {
                  "date_histogram": {
                    "field": "@timestamp",
                    "fixed_interval": "5m"
                  },
                  "aggs": {
                    "status": {
                      "avg": {
                        "field": "status.up"
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  },
  "condition": {
    "script": {
      "source": """
        def hosts = ctx.payload.aggregations.hosts.buckets;
        def downHosts = [];
        
        for (host in hosts) {
          def periods = host.time_periods.buckets;
          if (periods.size() == 6) {  // Should have 6 5-minute periods in 30 minutes
            boolean allDown = true;
            for (period in periods) {
              if (period.status.value > 0) {
                allDown = false;
                break;
              }
            }
            if (allDown) {
              downHosts.add(host.key);
            }
          }
        }
        
        return downHosts.size() > 0;
      """
    }
  },
  "transform": {
    "script": {
      "source": """
        def downHosts = [];
        def hosts = ctx.payload.aggregations.hosts.buckets;
        
        for (host in hosts) {
          def periods = host.time_periods.buckets;
          if (periods.size() == 6) {
            boolean allDown = true;
            for (period in periods) {
              if (period.status.value > 0) {
                allDown = false;
                break;
              }
            }
            if (allDown) {
              downHosts.add([
                "host": host.key,
                "detection_time": ctx.execution_time,
                "downtime_duration": "30m"
              ]);
            }
          }
        }
        
        return [ "down_hosts": downHosts ];
      """
    }
  },
  "actions": {
    "index_record": {
      "index": {
        "index": "host-downtime-alerts"
      },
      "body": {
        "script": {
          "source": """
            for (host in ctx.payload.down_hosts) {
              def doc = [
                "host": host.host,
                "detection_time": host.detection_time,
                "downtime_duration": host.downtime_duration,
                "alert_timestamp": ctx.execution_time
              ];
              ctx.index(doc);
            }
          """
        }
      }
    }
  }
}
