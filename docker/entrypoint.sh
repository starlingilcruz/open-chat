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

echo "Redis connection info:"
echo "Host: ${REDIS_HOST_VALUE}"
echo "Port: ${REDIS_PORT_VALUE}"
echo "REDIS_URL: ${REDIS_URL:-not set}"
echo "REDIS_HOST: ${REDIS_HOST:-not set}"

# Test DNS resolution first
echo "Testing DNS resolution for ${REDIS_HOST_VALUE}..."
if ! getent hosts ${REDIS_HOST_VALUE} > /dev/null 2>&1; then
  echo "DNS resolution failed for ${REDIS_HOST_VALUE}"
  echo "   Trying to resolve..."
  nslookup ${REDIS_HOST_VALUE} || true
  echo "   Continuing anyway..."
fi

# Test port connectivity
echo "Testing port connectivity..."
if command -v nc >/dev/null 2>&1; then
  if ! nc -z -w 2 ${REDIS_HOST_VALUE} ${REDIS_PORT_VALUE} 2>/dev/null; then
    echo "Port ${REDIS_PORT_VALUE} not reachable on ${REDIS_HOST_VALUE}"
  else
    echo "Port ${REDIS_PORT_VALUE} is reachable"
  fi
fi

echo "Connecting to Redis at ${REDIS_HOST_VALUE}:${REDIS_PORT_VALUE}..."
RETRY_COUNT=0
MAX_RETRIES=120
until redis-cli -h ${REDIS_HOST_VALUE} -p ${REDIS_PORT_VALUE} ping > /dev/null 2>&1; do
  RETRY_COUNT=$((RETRY_COUNT + 1))
  if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
    echo "Redis connection timeout after ${MAX_RETRIES} attempts (${MAX_RETRIES} seconds)"
    echo "Host: ${REDIS_HOST_VALUE}, Port: ${REDIS_PORT_VALUE}"
    echo "REDIS_URL: ${REDIS_URL}"
    echo "Testing connection manually..."
    redis-cli -h ${REDIS_HOST_VALUE} -p ${REDIS_PORT_VALUE} ping 2>&1 || true
    echo "Testing with timeout..."
    timeout 2 redis-cli -h ${REDIS_HOST_VALUE} -p ${REDIS_PORT_VALUE} ping 2>&1 || true
    exit 1
  fi
  if [ $((RETRY_COUNT % 10)) -eq 0 ]; then
    echo "Redis is unavailable - sleeping (attempt $RETRY_COUNT/$MAX_RETRIES)"
    # Periodically re-test DNS
    getent hosts ${REDIS_HOST_VALUE} > /dev/null 2>&1 || echo "DNS still not resolving"
  fi
  sleep 1
done
echo "Redis started successfully!"

echo "Running migrations..."
python manage.py migrate --noinput

echo "Collecting static files..."
python manage.py collectstatic --noinput --clear || true

echo "Starting application..."
exec "$@"
