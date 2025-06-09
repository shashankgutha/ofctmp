import os
import requests
import hashlib
from datetime import datetime
from elasticsearch import Elasticsearch
from requests.auth import HTTPBasicAuth


class AternityDataIngestion:
    def __init__(self):
        # Aternity API configuration from environment variables
        self.host = os.getenv('ATERNITY_HOST')
        self.username = os.getenv('ATERNITY_USERNAME')
        self.password = os.getenv('ATERNITY_PASSWORD')
        self.activity = os.getenv('ATERNITY_ACTIVITY', 'Order Details')
        self.time_period = os.getenv('ATERNITY_TIME_PERIOD', 'last_24_hours')
        
        # Elasticsearch configuration from environment variables
        self.es_host = os.getenv('ES_HOST')
        self.es_user = os.getenv('ES_USER')
        self.es_pass = os.getenv('ES_PASS')
        self.es_index = os.getenv('ES_INDEX')
        
        # Initialize Elasticsearch client
        self.es = Elasticsearch(
            self.es_host,
            basic_auth=(self.es_user, self.es_pass),
            verify_certs=False,
            ssl_show_warn=False
        )
    
    def get_aternity_data(self):
        """Fetch data from Aternity API with pagination support"""
        params = f"&format=json&filter=relative_time({self.time_period}) and activity_name eq '{self.activity}'"
        endpoint = f"https://{self.host}/aternity.odata/latest/BUSINESS_ACTIVITIES_HOURLY?{params}"
        
        auth = HTTPBasicAuth(self.username, self.password)
        all_records = []
        
        while endpoint:
            try:
                resp = requests.get(endpoint, auth=auth, verify=True)
                resp.raise_for_status()
                data = resp.json()
                
                # Add current page records to collection
                records = data.get("value", [])
                all_records.extend(records)
                print(f"Fetched {len(records)} records from current page")
                
                # Check for next page
                endpoint = data.get("@odata.nextLink")
                if endpoint:
                    print(f"Found next page: {len(all_records)} total records so far")
                
            except Exception as e:
                print(f"Exception: {e}")
                break
        
        print(f"Total records fetched: {len(all_records)}")
        return all_records
    
    def generate_document_id(self, record):
        """Generate unique document ID using ACCOUNT_ID+APPLICATION_NAME+USERNAME+TIMEFRAME"""
        account_id = str(record.get('ACCOUNT_ID', ''))
        application_name = str(record.get('APPLICATION_NAME', ''))
        username = str(record.get('USERNAME', ''))
        timeframe = str(record.get('TIMEFRAME', ''))
        
        # Create concatenated string
        id_string = f"{account_id}+{application_name}+{username}+{timeframe}"
        
        # Generate MD5 hash for consistent ID
        hash_id = hashlib.md5(id_string.encode('utf-8')).hexdigest()
        
        return hash_id
    
    def prepare_records_for_ingestion(self, records):
        """Prepare records with additional metadata for Elasticsearch"""
        actions = []
        timestamp = datetime.utcnow().isoformat()
        
        for rec in records:
            # Generate unique document ID
            doc_id = self.generate_document_id(rec)
            
            action = {
                "_index": self.es_index,
                "_id": doc_id,
                "_source": {
                    **rec,
                    "@timestamp": timestamp,
                    "data_source": "aternity_api"
                }
            }
            actions.append(action)
        
        return actions
    
    def ingest_to_elasticsearch(self, actions):
        """Bulk ingest data to Elasticsearch"""
        if not actions:
            print("No data to ingest")
            return
        
        try:
            from elasticsearch.helpers import bulk
            bulk(self.es, actions)
            print(f"Successfully ingested {len(actions)} records")
        except Exception as e:
            print(f"Error ingesting data: {e}")
    
    def run(self):
        """Main execution method"""
        print("Starting Aternity data ingestion...")
        
        # Fetch data from Aternity
        records = self.get_aternity_data()
        
        if not records:
            print("No records found")
            return
        
        print(f"Fetched {len(records)} records")
        
        # Prepare records for ingestion
        actions = self.prepare_records_for_ingestion(records)
        
        # Ingest to Elasticsearch
        self.ingest_to_elasticsearch(actions)
        
        print("Aternity data ingestion completed")


if __name__ == "__main__":
    ingestion = AternityDataIngestion()
    ingestion.run()
