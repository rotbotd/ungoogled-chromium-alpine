FROM ubuntu:22.04

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends \
        bash \
        build-essential \
        ca-certificates \
        coreutils \
        python3 \
    && rm -rf /var/lib/apt/lists/*
