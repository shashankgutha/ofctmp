#!/usr/bin/env python3
"""
Simplified Elasticsearch Empty Data Streams Cleanup Script

Deletes data streams based on:
- Size <= 500 bytes
- Backing indices <= 1  
- Age > 30 days
- Skip system streams (starting with '.')
"""

import os
import time
from datetime import datetime, timedelta
from elasticsearch import Elasticsearch

# Configuration from environment variables
ES_HOST = os.getenv('ES_HOST', 'localhost')
ES_PORT = int(os.getenv('ES_PORT', '9200'))
ES_USERNAME = os.getenv('ES_USERNAME')
ES_PASSWORD = os.getenv('ES_PASSWORD')
ES_USE_SSL = os.getenv('ES_USE_SSL', 'false').lower() == 'true'
DRY_RUN = os.getenv('DRY_RUN', 'true').lower() == 'true'

# Filtering criteria
MAX_SIZE_BYTES = 500
MAX_BACKING_INDICES = 1
AGE_THRESHOLD_DAYS = 30

def create_es_client():
    """Create Elasticsearch client"""
    config = {
        'hosts': [f"{'https' if ES_USE_SSL else 'http'}://{ES_HOST}:{ES_PORT}"],
        'verify_certs': ES_USE_SSL,
    }
    
    if ES_USERNAME and ES_PASSWORD:
        config['basic_auth'] = (ES_USERNAME, ES_PASSWORD)
    
    return Elasticsearch(**config)

def get_data_streams_to_delete(es):
    """Get list of data streams that should be deleted"""
    print("Getting data stream statistics...")
    
    # Get stats
    response = es.indices.data_streams_stats(name="*")
    data_streams = response.get('data_streams', [])
    
    # Calculate age threshold
    age_threshold_ms = int((datetime.now() - timedelta(days=AGE_THRESHOLD_DAYS)).timestamp() * 1000)
    
    streams_to_delete = []
    
    for stream in data_streams:
        name = stream.get('data_stream', '')
        size = stream.get('store_size_bytes', 0)
        backing_indices = stream.get('backing_indices', 0)
        max_timestamp = stream.get('maximum_timestamp', 0)
        
        # Apply filtering criteria
        if (not name.startswith('.') and  # Skip system streams
            size <= MAX_SIZE_BYTES and
            backing_indices <= MAX_BACKING_INDICES and
            max_timestamp > 0 and
            max_timestamp <= age_threshold_ms):
            
            age_days = (datetime.now().timestamp() * 1000 - max_timestamp) / (1000 * 60 * 60 * 24)
            streams_to_delete.append({
                'name': name,
                'size': size,
                'indices': backing_indices,
                'age_days': round(age_days, 1)
            })
    
    return streams_to_delete

def delete_data_streams(es, streams_to_delete):
    """Delete the filtered data streams"""
    deleted = []
    failed = []
    
    for stream in streams_to_delete:
        try:
            print(f"Deleting: {stream['name']}")
            es.indices.delete_data_stream(name=stream['name'])
            deleted.append(stream['name'])
            time.sleep(0.5)  # Small delay
        except Exception as e:
            print(f"Failed to delete {stream['name']}: {e}")
            failed.append(stream['name'])
    
    return deleted, failed

def main():
    print("=" * 60)
    print("Elasticsearch Data Streams Cleanup")
    print("=" * 60)
    print(f"Host: {ES_HOST}:{ES_PORT}")
    print(f"SSL: {ES_USE_SSL}")
    print(f"Dry Run: {DRY_RUN}")
    print(f"Criteria: size<={MAX_SIZE_BYTES}b, indices<={MAX_BACKING_INDICES}, age>{AGE_THRESHOLD_DAYS}d")
    print("-" * 60)
    
    try:
        # Connect to Elasticsearch
        es = create_es_client()
        
        if not es.ping():
            print("ERROR: Cannot connect to Elasticsearch")
            return 1
        
        print("Connected to Elasticsearch successfully")
        
        # Get streams to delete
        streams_to_delete = get_data_streams_to_delete(es)
        
        if not streams_to_delete:
            print("No data streams found matching deletion criteria")
            return 0
        
        print(f"\nFound {len(streams_to_delete)} data streams to delete:")
        for stream in streams_to_delete:
            print(f"  - {stream['name']} ({stream['size']}b, {stream['indices']} indices, {stream['age_days']}d old)")
        
        if DRY_RUN:
            print(f"\nDRY RUN: Would delete {len(streams_to_delete)} data streams")
            print("Set DRY_RUN=false to perform actual deletion")
        else:
            print(f"\nDeleting {len(streams_to_delete)} data streams...")
            deleted, failed = delete_data_streams(es, streams_to_delete)
            
            print(f"\nResults:")
            print(f"  Successfully deleted: {len(deleted)}")
            print(f"  Failed to delete: {len(failed)}")
            
            if deleted:
                print(f"  Deleted streams: {', '.join(deleted)}")
            if failed:
                print(f"  Failed streams: {', '.join(failed)}")
    
    except Exception as e:
        print(f"ERROR: {e}")
        return 1
    
    print("\nCleanup completed")
    return 0

if __name__ == "__main__":
    exit(main())
