import os
import requests
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
        """Fetch data from Aternity API"""
        params = f"&format=json&filter=relative_time({self.time_period}) and activity_name eq '{self.activity}'"
        endpoint = f"https://{self.host}/aternity.odata/latest/BUSINESS_ACTIVITIES_HOURLY?{params}"
        
        auth = HTTPBasicAuth(self.username, self.password)
        
        try:
            resp = requests.get(endpoint, auth=auth, verify=True)
            resp.raise_for_status()
            data = resp.json()
            records = data.get("value", [])
            return records
        except Exception as e:
            print(f"Exception: {e}")
            return []
    
    def prepare_records_for_ingestion(self, records):
        """Prepare records with additional metadata for Elasticsearch"""
        actions = []
        timestamp = datetime.utcnow().isoformat()
        
        for rec in records:
            action = {
                "_index": self.es_index,
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
