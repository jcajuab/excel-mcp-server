FROM python:3.11-slim AS builder

COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

WORKDIR /app

COPY pyproject.toml uv.lock* ./

RUN uv pip install --system --no-cache \
    --compile-bytecode \
    -r pyproject.toml

COPY src/ ./src/
COPY README.md LICENSE ./

RUN uv pip install --system --no-cache --no-deps -e .

FROM python:3.11-slim AS runtime

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONPATH=/app \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    EXCEL_FILES_PATH=/app/excel_files \
    FASTMCP_PORT=8000 \
    FASTMCP_HOST=0.0.0.0

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    curl \
    tzdata && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN groupadd -r -g 1000 appuser && \
    useradd -r -u 1000 -g appuser -d /app -s /sbin/nologin \
    -c "Application user" appuser

WORKDIR /app

COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=builder /usr/local/bin/excel-mcp-server /usr/local/bin/excel-mcp-server

COPY --from=builder /app/src ./src
COPY --from=builder /app/README.md /app/LICENSE ./

RUN mkdir -p /app/excel_files /app/logs && \
    chown -R appuser:appuser /app

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8000/mcp || exit 1

CMD ["excel-mcp-server", "streamable-http"]
