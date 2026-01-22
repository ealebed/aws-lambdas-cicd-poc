"""
Unit tests for the Python Lambda function.
"""

import json
import os
from unittest.mock import MagicMock, patch

from lambda_function import lambda_handler

# HTTP status codes
HTTP_OK = 200


class TestLambdaHandler:
    """Test cases for lambda_handler function."""

    def test_lambda_handler_success(self):
        """Test successful Lambda invocation."""
        event = {"key": "value"}
        context = MagicMock()
        context.function_name = "test-function"
        context.aws_request_id = "test-request-id"

        response = lambda_handler(event, context)

        assert response["statusCode"] == HTTP_OK
        body = json.loads(response["body"])
        assert "message" in body
        assert body["function_name"] == "test-function"
        assert body["request_id"] == "test-request-id"

    def test_lambda_handler_with_custom_greeting(self):
        """Test Lambda handler with custom greeting environment variable."""
        event = {}
        context = MagicMock()
        context.function_name = "test-function"
        context.aws_request_id = "test-request-id"

        with patch.dict(os.environ, {"GREETING": "Custom greeting"}):
            response = lambda_handler(event, context)

        assert response["statusCode"] == HTTP_OK
        body = json.loads(response["body"])
        assert body["message"] == "Custom greeting"
