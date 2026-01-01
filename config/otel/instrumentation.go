// Go client for OpenTelemetry instrumentation
// Use with: go get -u go.opentelemetry.io/otel

package main

import (
	"context"
	"fmt"
	"os"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/jaeger"
	"go.opentelemetry.io/otel/sdk/resource"
	tracesdk "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/semconv/v1.12.0"
	"go.opentelemetry.io/otel/trace"
)

// InitTracer initializes OpenTelemetry tracer with Jaeger exporter
func InitTracer(serviceName string) (trace.Tracer, error) {
	exp, err := jaeger.New(jaeger.WithAgentHost(
		os.Getenv("JAEGER_AGENT_HOST"),
	))
	if err != nil {
		return nil, err
	}

	tp := tracesdk.NewTracerProvider(
		tracesdk.WithBatcher(exp),
		tracesdk.WithResource(resource.NewWithAttributes(
			context.Background(),
			semconv.ServiceNameKey.String(serviceName),
			semconv.ServiceVersionKey.String(os.Getenv("APP_VERSION")),
			semconv.DeploymentEnvironmentKey.String(os.Getenv("ENVIRONMENT")),
			semconv.ServiceInstanceIDKey.String(os.Hostname()),
		)),
	)
	otel.SetTracerProvider(tp)

	fmt.Printf("✓ OpenTelemetry initialized for %s\n", serviceName)
	return tp.Tracer(serviceName), nil
}

// Example usage:
// tracer, err := InitTracer("gitea")
// ctx, span := tracer.Start(context.Background(), "ProcessRequest")
// defer span.End()
// // Your code here
