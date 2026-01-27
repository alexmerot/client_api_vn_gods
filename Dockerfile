# syntax=docker/dockerfile:1

FROM python:3.14.2-slim-trixie AS builder

ENV POETRY_VERSION=2.3.1 \
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

RUN poetry install --no-ansi --without dev --no-root

COPY . .

RUN poetry install --no-ansi --without dev

FROM python:3.14.2-slim-trixie

# Set timezone to Europe/Paris
ENV TZ=Europe/Paris
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Set locale to French
RUN apt-get update && apt-get install -y locales && \
    sed -i '/fr_FR.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen fr_FR.UTF-8 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

ENV LANG=fr_FR.UTF-8
ENV LANGUAGE=fr_FR:fr
ENV LC_ALL=fr_FR.UTF-8

# Set up non-root user for added security
RUN useradd -r -m -d /home/appuser -U appuser

WORKDIR /app
COPY --from=builder /app /app

RUN mkdir -p /home/appuser/config

# Activate the virtual environment
ENV VIRTUAL_ENV=/app/.venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# Set permissions for the non-root user
RUN chown -R appuser:appuser /app && chown -R appuser:appuser /home/appuser

# Switch to non-root user
USER appuser

# Default command
CMD ["transfer_vn", "--help"]
