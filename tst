#!/usr/bin/env python3
"""
Concise Aternity Data Ingestion Script
"""

import os
import sys
import json
import logging
from datetime import datetime, timezone
import requests
from requests.auth import HTTPBasicAuth
from elasticsearch import Elasticsearch
from elasticsearch.helpers import bulk

# Setup logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class AternityIngester:
    def __init__(self):
        # Load config from environment
        self.aternity_host = os.getenv('ATERNITY_HOST', 'us5-odata.aternity.com')
        self.aternity_auth = HTTPBasicAuth(
            os.getenv('ATERNITY_USERNAME'), 
            os.getenv('ATERNITY_PASSWORD')
        )
        
        # Initialize Elasticsearch
        self.es = Elasticsearch(
            hosts=[os.getenv('ES_HOST', 'http://localhost:9200')],
            basic_auth=(os.getenv('ES_USERNAME', 'elastic'), os.getenv('ES_PASSWORD')),
            verify_certs=True,
            request_timeout=60
        )
        self.es_index = os.getenv('ES_INDEX', 'aternity-activities')
        
        # Validate connection
        if not self.es.ping():
            raise ConnectionError("Cannot connect to Elasticsearch")
    
    def fetch_aternity_data(self, activity="Order Details", time_period="last_24_hours"):
        """Fetch data from Aternity API"""
        try:
            url = f"https://{self.aternity_host}/aternity.odata/latest/BUSINESS_ACTIVITIES_HOURLY"
            params = {
                "format": "json",
                "filter": f"relative_time({time_period}) and activity_name eq '{activity}'"
            }
            
            response = requests.get(url, auth=self.aternity_auth, params=params, timeout=30)
            response.raise_for_status()
            
            records = response.json().get("value", [])
            logger.info(f"Fetched {len(records)} records from Aternity")
            return records
            
        except Exception as e:
            logger.error(f"Error fetching Aternity data: {e}")
            raise
    
    def prepare_documents(self, records):
        """Prepare documents for Elasticsearch"""
        docs = []
        timestamp = datetime.now(timezone.utc).isoformat()
        
        for record in records:
            doc = {
                "_index": self.es_index,
                "_source": {
                    **record,
                    "@timestamp": timestamp,
                    "data_source": "aternity_api"
                }
            }
            docs.append(doc)
        
        return docs
    
    def create_index(self):
        """Create ES index if not exists"""
        if not self.es.indices.exists(index=self.es_index):
            mapping = {
                "mappings": {
                    "properties": {
                        "@timestamp": {"type": "date"},
                        "activity_name": {"type": "keyword"},
                        "data_source": {"type": "keyword"}
                    }
                }
            }
            self.es.indices.create(index=self.es_index, body=mapping)
            logger.info(f"Created index: {self.es_index}")
    
    def ingest_data(self, documents):
        """Bulk ingest to Elasticsearch"""
        if not documents:
            logger.warning("No documents to ingest")
            return {"success": 0, "failed": 0}
        
        self.create_index()
        
        try:
            success, failed = bulk(self.es, documents, index=self.es_index)
            logger.info(f"Ingested: {success} success, {len(failed)} failed")
            return {"success": success, "failed": len(failed)}
        except Exception as e:
            logger.error(f"Bulk ingestion failed: {e}")
            raise
    
    def run(self):
        """Main execution"""
        try:
            # Get configuration
            activity = os.getenv('ATERNITY_ACTIVITY', 'Order Details')
            time_period = os.getenv('ATERNITY_TIME_PERIOD', 'last_24_hours')
            
            # Fetch and ingest data
            records = self.fetch_aternity_data(activity, time_period)
            documents = self.prepare_documents(records)
            result = self.ingest_data(documents)
            
            logger.info(f"Ingestion completed: {result}")
            return result['failed'] == 0
            
        except Exception as e:
            logger.error(f"Ingestion failed: {e}")
            return False

def main():
    """Entry point"""
    try:
        ingester = AternityIngester()
        success = ingester.run()
        sys.exit(0 if success else 1)
    except Exception as e:
        logger.error(f"Fatal error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
