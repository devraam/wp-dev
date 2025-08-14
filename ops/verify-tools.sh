#!/usr/bin/env bash
set -euo pipefail

echo "== Composer version =="
docker compose run --rm composer --version

echo "== Composer validate (plugin ejemplo) =="
docker compose run --rm composer validate --no-interaction --working-dir=/app/mi-plugin

echo "== WP-CLI info =="
docker compose run --rm wpcli wp --info --url=http://localhost:8080

echo "== WP instalado & plugins =="
docker compose run --rm wpcli wp core is-installed --url=http://localhost:8080
docker compose run --rm wpcli wp plugin list --url=http://localhost:8080
