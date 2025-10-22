# Stage 1: Builder
FROM golang:1.25.3-trixie AS builder

WORKDIR /app

# Copy go.mod and go.sum first to leverage Docker's build cache
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy the rest of the application source code
COPY . .

# Build the Go application
# CGO_ENABLED=0 creates a statically linked binary, making it more portable
# -o specifies the output binary name
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o myapp .

# Stage 2: Final image
FROM alpine:3.22.2

WORKDIR /root/

# Copy the compiled binary from the builder stage
COPY --from=builder /app/myapp .

RUN apk add curl
# Expose the port your application listens on (optional)
EXPOSE 8000

# Command to run the application when the container starts
CMD ["./myapp"]