PUT _watcher/watch/testwatcher
{
  "trigger": {
    "schedule": {
      "interval": "5m"
    }
  },
  "input": {
    "search": {
      "request": {
        "indices": ["inframetrics-*"],
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
          if (periods.size() >= 1) {
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
          if (periods.size() >= 1) {
            boolean allDown = true;
            for (period in periods) {
              if (period.status.value > 0) {
                allDown = false;
                break;
              }
            }
            if (allDown) {
              downHosts.add([
                "id": host.key + "-" + ctx.execution_time,
                "body": [
                  "host": host.key,
                  "detection_time": ctx.execution_time,
                  "downtime_duration": "30m",
                  "alert_timestamp": ctx.execution_time
                ]
              ]);
            }
          }
        }
        return [ "alerts": downHosts ];
      """
    }
  },
  "actions": {
    "index_payload": {
      "foreach": "ctx.payload.alerts",
      "index": {
        "index": "host-downtime-alerts"
      }
    }
  }
}




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


PUT inframetrics-poc
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


GET host-downtime-alerts/_search
{
  "query": {
    "match_all": {}
  }
}

POST _watcher/watch/testwatcher/_execute


POST _bulk
{ "index": { "_index": "inframetrics-poc" }}
{ "@timestamp": "2025-02-03T10:00:00Z", "host": { "name": "server1" }, "status": { "up": 0 }}
{ "index": { "_index": "inframetrics-poc" }}
{ "@timestamp": "2025-02-03T10:05:00Z", "host": { "name": "server1" }, "status": { "up": 0 }}
{ "index": { "_index": "inframetrics-poc" }}
{ "@timestamp": "2025-02-03T10:10:00Z", "host": { "name": "server1" }, "status": { "up": 0 }}
{ "index": { "_index": "inframetrics-poc" }}
{ "@timestamp": "2025-02-03T10:15:00Z", "host": { "name": "server1" }, "status": { "up": 0 }}
{ "index": { "_index": "inframetrics-poc" }}
{ "@timestamp": "2025-02-03T10:20:00Z", "host": { "name": "server1" }, "status": { "up": 0 }}
{ "index": { "_index": "inframetrics-poc" }}
{ "@timestamp": "2025-02-03T10:25:00Z", "host": { "name": "server1" }, "status": { "up": 0 }}
{ "index": { "_index": "inframetrics-poc" }}
{ "@timestamp": "2025-02-03T10:00:00Z", "host": { "name": "server2" }, "status": { "up": 0 }}
{ "index": { "_index": "inframetrics-poc" }}
{ "@timestamp": "2025-02-03T10:05:00Z", "host": { "name": "server2" }, "status": { "up": 1 }}
{ "index": { "_index": "inframetrics-poc" }}
{ "@timestamp": "2025-02-03T10:10:00Z", "host": { "name": "server2" }, "status": { "up": 0 }}
{ "index": { "_index": "inframetrics-poc" }}
{ "@timestamp": "2025-02-03T10:15:00Z", "host": { "name": "server2" }, "status": { "up": 0 }}
{ "index": { "_index": "inframetrics-poc" }}
{ "@timestamp": "2025-02-03T10:20:00Z", "host": { "name": "server2" }, "status": { "up": 0 }}
{ "index": { "_index": "inframetrics-poc" }}
{ "@timestamp": "2025-02-03T10:25:00Z", "host": { "name": "server2" }, "status": { "up": 0 }}
{ "index": { "_index": "inframetrics-poc" }}
{ "@timestamp": "2025-02-03T10:00:00Z", "host": { "name": "server3" }, "status": { "up": 0 }}
{ "index": { "_index": "inframetrics-poc" }}
{ "@timestamp": "2025-02-03T10:05:00Z", "host": { "name": "server3" }, "status": { "up": 0 }}
{ "index": { "_index": "inframetrics-poc" }}
{ "@timestamp": "2025-02-03T10:10:00Z", "host": { "name": "server3" }, "status": { "up": 0 }}
{ "index": { "_index": "inframetrics-poc" }}
{ "@timestamp": "2025-02-03T10:15:00Z", "host": { "name": "server3" }, "status": { "up": 0 }}
{ "index": { "_index": "inframetrics-poc" }}
{ "@timestamp": "2025-02-03T10:20:00Z", "host": { "name": "server3" }, "status": { "up": 0 }}
{ "index": { "_index": "inframetrics-poc" }}
{ "@timestamp": "2025-02-03T10:25:00Z", "host": { "name": "server3" }, "status": { "up": 0 }}
