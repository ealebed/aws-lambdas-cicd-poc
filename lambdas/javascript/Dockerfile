# Use AWS Lambda Node.js base image
FROM public.ecr.aws/lambda/nodejs:24

# Copy function code
COPY index.js ${LAMBDA_TASK_ROOT}
COPY package*.json ${LAMBDA_TASK_ROOT}

# Install dependencies (if any)
RUN npm ci --only=production

# Set the CMD to your handler
CMD [ "index.handler" ]
