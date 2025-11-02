#!/bin/bash
set -e

echo "Waiting for PostgreSQL..."
until pg_isready -h ${POSTGRES_HOST:-db} -p ${POSTGRES_PORT:-5432} -U ${POSTGRES_USER:-openchat} > /dev/null 2>&1; do
  echo "PostgreSQL is unavailable - sleeping"
  sleep 1
done
echo "PostgreSQL started"

echo "Waiting for Redis..."
REDIS_HOST_VALUE=${REDIS_HOST:-redis}
REDIS_PORT_VALUE=${REDIS_PORT:-6379}
# Extract host from REDIS_URL if it's in URL format
if [ -n "$REDIS_URL" ]; then
  # Parse redis://host:port/db format
  REDIS_HOST_VALUE=$(echo $REDIS_URL | sed -E 's|redis://([^:/]+).*|\1|')
  REDIS_PORT_VALUE=$(echo $REDIS_URL | sed -E 's|redis://[^:]+:([0-9]+).*|\1|' || echo "6379")
fi

echo "Connecting to Redis at ${REDIS_HOST_VALUE}:${REDIS_PORT_VALUE}..."
RETRY_COUNT=0
MAX_RETRIES=60
until redis-cli -h ${REDIS_HOST_VALUE} -p ${REDIS_PORT_VALUE} ping > /dev/null 2>&1; do
  RETRY_COUNT=$((RETRY_COUNT + 1))
  if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
    echo "❌ Redis connection timeout after ${MAX_RETRIES} attempts"
    echo "   Host: ${REDIS_HOST_VALUE}, Port: ${REDIS_PORT_VALUE}"
    echo "   REDIS_URL: ${REDIS_URL}"
    echo "   Trying to debug connection..."
    redis-cli -h ${REDIS_HOST_VALUE} -p ${REDIS_PORT_VALUE} ping || true
    exit 1
  fi
  echo "Redis is unavailable - sleeping (attempt $RETRY_COUNT/$MAX_RETRIES)"
  sleep 1
done
echo "✅ Redis started"

echo "Running migrations..."
python manage.py migrate --noinput

echo "Collecting static files..."
python manage.py collectstatic --noinput --clear || true

echo "Starting application..."
exec "$@"
