FROM postgres:17.6-trixie

USER root

RUN apt-get update && \
    apt-get install -y --no-install-recommends jq && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /docker-entrypoint-initdb.d/config

COPY init.sh /docker-entrypoint-initdb.d
COPY config/config.json /docker-entrypoint-initdb.d/config

RUN chmod +x /docker-entrypoint-initdb.d/init.sh
