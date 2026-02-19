# Stage 1: Build
FROM golang:1.23-alpine AS builder
WORKDIR /app

# Install build dependencies
RUN apk --no-cache add gcc musl-dev

# Download dependencies first (layer caching)
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build only the server binary
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o server ./cmd/server/main.go

# Stage 2: Run (minimal image)
FROM alpine:latest
WORKDIR /app

RUN apk --no-cache add ca-certificates tzdata
COPY --from=builder /app/server .
COPY --from=builder /app/.env.example .env

EXPOSE 8080
CMD ["./server"]