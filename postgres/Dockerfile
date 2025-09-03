FROM bitnami/postgresql:17.6.0-debian-12-r4

USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends jq && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
USER 1001
