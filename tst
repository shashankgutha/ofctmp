import boto3
from datetime import datetime
import os
from opentelemetry import trace, metrics
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk._logs import LoggerProvider
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor
from opentelemetry.exporter.otlp.proto.grpc._log_exporter import OTLPLogExporter
from opentelemetry.sdk.resources import SERVICE_NAME
import base64

# Basic auth credentials
OTLP_USERNAME = os.getenv("OTLP_USERNAME")
OTLP_PASSWORD = os.getenv("OTLP_PASSWORD")
OTLP_ENDPOINT = os.getenv("OTLP_ENDPOINT", "localhost:4317")

# Create basic auth header
credentials = f"{OTLP_USERNAME}:{OTLP_PASSWORD}"
auth_header = base64.b64encode(credentials.encode()).decode()

# Configure OpenTelemetry resource
resource = Resource.create({
    SERVICE_NAME: "aws-health-monitor",
    "deployment.environment": "production"
})

# Configure OTLP exporter with basic auth
headers = [
    ("authorization", f"Basic {auth_header}")
]

otlp_exporter = OTLPLogExporter(
    endpoint=OTLP_ENDPOINT,
    headers=headers,
    insecure=True  # Set to False if using HTTPS
)

# Set up logger provider
logger_provider = LoggerProvider(resource=resource)
logger_provider.add_log_record_processor(BatchLogRecordProcessor(otlp_exporter))

def process_aws_health_api_data(event):
    """
    Process AWS Health API data and send it via OpenTelemetry
    """
    try:
        # Initialize AWS Health client
        health = boto3.client('health')
        
        # Get current time for logging
        ct = datetime.datetime.now()
        ts = ct.timestamp()
        
        # Get health events
        response = health.describe_events(
            filter={
                'eventTypeCategories': ['issue', 'scheduledChange', 'accountNotification']
            }
        )
        
        # Process each event
        for health_event in response['events']:
            try:
                return LogRecord(
                    timestamp=int(ts),
                    severity_text="INFO",
                    body=health_event.get('eventTypeCode', 'unknown'),
                    span_id=2123,
                    trace_id=3232,
                    trace_flags=12,
                    severity_number=9,  # INFO in OpenTelemetry
                    attributes={
                        "service": "aws-health",
                        "eventTypeCode": health_event.get('eventTypeCode', 'unknown'),
                        "eventTypeCategory": health_event.get('eventTypeCategory', 'unknown'),
                        "region": health_event.get('region', 'unknown'),
                        "startTime": health_event.get('startTime', '').isoformat() if health_event.get('startTime') else 'unknown',
                        "eventArn": health_event.get('arn', 'unknown'),
                        "service": health_event.get('service', 'unknown'),
                        "eventDescription": health_event.get('eventDescription', {}).get('latestDescription', 'unknown')
                    }
                )
            except KeyError as e:
                logger.error(f"Missing key in event attributes: {e}")
                continue
            
    except health.exceptions.HealthException as e:
        print(f"AWS Health API error: {e}")
        return None
    except Exception as e:
        print(f"Unexpected error: {e}")
        return None
    finally:
        # Ensure logs are exported
        logger_provider.force_flush()

def main():
    """
    Main function to run the AWS Health check
    """
    try:
        process_aws_health_api_data({})
        print("Successfully processed AWS Health API data")
    except Exception as e:
        print(f"Error in main function: {e}")

if __name__ == "__main__":
    main()
