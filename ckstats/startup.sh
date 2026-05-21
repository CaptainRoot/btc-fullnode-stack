#!/bin/bash
set -e

# Load .env if it exists
if [ -f /app/.env ]; then
    export $(grep -v '^#' /app/.env | xargs)
fi

DB_HOST="${DB_HOST:-ckstats-db}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-ckstats-mainnet}"
DB_NAME="${DB_NAME:-ckstats-mainnet}"
DB_PASSWORD="${DB_PASSWORD:-changeme}"

# Export for pnpm/app to use
export DATABASE_URL="postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}"

# Optional rebuild of app
if [ "$REBUILD_APP" = "1" ]; then
    echo "🔁 [startup] REBUILD_APP=1 detected - removing build marker..."
    rm -f /app/.build.complete
fi

# Function to check if PostgreSQL is reachable
wait_for_postgres() {
    echo "⏳ [startup] Waiting for PostgreSQL to be ready at ${DB_HOST}:${DB_PORT}..."
    for i in {1..30}; do
        if pg_isready -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" > /dev/null 2>&1; then
            echo "✅ [startup] PostgreSQL is ready."
            return 0
        fi
        echo "⏳ [startup] Attempt $i/30 - PostgreSQL not ready yet, retrying..."
        sleep 2
    done

    echo "❌ [startup] PostgreSQL did not become ready in time at ${DB_HOST}:${DB_PORT}"
    exit 1
}

# Function to build and run migrations/seed
build_and_migrate() {
    cd /app

    echo "🧪 [startup] Running migrations and seed..."
    pnpm migration:run
    pnpm seed

    if [ ! -f /app/.build.complete ]; then
        echo "🔨 [startup] Running pnpm build..."
        pnpm build && touch /app/.build.complete
    else
        echo "✅ [startup] Build already complete (skipping)."
    fi
}

echo "🚦 [startup] Starting supervisord..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
