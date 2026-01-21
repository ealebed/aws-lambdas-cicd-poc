# Build stage
FROM golang:1.25-alpine AS builder

WORKDIR /build

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build the application
# Use amd64 (x86_64) architecture to match Lambda configuration
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o bootstrap main.go

# Runtime stage - use AWS Lambda provided.al2023 base image
FROM public.ecr.aws/lambda/provided:al2023

# Copy the bootstrap binary
COPY --from=builder /build/bootstrap ${LAMBDA_TASK_ROOT}

# Set the CMD to your handler
CMD [ "bootstrap" ]
