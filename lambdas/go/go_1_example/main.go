package main

import (
	"context"
	"encoding/json"
	"log"
	"os"

	"github.com/aws/aws-lambda-go/lambda"
)

// Response represents the Lambda response structure
type Response struct {
	StatusCode int               `json:"statusCode"`
	Body       string            `json:"body"`
	Headers    map[string]string `json:"headers,omitempty"`
}

// ResponseBody represents the body content
type ResponseBody struct {
	Message      string `json:"message"`
	FunctionName string `json:"function_name"`
	RequestID    string `json:"request_id"`
}

// Handler is the Lambda function handler
func Handler(ctx context.Context, event map[string]interface{}) (Response, error) {
	log.Println("Go Lambda function invoked")

	eventJSON, _ := json.Marshal(event)
	log.Printf("Event: %s", string(eventJSON))

	// Get function name and request ID from context
	functionName := os.Getenv("AWS_LAMBDA_FUNCTION_NAME")
	requestID := os.Getenv("AWS_LAMBDA_REQUEST_ID")

	log.Printf("Function name: %s", functionName)
	log.Printf("Request ID: %s", requestID)

	// Get environment variable if set
	greeting := os.Getenv("GREETING")
	if greeting == "" {
		greeting = "Hello from Go Lambda #1!"
	}

	body := ResponseBody{
		Message:      greeting,
		FunctionName: functionName,
		RequestID:    requestID,
	}

	bodyJSON, err := json.Marshal(body)
	if err != nil {
		return Response{
			StatusCode: 500,
			Body:       `{"error": "Failed to marshal response"}`,
		}, err
	}

	response := Response{
		StatusCode: 200,
		Body:       string(bodyJSON),
		Headers: map[string]string{
			"Content-Type": "application/json",
		},
	}

	responseJSON, _ := json.Marshal(response)
	log.Printf("Response: %s", string(responseJSON))

	return response, nil
}

func main() {
	lambda.Start(Handler)
}
