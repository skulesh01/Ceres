#!/bin/bash
set -e

# Run plugin migrations on first start
if [ ! -f /usr/src/redmine/tmp/plugin_migrated ]; then
    echo "Running plugin migrations..."
    bundle exec rake redmine:plugins:migrate RAILS_ENV=production
    touch /usr/src/redmine/tmp/plugin_migrated
fi

# Generate secret token if not exists
if [ ! -f /usr/src/redmine/config/secrets.yml ]; then
    echo "Generating secret token..."
    bundle exec rake generate_secret_token
fi

# Run original entrypoint
exec /docker-entrypoint.sh "$@"
