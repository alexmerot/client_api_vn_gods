# syntax=docker/dockerfile:1

FROM python:3.14-slim-trixie AS builder

ENV POETRY_VERSION=2.4.1 \
    POETRY_VIRTUALENVS_CREATE=true \
    POETRY_VIRTUALENVS_IN_PROJECT=true \
    POETRY_NO_INTERACTION=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc libc-dev libpq-dev && \
    pip install "poetry==$POETRY_VERSION" && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Two runs for Docker layer caching optimisation
COPY pyproject.toml poetry.lock ./

RUN poetry install --no-ansi --only main --no-root

COPY src ./src
COPY README.md LICENSE ./

RUN poetry install --no-ansi --only main

FROM python:3.14-slim-trixie

# Set timezone to Europe/Paris
ENV TZ=Europe/Paris
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Set locale to French and install PostgreSQL client
RUN apt-get update && apt-get install -y --no-install-recommends locales postgresql-client && \
    sed -i '/fr_FR.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen fr_FR.UTF-8 && \
    rm -rf /var/lib/apt/lists/*

ENV LANG=fr_FR.UTF-8
ENV LANGUAGE=fr_FR:fr
ENV LC_ALL=fr_FR.UTF-8

# Set up non-root user for added security
RUN useradd -r -m -d /home/appuser -U appuser

WORKDIR /app
COPY --from=builder --chown=appuser:appuser /app /app

# Activate the virtual environment
ENV VIRTUAL_ENV=/app/.venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

USER appuser

CMD ["transfer_vn", "--help"]
