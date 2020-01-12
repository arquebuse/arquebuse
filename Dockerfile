# Arquebuse-API build stage

FROM       golang:alpine AS build-api-stage
ARG        api_version="snapshot"
RUN        apk --no-cache add build-base git bzr mercurial gcc
COPY       src/arquebuse-api /go
RUN        export GOPATH="/go" && \
           export GOBIN=$GOPATH/bin && \
           cd /go/src/github.com/arquebuse/arquebuse-api/cmd/arquebuse-api && \
           go get && \
           go build -ldflags "-X main.apiVersion=$api_version" -o $GOBIN/arquebuse-api

# Arquebuse-UI build stage

FROM       node:latest as build-ui-stage
WORKDIR    /app
COPY       src/arquebuse-ui/package*.json ./
RUN        npm install
COPY       src/arquebuse-ui/ .
RUN        npm run build

# Main Image

FROM       alpine:latest
LABEL      maintainer="Arquebuse - https://github.com/arquebuse/arquebuse/"


# Install required packages

RUN        true && \
           apk add --no-cache ca-certificates supervisor nginx && \
           apk add --no-cache --upgrade musl musl-utils && \
           (rm "/tmp/"* 2>/dev/null || true) && \
           (rm -rf /var/cache/apk/* 2>/dev/null || true) && \
           mkdir /run/nginx


# Set up configuration and scripts

COPY       conf/arquebuse /etc/arquebuse
COPY       conf/supervisord/supervisord.conf /etc/supervisord/supervisord.conf
COPY       conf/nginx/default.conf /etc/nginx/conf.d/default.conf
COPY       --from=build-api-stage /go/bin/arquebuse-api /usr/sbin/arquebuse-api
COPY       --from=build-ui-stage /app/dist /app
RUN        chmod +x /usr/sbin/arquebuse-api


# Run supervisord

USER       root
WORKDIR    /tmp
EXPOSE     80
CMD        ["/usr/bin/supervisord", "-c", "/etc/supervisord/supervisord.conf"]
