FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1
WORKDIR /srv

# opencv-python-headless still needs libGL-free glib bits for imread paths
RUN apt-get update && apt-get install -y --no-install-recommends \
        libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

COPY pyproject.toml ./
RUN pip install --upgrade pip && pip install .

COPY app ./app
COPY alembic ./alembic
COPY alembic.ini ./

# Render, Fly and Cloud Run all assign a port through $PORT and ignore EXPOSE.
# Hardcoding 8000 works only while the platform happens to pick 8000; the shell
# form below honours $PORT and falls back to 8000 for a plain `docker run`.
EXPOSE 8000
ENV PORT=8000
# 2 workers on a 512 MB instance; 4 will OOM.
CMD uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000} \
    --workers 2 --proxy-headers --no-access-log
