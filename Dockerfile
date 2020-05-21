# Arquebuse-API/Mail build stage

FROM       golang:alpine AS build-golang-stage
ARG        api_version="snapshot"
ARG        mail_version="snapshot"
WORKDIR    /go/src/github.com/arquebuse
RUN        apk --no-cache add git && \
           git config --global advice.detachedHead false
RUN        git clone https://github.com/arquebuse/arquebuse-api.git && \
           cd arquebuse-api && \
           git fetch && git fetch --tags && \
           if [ "${api_version}" != "snapshot" ]; then echo "Checking out tag ${api_version}"; git checkout ${api_version}; fi && \
           git_commit=$(git rev-parse --short HEAD) && \
           build_time=$(date +%Y.%m.%d-%H:%M:%S) && \
           cd cmd/arquebuse-api && \
           go get && \
           CGO_ENABLED=0 go build -a -ldflags "-s -w \
            -X github.com/arquebuse/arquebuse-api/pkg/version.GitCommit=${git_commit} \
            -X github.com/arquebuse/arquebuse-api/pkg/version.Version=${api_version} \
            -X github.com/arquebuse/arquebuse-api/pkg/version.BuildTime=${build_time}" -o /tmp/arquebuse-api
RUN        cd /go/src/github.com/arquebuse && \
           git clone https://github.com/arquebuse/arquebuse-mail.git && \
           cd arquebuse-mail && \
           git fetch && git fetch --tags && \
           if [ "${mail_version}" != "snapshot" ]; then echo "Checking out tag ${mail_version}"; git checkout ${mail_version}; fi && \
           git_commit=$(git rev-parse --short HEAD) && \
           build_time=$(date +%Y.%m.%d-%H:%M:%S) && \
           cd cmd/arquebuse-mail && \
           go get && \
           CGO_ENABLED=0 go build -a -ldflags "-s -w \
            -X github.com/arquebuse/arquebuse-mail/pkg/version.GitCommit=${git_commit} \
            -X github.com/arquebuse/arquebuse-mail/pkg/version.Version=${mail_version} \
            -X github.com/arquebuse/arquebuse-mail/pkg/version.BuildTime=${build_time}" -o /tmp/arquebuse-mail


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
COPY       --from=build-golang-stage /tmp/arquebuse-api /usr/sbin/arquebuse-api
COPY       --from=build-golang-stage /tmp/arquebuse-mail /usr/sbin/arquebuse-mail
COPY       --from=build-ui-stage /app/dist /app


# Run supervisord

USER       root
WORKDIR    /tmp
EXPOSE     2525 443
CMD        ["/usr/bin/supervisord", "-c", "/etc/supervisord/supervisord.conf"]
