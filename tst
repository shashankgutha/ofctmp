input {
  http_poller {
    urls => {
      salesforce_query => {
        # Replace <instance> and adjust the API version as needed.
        url => "https://<instance>.salesforce.com/services/data/v54.0/query/?q=SELECT+Id,EventType,LogDate,LogFile+FROM+EventLogFile+WHERE+EventType+IN+('Login','Logout','Apex')"
        headers => {
          "Authorization" => "Bearer YOUR_ACCESS_TOKEN"
        }
      }
    }
    # Poll every 60 minutes (adjust schedule as required)
    schedule => { cron => "0 0 * * * ?" }
    codec => "json"
  }
}
filter {
  # Split the records array so each event is processed individually.
  split {
    field => "records"
  }

  ruby {
    code => "
      require 'net/http'
      require 'uri'
      # Get the Salesforce instance URL and access token (could be set as Logstash environment variables)
      instance_url = 'https://<instance>.salesforce.com'
      access_token = 'YOUR_ACCESS_TOKEN'  # Consider using environment variables for security

      # Check if the current event contains the 'LogFile' field
      log_file_rel_url = event.get('records')['LogFile']
      if log_file_rel_url
        # Construct the full URL
        full_url = instance_url + log_file_rel_url
        uri = URI.parse(full_url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        request = Net::HTTP::Get.new(uri.request_uri)
        request['Authorization'] = 'Bearer ' + access_token
        response = http.request(request)
        if response.code.to_i == 200
          event.set('log_file_contents', response.body)
        else
          event.set('log_file_contents', 'HTTP error: ' + response.code)
        end
      else
        event.tag('no_logfile_url')
      end
    "
  }
}
output {
  elasticsearch {
    hosts => ["http://localhost:9200"]
    index => "salesforce-logs-%{+YYYY.MM.dd}"
  }
  stdout { codec => rubydebug }
}
