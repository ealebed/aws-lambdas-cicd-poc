/**
 * Unit tests for the JavaScript Lambda function.
 */
const { handler } = require("./index");

describe("Lambda Handler", () => {
  let mockContext;

  beforeEach(() => {
    mockContext = {
      functionName: "test-function",
      awsRequestId: "test-request-id",
    };
  });

  test("should return success response", async () => {
    const event = { key: "value" };
    const response = await handler(event, mockContext);

    expect(response.statusCode).toBe(200);
    const body = JSON.parse(response.body);
    expect(body).toHaveProperty("message");
    expect(body.functionName).toBe("test-function");
    expect(body.requestId).toBe("test-request-id");
  });

  test("should use custom greeting from environment", async () => {
    const originalGreeting = process.env.GREETING;
    process.env.GREETING = "Custom greeting";

    const event = {};
    const response = await handler(event, mockContext);

    expect(response.statusCode).toBe(200);
    const body = JSON.parse(response.body);
    expect(body.message).toBe("Custom greeting");

    // Restore original value
    if (originalGreeting) {
      process.env.GREETING = originalGreeting;
    } else {
      delete process.env.GREETING;
    }
  });
});
