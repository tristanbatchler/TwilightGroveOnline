# Use the official Golang image for development
FROM golang:1.23

# Set the working directory
WORKDIR /usr/src/gameserver

# Copy dependency files and download modules
COPY go.mod go.sum ./ 
RUN go mod download && go mod verify

# Copy the source code
COPY . .

# Build the application binary
RUN go build -v -o /gameserver/main ./cmd/main.go

# Default command to run the application, referencing the .env file
CMD ["/gameserver/main", "--config", ".env"]