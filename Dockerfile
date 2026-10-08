FROM --platform=$BUILDPLATFORM golang:1.25-alpine AS build

LABEL org.opencontainers.image.source=https://github.com/p1ratrulezzz/dnscrypt-proxy
LABEL org.opencontainers.image.description="Dockerized version of dnscrypt-proxy for Mikrotik routers and others"

ARG VERSION=2.1.18
ARG TARGETOS TARGETARCH TARGETVARIANT
RUN apk add --no-cache ca-certificates
WORKDIR /src
ADD https://github.com/DNSCrypt/dnscrypt-proxy/archive/refs/tags/${VERSION}.tar.gz /tmp/src.tar.gz
RUN tar -xzf /tmp/src.tar.gz --strip-components=1
WORKDIR /src/dnscrypt-proxy
ENV CGO_ENABLED=0
RUN case "${TARGETARCH}${TARGETVARIANT}" in \
      armv7) export GOARM=7 ;; \
      armv6) export GOARM=6 ;; \
    esac \
    && GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
       go build -trimpath -ldflags="-s -w" -o /out/dnscrypt-proxy .

FROM alpine:3.24.2

RUN addgroup -S dnscrypt && adduser -S -D -H -G dnscrypt dnscrypt \
    && apk add --no-cache ca-certificates

COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=build /out/dnscrypt-proxy /dnscrypt-proxy
COPY ./dnscrypt-proxy.toml /etc/dnscrypt-proxy/dnscrypt-proxy.toml

EXPOSE 53/tcp 53/udp

ENTRYPOINT ["/dnscrypt-proxy"]
CMD ["-config", "/etc/dnscrypt-proxy/dnscrypt-proxy.toml"]