FROM python:3.14-slim
LABEL org.opencontainers.image.source="https://github.com/tdomnitz/graphify-action"

ARG GRAPHIFY_VERSION=0.9.84

RUN apt-get update && \
  apt-get install -y --no-install-recommends git && \
  rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir "graphifyy[gemini]==${GRAPHIFY_VERSION}"

COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]