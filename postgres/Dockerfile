FROM postgres:17.6-alpine3.21

USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends jq && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
USER 1001
