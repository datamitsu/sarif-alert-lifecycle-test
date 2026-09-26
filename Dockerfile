FROM alpine:3.20
RUN apk add curl
WORKDIR /app
COPY . .
CMD ["sh"]
