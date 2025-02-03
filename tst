PUT metrics-test
{
  "mappings": {
    "properties": {
      "@timestamp": { "type": "date" },
      "host": {
        "properties": {
          "name": { "type": "keyword" }
        }
      },
      "status": { "type": "keyword" }
    }
  }
}


POST metrics-test/_bulk
{ "index": {} }
{ "@timestamp": "2024-02-03T12:00:00Z", "host": { "name": "host-1" }, "status": "up" }
{ "index": {} }
{ "@timestamp": "2024-02-03T12:00:00Z", "host": { "name": "host-2" }, "status": "down" }
{ "index": {} }
{ "@timestamp": "2024-02-03T12:00:00Z", "host": { "name": "host-3" }, "status": "up" }
{ "index": {} }
{ "@timestamp": "2024-02-03T12:05:00Z", "host": { "name": "host-1" }, "status": "up" }
{ "index": {} }
{ "@timestamp": "2024-02-03T12:05:00Z", "host": { "name": "host-2" }, "status": "down" }
{ "index": {} }
{ "@timestamp": "2024-02-03T12:05:00Z", "host": { "name": "host-3" }, "status": "up" }
{ "index": {} }
{ "@timestamp": "2024-02-03T12:10:00Z", "host": { "name": "host-1" }, "status": "up" }
{ "index": {} }
{ "@timestamp": "2024-02-03T12:10:00Z", "host": { "name": "host-2" }, "status": "down" }
{ "index": {} }
{ "@timestamp": "2024-02-03T12:10:00Z", "host": { "name": "host-3" }, "status": "up" }
{ "index": {} }
{ "@timestamp": "2024-02-03T12:15:00Z", "host": { "name": "host-1" }, "status": "up" }
{ "index": {} }
{ "@timestamp": "2024-02-03T12:15:00Z", "host": { "name": "host-2" }, "status": "down" }
{ "index": {} }
{ "@timestamp": "2024-02-03T12:15:00Z", "host": { "name": "host-3" }, "status": "up" }
{ "index": {} }
{ "@timestamp": "2024-02-03T12:20:00Z", "host": { "name": "host-1" }, "status": "up" }
{ "index": {} }
{ "@timestamp": "2024-02-03T12:20:00Z", "host": { "name": "host-2" }, "status": "down" }
{ "index": {} }
{ "@timestamp": "2024-02-03T12:20:00Z", "host": { "name": "host-3" }, "status": "up" }
{ "index": {} }
{ "@timestamp": "2024-02-03T12:25:00Z", "host": { "name": "host-1" }, "status": "up" }
{ "index": {} }
{ "@timestamp": "2024-02-03T12:25:00Z", "host": { "name": "host-2" }, "status": "down" }
{ "index": {} }
{ "@timestamp": "2024-02-03T12:25:00Z", "host": { "name": "host-3" }, "status": "up" }
{ "index": {} }
{ "@timestamp": "2024-02-03T12:30:00Z", "host": { "name": "host-1" }, "status": "up" }
{ "index": {} }
{ "@timestamp": "2024-02-03T12:30:00Z", "host": { "name": "host-2" }, "status": "down" }
{ "index": {} }
{ "@timestamp": "2024-02-03T12:30:00Z", "host": { "name": "host-3" }, "status": "up" }


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
            "range": {
              "@timestamp": {
                "gte": "now-30m",
                "lt": "now"
              }
            }
          },
          "aggs": {
            "hosts": {
              "terms": {
                "field": "host.name",
                "size": 2000
              },
              "aggs": {
                "down_count": {
                  "filter": {
                    "term": {
                      "status": "down"
                    }
                  }
                },
                "total_count": {
                  "value_count": {
                    "field": "host.name"
                  }
                },
                "host_down": {
                  "bucket_selector": {
                    "buckets_path": {
                      "down": "down_count._count",
                      "total": "total_count.value"
                    },
                    "script": "params.down == params.total && params.total >= 6"
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
      "source": "return ctx.payload.aggregations.hosts.buckets.size() > 0"
    }
  },
  "actions": {
    "log_to_metadata_index": {
      "index": {
        "index": "host_downtime_metadata",
        "doc_id": "{{ctx.trigger.scheduled_time}}-{{ctx.payload.aggregations.hosts.buckets.0.key}}",
        "body": {
          "down_hosts": "{{ctx.payload.aggregations.hosts.buckets}}",
          "timestamp": "{{ctx.trigger.scheduled_time}}"
        }
      }
    }
  }
}
