/**
 * Simple example AWS Lambda function in JavaScript/Node.js.
 * Logs a greeting message with event details.
 */

/**
 * AWS Lambda handler function.
 *
 * @param {Object} event - Lambda event object
 * @param {Object} context - Lambda context object
 * @returns {Object} Response with status code and message
 */
exports.handler = async (event, context) => {
  console.log("JavaScript Lambda function invoked");
  console.log("Event:", JSON.stringify(event, null, 2));
  console.log("Function name:", context.functionName);
  console.log("Request ID:", context.awsRequestId);

  // Get environment variable if set
  const greeting =
    process.env.GREETING || "Hello from DEFAULT JavaScript Lambda #1!";

  const response = {
    statusCode: 200,
    body: JSON.stringify({
      message: greeting,
      functionName: context.functionName,
      requestId: context.awsRequestId,
    }),
  };

  console.log("Response:", JSON.stringify(response, null, 2));
  return response;
};
