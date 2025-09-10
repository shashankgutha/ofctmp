import requests
import time
import logging
from datetime import datetime, timedelta
from elasticsearch import Elasticsearch
from simple_salesforce import Salesforce

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('salesforce_ingestion.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class SalesforceLoginHistoryIngester:
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
            
            # Create index mapping
            mapping = {
                "mappings": {
                    "properties": {
                        "Id": {"type": "keyword"},
                        "UserId": {"type": "keyword"},
                        "LoginTime": {"type": "date"},
                        "LoginType": {"type": "keyword"},
                        "SourceIp": {"type": "ip"},
                        "Status": {"type": "keyword"},
                        "Platform": {"type": "text"},
                        "Application": {"type": "text"},
                        "Browser": {"type": "text"},
                        "ApiType": {"type": "keyword"},
                        "ApiVersion": {"type": "keyword"},
                        "ClientVersion": {"type": "text"},
                        "CountryIso": {"type": "keyword"},
                        "LoginGeoId": {"type": "keyword"},
                        "LoginUrl": {"type": "text"},
                        "NetworkId": {"type": "keyword"},
                        "AuthenticationMethodReference": {"type": "text"},
                        "ingestion_timestamp": {"type": "date"}
                    }
                }
            }
            
            if not self.es.indices.exists(index=self.config['es_index']):
                self.es.indices.create(index=self.config['es_index'], body=mapping)
                logger.info(f"Created Elasticsearch index: {self.config['es_index']}")
            
            return True
            
        except Exception as e:
            logger.error(f"Error setting up Elasticsearch: {e}")
            return False

    def get_latest_sync_timestamp_from_es(self):
        """Retrieve latest LoginTime from Elasticsearch index"""
        try:
            # Query for the latest LoginTime in the index
            response = self.es.search(
                index=self.config['es_index'],
                body={
                    "size": 1,
                    "sort": [{"LoginTime": {"order": "desc"}}],
                    "_source": ["LoginTime"]
                }
            )
            
            hits = response.get('hits', {}).get('hits', [])
            if hits:
                latest_time_str = hits[0]['_source']['LoginTime']
                # Handle different datetime formats that might be in ES
                try:
                    if latest_time_str.endswith('Z'):
                        latest_time = datetime.fromisoformat(latest_time_str.replace('Z', '+00:00'))
                    else:
                        latest_time = datetime.fromisoformat(latest_time_str)
                except:
                    # Fallback parsing
                    latest_time = datetime.strptime(latest_time_str, '%Y-%m-%dT%H:%M:%S.%f%z')
                
                logger.info(f"Latest LoginTime found in ES: {latest_time}")
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

    def fetch_incremental_data(self):
        """Fetch incremental LoginHistory data since last record in ES"""
        try:
            # Get the latest timestamp from Elasticsearch
            last_sync = self.get_latest_sync_timestamp_from_es()
            
            # If no records exist, use fallback
            if last_sync is None:
                last_sync = self.get_fallback_timestamp()
            else:
                # Add a small buffer (1 second) to avoid missing records with the same timestamp
                last_sync = last_sync + timedelta(seconds=1)
            
            # Format datetime for SOQL query (Salesforce expects UTC)
            last_sync_str = last_sync.strftime('%Y-%m-%dT%H:%M:%S.000Z')
            
            query = f"""
            SELECT Id, UserId, LoginTime, LoginType, SourceIp, Status, 
                   Platform, Application, Browser, ApiType, ApiVersion,
                   ClientVersion, CountryIso, LoginGeoId, LoginUrl,
                   NetworkId, AuthenticationMethodReference
            FROM LoginHistory 
            WHERE LoginTime >= {last_sync_str}
            ORDER BY LoginTime ASC
            LIMIT {self.config.get('batch_size', 2000)}
            """
            
            logger.info(f"Fetching LoginHistory records since: {last_sync_str}")
            result = self.sf.query_all(query)
            records = result['records']
            
            logger.info(f"Retrieved {len(records)} new LoginHistory records")
            return records
            
        except Exception as e:
            logger.error(f"Error fetching incremental data: {e}")
            return []

    def bulk_ingest_to_elasticsearch(self, records):
        """Bulk ingest records to Elasticsearch"""
        if not records:
            return 0
            
        try:
            from elasticsearch.helpers import bulk
            
            actions = []
            for record in records:
                record.pop('attributes', None)
                record['ingestion_timestamp'] = datetime.now().isoformat()
                
                action = {
                    "_index": self.config['es_index'],
                    "_id": record['Id'],
                    "_source": record
                }
                actions.append(action)
            
            # Perform bulk insert
            success, failed = bulk(self.es, actions, chunk_size=500, request_timeout=60)
            
            logger.info(f"Bulk ingested {success} records to Elasticsearch")
            if failed:
                logger.warning(f"Failed to ingest {len(failed)} records")
            
            return success
            
        except Exception as e:
            logger.error(f"Error during bulk ingestion: {e}")
            return 0

    def get_index_stats(self):
        """Get statistics about the current index"""
        try:
            stats = self.es.indices.stats(index=self.config['es_index'])
            doc_count = stats['indices'][self.config['es_index']]['total']['docs']['count']
            size_in_bytes = stats['indices'][self.config['es_index']]['total']['store']['size_in_bytes']
            size_mb = size_in_bytes / (1024 * 1024)
            
            logger.info(f"Index stats - Total documents: {doc_count:,}, Size: {size_mb:.2f} MB")
            
        except Exception as e:
            logger.warning(f"Could not retrieve index stats: {e}")

    def run_single_sync(self):
        """Run a single synchronization cycle"""
        try:
            # Reconnect to Salesforce if needed (token might expire)
            if not self.sf or not self.connect_to_salesforce():
                logger.error("Failed to connect to Salesforce")
                return False
            
            # Fetch incremental data
            records = self.fetch_incremental_data()
            
            # Ingest to Elasticsearch
            if records:
                ingested_count = self.bulk_ingest_to_elasticsearch(records)
                logger.info(f"Sync completed: {ingested_count} records ingested")
                
                # Show index stats after ingestion
                self.get_index_stats()
            else:
                logger.info("No new records to sync")
            
            return True
            
        except Exception as e:
            logger.error(f"Error during sync cycle: {e}")
            return False

    def run_continuous(self):
        """Run continuous ingestion"""
        logger.info("Starting continuous Salesforce LoginHistory ingestion...")
        
        # Initial setup
        if not self.setup_elasticsearch():
            logger.error("Failed to setup Elasticsearch. Exiting.")
            return
        
        sync_interval = self.config.get('sync_interval_minutes', 15)
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
                            logger.warning(f"Sync failed, retrying in 5 minutes... (attempt {retry_count}/{max_retries})")
                            time.sleep(300)  # Wait 5 minutes before retry
                
                if not success:
                    logger.error(f"Sync failed after {max_retries} attempts")
                
                logger.info(f"Waiting {sync_interval} minutes until next sync...")
                time.sleep(sync_interval * 60)
                
            except KeyboardInterrupt:
                logger.info("Received interrupt signal. Stopping continuous ingestion...")
                break
            except Exception as e:
                logger.error(f"Unexpected error in continuous loop: {e}")
                logger.info("Waiting 10 minutes before retrying...")
                time.sleep(600)

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
        'es_index': 'salesforce_loginhistory',
        'sync_interval_minutes': 15,        # Sync every 15 minutes
        'batch_size': 2000,                 # Max records per sync
        'max_retries': 3,                   # Max retry attempts per sync
        'initial_lookback_hours': 24        # How far back to look on first run (hours)
    }
    
    # Create and run ingester
    ingester = SalesforceLoginHistoryIngester(CONFIG)
    ingester.run_continuous()

if __name__ == "__main__":
    main()
