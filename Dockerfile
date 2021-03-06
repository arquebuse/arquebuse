# Arquebuse-API/Mail build stage

FROM       golang:alpine AS build-golang-stage
ARG        api_version="snapshot"
ARG        mail_version="snapshot"
RUN        apk --no-cache add git
RUN        export GOPATH="/go" && \
           export GOBIN=$GOPATH/bin && \
           git config --global advice.detachedHead false && \
           mkdir -p /go/src/github.com/arquebuse
RUN        cd /go/src/github.com/arquebuse && \
           git clone https://github.com/arquebuse/arquebuse-api.git && \
           cd arquebuse-api && \
           git fetch && git fetch --tags && \
           if [ "${api_version}" != "snapshot" ]; then echo "Checking out tag ${api_version}"; git checkout ${api_version}; fi && \
           cd cmd/arquebuse-api && \
           go get && \
           go build -ldflags "-X main.apiVersion=${api_version}" -o $GOBIN/arquebuse-api
RUN        cd /go/src/github.com/arquebuse && \
           git clone https://github.com/arquebuse/arquebuse-mail.git && \
           cd arquebuse-mail && \
           git fetch && git fetch --tags && \
           if [ "${mail_version}" != "snapshot" ]; then echo "Checking out tag ${mail_version}"; git checkout ${mail_version}; fi && \
           cd cmd/arquebuse-mail && \
           go get && \
           go build -ldflags "-X main.mailVersion=${mail_version}" -o $GOBIN/arquebuse-mail


# Arquebuse-UI build stage

FROM       node:latest as build-ui-stage
ARG        ui_version="snapshot"
WORKDIR    /app
RUN        git config --global advice.detachedHead false && \
           git clone https://github.com/arquebuse/arquebuse-ui.git /app && \
           git fetch && git fetch --tags && \
           if [ "${ui_version}" != "snapshot" ]; then echo "Checking out tag ${ui_version}"; git checkout ${ui_version}; fi && \
           npm install && \
           npm run build


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

COPY       conf/arquebuse-api /etc/arquebuse-api
COPY       conf/arquebuse-mail /etc/arquebuse-mail
COPY       conf/supervisord/supervisord.conf /etc/supervisord/supervisord.conf
COPY       conf/nginx/default.conf /etc/nginx/conf.d/default.conf
COPY       conf/nginx/ssl /etc/nginx/ssl
COPY       --from=build-golang-stage /go/bin/arquebuse-api /usr/sbin/arquebuse-api
COPY       --from=build-golang-stage /go/bin/arquebuse-mail /usr/sbin/arquebuse-mail
COPY       --from=build-ui-stage /app/dist /app


# Run supervisord

USER       root
WORKDIR    /tmp
EXPOSE     2525 443
CMD        ["/usr/bin/supervisord", "-c", "/etc/supervisord/supervisord.conf"]
