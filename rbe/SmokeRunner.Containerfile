FROM alpine:edge

RUN apk add --no-cache \
        bash \
        build-base \
        ca-certificates \
        clang22 \
        coreutils \
        lld22 \
        python3 \
