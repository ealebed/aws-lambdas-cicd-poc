"""
Simple example AWS Lambda function in Python.
Logs a greeting message with event details.
"""

import json
import logging
import os

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event, context):
    """
    AWS Lambda handler function.

    Args:
        event: Lambda event object
        context: Lambda context object

    Returns:
        dict: Response with status code and message
    """
    logger.info("Python Lambda function invoked")
    logger.info(f"Event: {json.dumps(event)}")
    logger.info(f"Function name: {context.function_name}")
    logger.info(f"Request ID: {context.aws_request_id}")

    # Get environment variable if set
    greeting = os.environ.get("GREETING", "Hello from Python Lambda #1!")

    response = {
        "statusCode": 200,
        "body": json.dumps(
            {
                "message": greeting,
                "function_name": context.function_name,
                "request_id": context.aws_request_id,
            }
        ),
    }

    logger.info(f"Response: {json.dumps(response)}")
    return response
