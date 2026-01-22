# syntax=docker/dockerfile:1

FROM python:3.14.2-slim-trixie AS builder

ENV POETRY_VERSION=2.3.1 POETRY_VIRTUALENVS_CREATE=false

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc libc-dev libpq-dev && \
    pip install "poetry==$POETRY_VERSION" && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . /app/

RUN poetry install --no-ansi --no-interaction --without dev

FROM python:3.14.2-slim-trixie

WORKDIR /app
COPY --from=builder /app /app

CMD ["transfer_vn", "--help"]
