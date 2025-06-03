{
  "trigger": {
    "schedule": {
      "cron": "0 3 * * *"
    }
  },
  "input": {
    "http": {
      "request": {
        "scheme": "http",
        "host": "localhost",
        "port": 9200,
        "method": "get",
        "path": "/_data_stream/_stats",
        "headers": {
          "Content-Type": "application/json"
        }
      }
    }
  },
  "condition": {
    "script": {
      "source": """
        def smallDataStreams = [];
        def maxSizeBytes = 500; // Delete data streams with size <= 500 bytes
        def minAgeHours = 24; // Only delete if older than 24 hours
        def currentTime = System.currentTimeMillis();
        
        if (ctx.payload.data_streams != null) {
          for (ds in ctx.payload.data_streams) {
            def dsName = ds.data_stream;
            def totalSizeBytes = 0;
            def isOldEnough = false;
            
            // Get store size
            if (ds.total != null && ds.total.store_size_bytes != null) {
              totalSizeBytes = ds.total.store_size_bytes;
            }
            
            // Simple age check using indexing stats
            if (ds.total != null && ds.total.indexing != null) {
              // If indexing time exists, check if it's been quiet for minimum age
              def lastIndexTime = ds.total.indexing.index_time_in_millis;
              if (lastIndexTime != null) {
                def timeSinceLastIndex = currentTime - lastIndexTime;
                if (timeSinceLastIndex > (minAgeHours * 60 * 60 * 1000)) {
                  isOldEnough = true;
                }
              }
            } else {
              // If no indexing stats, assume it's old enough if very small
              if (totalSizeBytes <= 100) {
                isOldEnough = true;
              }
            }
            
            // Skip system data streams
            if (!dsName.startsWith('.') && totalSizeBytes <= maxSizeBytes && isOldEnough) {
              smallDataStreams.add([
                'name': dsName, 
                'size': totalSizeBytes
              ]);
            }
          }
        }
        
        ctx.vars.small_datastreams = smallDataStreams.collect { it.name };
        ctx.vars.datastream_details = smallDataStreams;
        ctx.vars.total_checked = ctx.payload.data_streams != null ? ctx.payload.data_streams.size() : 0;
        return smallDataStreams.size() > 0;
      """
    }
  },
  "actions": {
    "delete_small_datastreams": {
      "foreach": {
        "ctx.vars.small_datastreams": {
          "max_iterations": 50,
          "action": {
            "webhook": {
              "scheme": "http",
              "host": "localhost",
              "port": 9200,
              "method": "delete",
              "path": "/_data_stream/{{ctx.payload}}",
              "headers": {
                "Content-Type": "application/json"
              }
            }
          }
        }
      }
    },
    "log_deleted_datastreams": {
      "logging": {
        "level": "info",
        "text": "Checked {{ctx.vars.total_checked}} data streams. Deleted {{ctx.vars.small_datastreams.size()}} data streams ≤500 bytes: {{ctx.vars.datastream_details}}"
      }
    }
  }
}
