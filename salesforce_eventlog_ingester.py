import requests
import time
import logging
import csv
import gzip
import io
import hashlib
from datetime import datetime, timedelta
from elasticsearch import Elasticsearch
from simple_salesforce import Salesforce

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('salesforce_eventlog_ingestion.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class SalesforceEventLogFileIngester:
    def __init__(self, config):
        self.config = config
        self.sf = None
        self.es = None
        
    def get_access_token(self):
        """Get Salesforce access token using JWT Bearer flow"""
        import jwt
        import time
        
        payload = {
            'iss': self.config['client_id'],
            'sub': self.config['username'],
            'aud': self.config.get('auth_url', 'https://login.salesforce.com'),
            'exp': int(time.time()) + 3600
        }
        
        token = jwt.encode(payload, self.config['private_key'], algorithm='RS256')
        
        data = {
            'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
            'assertion': token
        }
        
        response = requests.post(f"{self.config.get('auth_url', 'https://login.salesforce.com')}/services/oauth2/token", data=data)
        
        if response.status_code != 200:
            raise Exception(f'Authentication failed: {response.status_code} - {response.text}')
        
        return response.json()

    def connect_to_salesforce(self):
        """Establish connection to Salesforce"""
        try:
            auth_response = self.get_access_token()
            access_token = auth_response['access_token']
            instance_url = auth_response['instance_url']
            
            self.sf = Salesforce(instance_url=instance_url, session_id=access_token)
            logger.info(f"Connected to Salesforce instance: {instance_url}")
            return True
            
        except Exception as e:
            logger.error(f"Error connecting to Salesforce: {e}")
            return False

    def setup_elasticsearch(self):
        """Setup Elasticsearch connection"""
        try:
            self.es = Elasticsearch([self.config['es_host']])
            
            if not self.es.ping():
                raise Exception("Cannot connect to Elasticsearch")
            
            # Create index mapping for EventLogFile data
            mapping = {
                "mappings": {
                    "properties": {
                        # EventLogFile metadata
                        "EventLogFile_Id": {"type": "keyword"},
                        "EventType": {"type": "keyword"},
                        "LogDate": {"type": "date"},
                        "LogFileLength": {"type": "long"},
                        "Sequence": {"type": "long"},
                        "Interval": {"type": "keyword"},
                        
                        # Common event fields (will vary by EventType)
                        "EVENT_TYPE": {"type": "keyword"},
                        "TIMESTAMP": {"type": "date"},
                        "REQUEST_ID": {"type": "keyword"},
                        "ORGANIZATION_ID": {"type": "keyword"},
                        "USER_ID": {"type": "keyword"},
                        "USER_NAME": {"type": "text", "fields": {"keyword": {"type": "keyword"}}},
                        "RUN_TIME": {"type": "float"},
                        "CPU_TIME": {"type": "float"},
                        "URI": {"type": "text"},
                        "SESSION_KEY": {"type": "keyword"},
                        "LOGIN_KEY": {"type": "keyword"},
                        "REQUEST_STATUS": {"type": "keyword"},
                        "DB_TOTAL_TIME": {"type": "float"},
                        "BROWSER_TYPE": {"type": "text"},
                        "API_TYPE": {"type": "keyword"},
                        "API_VERSION": {"type": "keyword"},
                        "USER_TYPE": {"type": "keyword"},
                        "LICENSE_TYPE": {"type": "keyword"},
                        "CLIENT_IP": {"type": "ip"},
                        "URI_ID_DERIVED": {"type": "keyword"},
                        "REFERRER_URI": {"type": "text"},
                        "METHOD": {"type": "keyword"},
                        "STATUS": {"type": "keyword"},
                        "BYTES": {"type": "long"},
                        "REFERER": {"type": "text"},
                        "USER_AGENT": {"type": "text"},
                        
                        # Login specific fields
                        "LOGIN_TYPE": {"type": "keyword"},
                        "SOURCE_IP": {"type": "ip"},
                        "LOGIN_STATUS": {"type": "keyword"},
                        "BROWSER_NAME": {"type": "text"},
                        "PLATFORM": {"type": "text"},
                        "APPLICATION": {"type": "text"},
                        "CLIENT_VERSION": {"type": "text"},
                        "OS_NAME": {"type": "text"},
                        "OS_VERSION": {"type": "text"},
                        "COUNTRY_ISO": {"type": "keyword"},
                        "AUTH_METHOD_REFERENCE": {"type": "text"},
                        
                        # Logout specific fields
                        "SESSION_TYPE": {"type": "keyword"},
                        "SESSION_LEVEL": {"type": "keyword"},
                        
                        # Metadata
                        "ingestion_timestamp": {"type": "date"},
                        "log_file_processed": {"type": "keyword"}
                    }
                }
            }
            
            # Data streams are created automatically when needed
            logger.info("Elasticsearch connection established - data streams will be created automatically")
            return True
            
        except Exception as e:
            logger.error(f"Error setting up Elasticsearch: {e}")
            return False

    def get_latest_sync_timestamp_from_es(self):
        """Retrieve latest LogDate from Elasticsearch data streams"""
        try:
            # Query for the latest LogDate across all Salesforce data streams
            response = self.es.search(
                index="sg-salesforce-*",
                body={
                    "size": 1,
                    "sort": [{"LogDate": {"order": "desc"}}],
                    "_source": ["LogDate"]
                }
            )
            
            hits = response.get('hits', {}).get('hits', [])
            if hits:
                latest_time_str = hits[0]['_source']['LogDate']
                # Handle different datetime formats that might be in ES
                try:
                    if latest_time_str.endswith('Z'):
                        latest_time = datetime.fromisoformat(latest_time_str.replace('Z', '+00:00'))
                    else:
                        latest_time = datetime.fromisoformat(latest_time_str)
                except:
                    # Fallback parsing
                    latest_time = datetime.strptime(latest_time_str, '%Y-%m-%dT%H:%M:%S.%f%z')
                
                logger.info(f"Latest LogDate found in ES: {latest_time}")
                return latest_time
            else:
                logger.info("No existing records found in Elasticsearch index")
                return None
                
        except Exception as e:
            if "index_not_found_exception" in str(e):
                logger.info("Elasticsearch index doesn't exist yet")
                return None
            else:
                logger.error(f"Error retrieving latest sync timestamp from ES: {e}")
                return None

    def get_fallback_timestamp(self):
        """Get fallback timestamp when no data exists in ES"""
        fallback_hours = self.config.get('initial_lookback_hours', 24)
        fallback_time = datetime.now() - timedelta(hours=fallback_hours)
        logger.info(f"Using fallback timestamp: {fallback_time} ({fallback_hours} hours ago)")
        return fallback_time

    def fetch_eventlog_files(self):
        """Fetch EventLogFile records since last sync"""
        try:
            # Get the latest timestamp from Elasticsearch
            last_sync = self.get_latest_sync_timestamp_from_es()
            
            # If no records exist, use fallback
            if last_sync is None:
                last_sync = self.get_fallback_timestamp()
            else:
                # Add a small buffer (1 hour) to avoid missing records
                last_sync = last_sync + timedelta(hours=1)
            
            # Format datetime for SOQL query (Salesforce expects UTC)
            last_sync_str = last_sync.strftime('%Y-%m-%dT%H:%M:%S.000Z')
            
            # Get event types to process
            event_types = self.config.get('event_types', ['API', 'Login', 'Logout', 'URI'])
            event_types_str = "', '".join(event_types)
            
            query = f"""
            SELECT Id, EventType, LogDate, LogFile, LogFileLength, 
                   LogFileFieldNames, LogFileFieldTypes, Sequence, Interval
            FROM EventLogFile 
            WHERE LogDate >= {last_sync_str}
            AND EventType IN ('{event_types_str}')
            ORDER BY LogDate ASC, EventType ASC
            LIMIT {self.config.get('batch_size', 100)}
            """
            
            logger.info(f"Fetching EventLogFile records since: {last_sync_str}")
            logger.info(f"Event types: {event_types}")
            
            result = self.sf.query_all(query)
            records = result['records']
            
            logger.info(f"Retrieved {len(records)} EventLogFile records")
            return records
            
        except Exception as e:
            logger.error(f"Error fetching EventLogFile data: {e}")
            return []

    def download_and_parse_logfile(self, eventlog_record):
        """Download and parse the CSV content from EventLogFile"""
        try:
            log_file_id = eventlog_record['Id']
            event_type = eventlog_record['EventType']
            log_date = eventlog_record['LogDate']
            
            logger.info(f"Processing EventLogFile: {log_file_id} ({event_type}) from {log_date}")
            
            # Get the LogFile URL path - this contains a reference to download the actual log file
            log_file_url = eventlog_record.get('LogFile')
            if not log_file_url:
                logger.warning(f"No LogFile URL for {log_file_id}")
                return []
            
            # Download the actual log file content using REST API
            # Construct the full URL for downloading the log file
            download_url = f"{self.sf.base_url}sobjects/EventLogFile/{log_file_id}/LogFile"
            
            # Make authenticated request to download the file
            headers = {
                'Authorization': f'Bearer {self.sf.session_id}',
                'Accept-Encoding': 'gzip'
            }
            
            response = requests.get(download_url, headers=headers)
            response.raise_for_status()
            
            # The response content is gzipped CSV data
            decoded_content = response.content
            
            # Check if content is gzipped and decompress if needed
            if decoded_content.startswith(b'\x1f\x8b'):  # gzip magic number
                csv_content = gzip.decompress(decoded_content).decode('utf-8')
            else:
                csv_content = decoded_content.decode('utf-8')
            
            # Parse CSV content
            csv_reader = csv.DictReader(io.StringIO(csv_content))
            parsed_records = []
            
            for row in csv_reader:
                # Add EventLogFile metadata to each record
                enriched_record = {
                    'EventLogFile_Id': log_file_id,
                    'EventType': event_type,
                    'LogDate': log_date,
                    'LogFileLength': eventlog_record.get('LogFileLength'),
                    'Sequence': eventlog_record.get('Sequence'),
                    'Interval': eventlog_record.get('Interval'),
                    'ingestion_timestamp': datetime.now().isoformat(),
                    'log_file_processed': f"{log_file_id}_{event_type}"
                }
                
                # Add all CSV fields to the record
                enriched_record.update(row)
                
                # Convert timestamp fields to proper format
                self._convert_timestamp_fields(enriched_record)
                
                parsed_records.append(enriched_record)
            
            logger.info(f"Parsed {len(parsed_records)} records from EventLogFile {log_file_id}")
            return parsed_records
            
        except Exception as e:
            logger.error(f"Error processing EventLogFile {eventlog_record.get('Id', 'unknown')}: {e}")
            return []

    def _convert_timestamp_fields(self, record):
        """Convert timestamp fields to proper datetime format"""
        timestamp_fields = ['TIMESTAMP', 'LOGIN_TIME', 'LOGOUT_TIME']
        
        for field in timestamp_fields:
            if field in record and record[field]:
                try:
                    # Salesforce timestamps are typically in format: 20231201123045.123
                    timestamp_str = record[field]
                    if len(timestamp_str) >= 14:  # YYYYMMDDHHMMSS
                        # Parse the timestamp
                        dt = datetime.strptime(timestamp_str[:14], '%Y%m%d%H%M%S')
                        # Add milliseconds if present
                        if len(timestamp_str) > 15 and '.' in timestamp_str:
                            ms_part = timestamp_str.split('.')[1][:3]  # Take first 3 digits
                            dt = dt.replace(microsecond=int(ms_part.ljust(6, '0')))
                        
                        record[field] = dt.isoformat()
                except Exception as e:
                    logger.warning(f"Could not parse timestamp field {field}: {record[field]} - {e}")

    def bulk_ingest_to_elasticsearch(self, records):
        """Bulk ingest records to Elasticsearch data streams based on event type"""
        if not records:
            return 0
            
        try:
            from elasticsearch.helpers import bulk
            
            actions = []
            data_streams_used = set()
            
            # Process each record directly
            for i, record in enumerate(records):
                # Generate data stream name based on event type
                event_type = record.get('EventType', 'unknown').lower()
                data_stream_name = f"sg-salesforce-{event_type}"
                
                # Track data streams used
                data_streams_used.add(data_stream_name)
                
                # Create unique hash-based document ID
                hash_input = f"{record['EventLogFile_Id']}_{record.get('REQUEST_ID', '')}_{record.get('TIMESTAMP', '')}_{i}"
                doc_id = hashlib.sha256(hash_input.encode('utf-8')).hexdigest()[:16]
                
                action = {
                    "_index": data_stream_name,
                    "_id": doc_id,
                    "_source": record
                }
                actions.append(action)
            
            # Ensure all required data streams exist
            for data_stream_name in data_streams_used:
                self._ensure_data_stream_exists(data_stream_name)
            
            # Perform bulk insert for all records
            success, failed = bulk(self.es, actions, chunk_size=500, request_timeout=60)
            failed_count = len(failed) if failed else 0
            
            logger.info(f"Bulk ingested {success} records across {len(data_streams_used)} data streams: {', '.join(sorted(data_streams_used))}")
            if failed_count > 0:
                logger.warning(f"Failed to ingest {failed_count} records")
            
            return success
            
        except Exception as e:
            logger.error(f"Error during bulk ingestion: {e}")
            return 0

    def _ensure_data_stream_exists(self, data_stream_name):
        """Ensure data stream exists, create if it doesn't"""
        try:
            # Check if data stream exists
            if self.es.indices.exists_data_stream(name=data_stream_name):
                logger.debug(f"Data stream {data_stream_name} already exists")
                return True
            
            # Create data stream with basic template
            template_name = f"{data_stream_name}-template"
            
            # Create index template for the data stream
            template_body = {
                "index_patterns": [f"{data_stream_name}*"],
                "data_stream": {},
                "template": {
                    "settings": {
                        "number_of_shards": 1,
                        "number_of_replicas": 0
                    },
                    "mappings": {
                        "properties": {
                            "@timestamp": {
                                "type": "date"
                            },
                            "TIMESTAMP": {
                                "type": "date",
                                "format": "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'||yyyy-MM-dd'T'HH:mm:ss'Z'||epoch_millis"
                            },
                            "EventType": {
                                "type": "keyword"
                            },
                            "EVENT_TYPE": {
                                "type": "keyword"
                            },
                            "USER_ID": {
                                "type": "keyword"
                            },
                            "ORGANIZATION_ID": {
                                "type": "keyword"
                            }
                        }
                    }
                },
                "priority": 100
            }
            
            # Create the index template
            self.es.indices.put_index_template(name=template_name, body=template_body)
            logger.info(f"Created index template {template_name}")
            
            # Create the data stream
            self.es.indices.create_data_stream(name=data_stream_name)
            logger.info(f"Created data stream {data_stream_name}")
            
            return True
            
        except Exception as e:
            logger.error(f"Error ensuring data stream {data_stream_name} exists: {e}")
            return False

    def get_index_stats(self):
        """Get statistics about Salesforce data streams"""
        try:
            # Get all data streams matching the Salesforce pattern
            data_streams = self.es.indices.get_data_stream(name="sg-salesforce-*")
            
            total_docs = 0
            total_size_bytes = 0
            
            logger.info("Data Stream Statistics:")
            
            for ds_name, ds_info in data_streams['data_streams'].items():
                try:
                    # Get stats for this data stream
                    stats = self.es.indices.stats(index=ds_name)
                    
                    if ds_name in stats['indices']:
                        doc_count = stats['indices'][ds_name]['total']['docs']['count']
                        size_bytes = stats['indices'][ds_name]['total']['store']['size_in_bytes']
                        size_mb = size_bytes / (1024 * 1024)
                        
                        total_docs += doc_count
                        total_size_bytes += size_bytes
                        
                        logger.info(f"  {ds_name}: {doc_count:,} docs, {size_mb:.2f} MB")
                        
                except Exception as ds_error:
                    logger.warning(f"Could not get stats for data stream {ds_name}: {ds_error}")
            
            total_size_mb = total_size_bytes / (1024 * 1024)
            logger.info(f"Total across all Salesforce data streams: {total_docs:,} docs, {total_size_mb:.2f} MB")
            
        except Exception as e:
            logger.warning(f"Could not retrieve data stream stats: {e}")

    def run_single_sync(self):
        """Run a single synchronization cycle"""
        try:
            # Reconnect to Salesforce if needed (token might expire)
            if not self.sf or not self.connect_to_salesforce():
                logger.error("Failed to connect to Salesforce")
                return False
            
            # Fetch EventLogFile records
            eventlog_files = self.fetch_eventlog_files()
            
            if eventlog_files:
                total_ingested = 0
                
                for eventlog_file in eventlog_files:
                    # Download and parse each EventLogFile
                    parsed_records = self.download_and_parse_logfile(eventlog_file)
                    
                    if parsed_records:
                        # Ingest to Elasticsearch
                        ingested_count = self.bulk_ingest_to_elasticsearch(parsed_records)
                        total_ingested += ingested_count
                
                logger.info(f"Sync completed: {total_ingested} total records ingested from {len(eventlog_files)} EventLogFiles")
                
                # Show index stats after ingestion
                self.get_index_stats()
            else:
                logger.info("No new EventLogFiles to sync")
            
            return True
            
        except Exception as e:
            logger.error(f"Error during sync cycle: {e}")
            return False

    def run_continuous(self):
        """Run continuous ingestion"""
        logger.info("Starting continuous Salesforce EventLogFile ingestion...")
        
        # Initial setup
        if not self.setup_elasticsearch():
            logger.error("Failed to setup Elasticsearch. Exiting.")
            return
        
        sync_interval = self.config.get('sync_interval_minutes', 60)  # Default 1 hour for EventLogFiles
        max_retries = self.config.get('max_retries', 3)
        
        # Show initial index stats
        self.get_index_stats()
        
        while True:
            try:
                logger.info(f"Starting sync cycle...")
                
                retry_count = 0
                success = False
                
                while retry_count < max_retries and not success:
                    success = self.run_single_sync()
                    if not success:
                        retry_count += 1
                        if retry_count < max_retries:
                            logger.warning(f"Sync failed, retrying in 10 minutes... (attempt {retry_count}/{max_retries})")
                            time.sleep(600)  # Wait 10 minutes before retry
                
                if not success:
                    logger.error(f"Sync failed after {max_retries} attempts")
                
                logger.info(f"Waiting {sync_interval} minutes until next sync...")
                time.sleep(sync_interval * 60)
                
            except KeyboardInterrupt:
                logger.info("Received interrupt signal. Stopping continuous ingestion...")
                break
            except Exception as e:
                logger.error(f"Unexpected error in continuous loop: {e}")
                logger.info("Waiting 15 minutes before retrying...")
                time.sleep(900)

def main():
    """Main function"""
    # Configuration
    CONFIG = {
        'client_id': 'YOUR_CLIENT_ID_HERE',
        'private_key': '''-----BEGIN PRIVATE KEY-----
YOUR_PRIVATE_KEY_CONTENT_HERE
-----END PRIVATE KEY-----''',
        'username': 'your.username@example.com',
        'auth_url': 'https://login.salesforce.com',  # Use https://test.salesforce.com for sandbox
        'es_host': 'http://localhost:9200',
        # Data streams are automatically created based on event types
        'sync_interval_minutes': 60,            # Sync every hour (EventLogFiles are generated hourly)
        'batch_size': 100,                      # Max EventLogFiles per sync
        'max_retries': 3,                       # Max retry attempts per sync
        'initial_lookback_hours': 24,           # How far back to look on first run (hours)
        'event_types': ['API', 'Login', 'Logout', 'URI']  # EventLogFile types to process
    }
    
    # Create and run ingester
    ingester = SalesforceEventLogFileIngester(CONFIG)
    ingester.run_continuous()

if __name__ == "__main__":
    main()
