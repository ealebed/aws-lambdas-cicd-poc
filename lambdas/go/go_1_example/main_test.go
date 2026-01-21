package main

import (
	"context"
	"encoding/json"
	"os"
	"testing"

	"github.com/aws/aws-lambda-go/lambdacontext"
)

func TestHandler(t *testing.T) {
	// Set up test environment
	originalFunctionName := os.Getenv("AWS_LAMBDA_FUNCTION_NAME")

	os.Setenv("AWS_LAMBDA_FUNCTION_NAME", "test-function")
	defer func() {
		if originalFunctionName != "" {
			os.Setenv("AWS_LAMBDA_FUNCTION_NAME", originalFunctionName)
		} else {
			os.Unsetenv("AWS_LAMBDA_FUNCTION_NAME")
		}
	}()

	// Create a context with Lambda context containing request ID
	lc := &lambdacontext.LambdaContext{
		AwsRequestID: "test-request-id",
	}
	ctx := lambdacontext.NewContext(context.Background(), lc)

	event := map[string]interface{}{
		"key": "value",
	}

	response, err := Handler(ctx, event)
	if err != nil {
		t.Fatalf("Handler returned error: %v", err)
	}

	if response.StatusCode != 200 {
		t.Errorf("Expected status code 200, got %d", response.StatusCode)
	}

	var body ResponseBody
	if err := json.Unmarshal([]byte(response.Body), &body); err != nil {
		t.Fatalf("Failed to unmarshal response body: %v", err)
	}

	if body.Message == "" {
		t.Error("Expected message in response body")
	}

	if body.FunctionName != "test-function" {
		t.Errorf("Expected function name 'test-function', got '%s'", body.FunctionName)
	}

	if body.RequestID != "test-request-id" {
		t.Errorf("Expected request ID 'test-request-id', got '%s'", body.RequestID)
	}
}

func TestHandlerWithCustomGreeting(t *testing.T) {
	// Set up test environment
	originalFunctionName := os.Getenv("AWS_LAMBDA_FUNCTION_NAME")
	originalGreeting := os.Getenv("GREETING")

	os.Setenv("AWS_LAMBDA_FUNCTION_NAME", "test-function")
	os.Setenv("GREETING", "Custom greeting")
	defer func() {
		if originalFunctionName != "" {
			os.Setenv("AWS_LAMBDA_FUNCTION_NAME", originalFunctionName)
		} else {
			os.Unsetenv("AWS_LAMBDA_FUNCTION_NAME")
		}
		if originalGreeting != "" {
			os.Setenv("GREETING", originalGreeting)
		} else {
			os.Unsetenv("GREETING")
		}
	}()

	// Create a context with Lambda context containing request ID
	lc := &lambdacontext.LambdaContext{
		AwsRequestID: "test-request-id",
	}
	ctx := lambdacontext.NewContext(context.Background(), lc)

	event := map[string]interface{}{}

	response, err := Handler(ctx, event)
	if err != nil {
		t.Fatalf("Handler returned error: %v", err)
	}

	var body ResponseBody
	if err := json.Unmarshal([]byte(response.Body), &body); err != nil {
		t.Fatalf("Failed to unmarshal response body: %v", err)
	}

	if body.Message != "Custom greeting" {
		t.Errorf("Expected message 'Custom greeting', got '%s'", body.Message)
	}
}
