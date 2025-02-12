import logging
from opentelemetry._logs import set_logger_provider
from opentelemetry.exporter.otlp.proto.grpc._log_exporter import OTLPLogExporter
from opentelemetry.sdk._logs import LoggerProvider, LoggingHandler
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.resources import SERVICE_NAME
import base64
import os

# Setup resource and exporter as before…
resource = Resource.create({
    SERVICE_NAME: "aws-health-monitor",
    "deployment.environment": "production"
})

OTLP_USERNAME = os.getenv("OTLP_USERNAME")
OTLP_PASSWORD = os.getenv("OTLP_PASSWORD")
OTLP_ENDPOINT = os.getenv("OTLP_ENDPOINT", "localhost:4317")

credentials = f"{OTLP_USERNAME}:{OTLP_PASSWORD}"
auth_header = base64.b64encode(credentials.encode()).decode()
headers = [("authorization", f"Basic {auth_header}")]

otlp_exporter = OTLPLogExporter(
    endpoint=OTLP_ENDPOINT,
    headers=headers,
    insecure=True  # set to False if using HTTPS
)

logger_provider = LoggerProvider(resource=resource)
logger_provider.add_log_record_processor(BatchLogRecordProcessor(otlp_exporter))
set_logger_provider(logger_provider)

# Create a LoggingHandler that sends log records to your OTLP exporter
handler = LoggingHandler(level=logging.INFO, logger_provider=logger_provider)

# Attach the handler to the standard Python logger (for example, the root logger)
logging.getLogger().addHandler(handler)
logging.getLogger().setLevel(logging.INFO)

# Now use Python's logging interface
logging.info("AWS Health event received", extra={"event": "some event details"})
