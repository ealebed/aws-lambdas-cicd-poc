# Use AWS Lambda Python base image
FROM public.ecr.aws/lambda/python:3.13.2026.02.11.05

# Copy function code
COPY lambda_function.py ${LAMBDA_TASK_ROOT}

# Copy requirements and install dependencies
COPY requirements.txt ${LAMBDA_TASK_ROOT}
RUN pip install --no-cache-dir -r requirements.txt

# Set the CMD to your handler
CMD [ "lambda_function.lambda_handler" ]
