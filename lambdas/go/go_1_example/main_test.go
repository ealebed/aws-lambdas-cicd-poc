package main

import (
	"context"
	"encoding/json"
	"os"
	"testing"
)

func TestHandler(t *testing.T) {
	// Set up test environment
	originalFunctionName := os.Getenv("AWS_LAMBDA_FUNCTION_NAME")
	originalRequestID := os.Getenv("AWS_LAMBDA_REQUEST_ID")

	os.Setenv("AWS_LAMBDA_FUNCTION_NAME", "test-function")
	os.Setenv("AWS_LAMBDA_REQUEST_ID", "test-request-id")
	defer func() {
		if originalFunctionName != "" {
			os.Setenv("AWS_LAMBDA_FUNCTION_NAME", originalFunctionName)
		} else {
			os.Unsetenv("AWS_LAMBDA_FUNCTION_NAME")
		}
		if originalRequestID != "" {
			os.Setenv("AWS_LAMBDA_REQUEST_ID", originalRequestID)
		} else {
			os.Unsetenv("AWS_LAMBDA_REQUEST_ID")
		}
	}()

	ctx := context.Background()
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
	originalRequestID := os.Getenv("AWS_LAMBDA_REQUEST_ID")
	originalGreeting := os.Getenv("GREETING")

	os.Setenv("AWS_LAMBDA_FUNCTION_NAME", "test-function")
	os.Setenv("AWS_LAMBDA_REQUEST_ID", "test-request-id")
	os.Setenv("GREETING", "Custom greeting")
	defer func() {
		if originalFunctionName != "" {
			os.Setenv("AWS_LAMBDA_FUNCTION_NAME", originalFunctionName)
		} else {
			os.Unsetenv("AWS_LAMBDA_FUNCTION_NAME")
		}
		if originalRequestID != "" {
			os.Setenv("AWS_LAMBDA_REQUEST_ID", originalRequestID)
		} else {
			os.Unsetenv("AWS_LAMBDA_REQUEST_ID")
		}
		if originalGreeting != "" {
			os.Setenv("GREETING", originalGreeting)
		} else {
			os.Unsetenv("GREETING")
		}
	}()

	ctx := context.Background()
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
