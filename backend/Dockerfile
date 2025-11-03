# ------------------------------------------
# Stage 1: Build the Go binary
# ------------------------------------------
FROM golang:1.25.3-trixie AS builder

# Set a dedicated working directory
WORKDIR /app

# Copy go.mod and go.sum first to take advantage of Docker layer caching
COPY go.mod go.sum ./

# Download dependencies (cached unless dependencies change)
RUN go mod download

# Copy the rest of the source code
COPY . .

# Build the application
# - CGO_ENABLED=0 disables C bindings for static build (portable)
# - GOOS=linux ensures Linux-compatible binary
# - Use -trimpath and -ldflags for smaller binaries
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -trimpath -o myapp .

# ------------------------------------------
# Stage 2: Final runtime image
# ------------------------------------------
FROM alpine:3.22.2

# Create a non-root user for security
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Set a secure working directory
WORKDIR /app

# Copy the binary from the builder
COPY --from=builder /app/myapp .

# # Optional: copy secrets securely (consider using Docker secrets in production)
# COPY db-password /run/secrets/db-password

# Install only necessary tools
RUN apk add --no-cache curl

# Change ownership and drop privileges
RUN chown -R appuser:appgroup /app 
USER appuser

# Expose the application port
EXPOSE 8000

# Run the application
ENTRYPOINT ["./myapp"]
