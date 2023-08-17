FROM golang:1.16 AS build
WORKDIR /app
COPY . .
RUN go build -o raft .
FROM alpine:latest
WORKDIR /app
COPY --from=build /app/raft .
CMD ["./raft"]