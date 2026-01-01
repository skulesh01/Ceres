# Python client for OpenTelemetry instrumentation
# Use with: pip install opentelemetry-api opentelemetry-sdk opentelemetry-exporter-jaeger

from opentelemetry import trace, metrics
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.jaeger.thrift import JaegerExporter
from opentelemetry.sdk.resources import SERVICE_NAME, Resource
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor
from opentelemetry.instrumentation.psycopg2 import Psycopg2Instrumentor
from opentelemetry.instrumentation.redis import RedisInstrumentor
import os

def setup_opentelemetry(service_name: str):
    """Setup OpenTelemetry with Jaeger exporter"""
    
    # Create Jaeger exporter
    jaeger_exporter = JaegerExporter(
        agent_host_name=os.getenv("JAEGER_AGENT_HOST", "jaeger"),
        agent_port=int(os.getenv("JAEGER_AGENT_PORT", "6831")),
    )
    
    # Create tracer provider with resource
    trace.set_tracer_provider(
        TracerProvider(
            resource=Resource.create({
                SERVICE_NAME: service_name,
                "environment": os.getenv("ENVIRONMENT", "production"),
                "cluster": "ceres",
                "version": os.getenv("APP_VERSION", "1.0.0"),
            })
        )
    )
    
    # Add Jaeger exporter
    trace.get_tracer_provider().add_span_processor(
        BatchSpanProcessor(jaeger_exporter)
    )
    
    # Auto-instrumentations
    FlaskInstrumentor().instrument()
    RequestsInstrumentor().instrument()
    Psycopg2Instrumentor().instrument()
    RedisInstrumentor().instrument()
    
    print(f"✓ OpenTelemetry initialized for {service_name}")
    print(f"  Jaeger: {os.getenv('JAEGER_AGENT_HOST', 'jaeger')}:{os.getenv('JAEGER_AGENT_PORT', '6831')}")

def get_tracer(name: str):
    """Get tracer instance"""
    return trace.get_tracer(name)

# Example usage in Flask app:
# from flask import Flask
# from instrumentation import setup_opentelemetry, get_tracer
#
# app = Flask(__name__)
# setup_opentelemetry("nextcloud")
# tracer = get_tracer(__name__)
#
# @app.route("/api/files")
# def get_files():
#     with tracer.start_as_current_span("get_files"):
#         # Your code here
#         pass
