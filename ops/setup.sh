#!/usr/bin/env bash
set -euo pipefail

export WP_CLI_ALLOW_ROOT=1
umask 002   # allow group write as well

# 0) Preparation
mkdir -p /var/www/html
cd /var/www/html

# Base permissions → set everything to 33:33 (Debian www-data) so WP-CLI and Apache match
chown -R 33:33 /var/www/html || true
chmod -R u+rwX,go+rX /var/www/html || true

# 1) Core: download to /tmp and copy (without wp-content) if it doesn't exist
if [ ! -f wp-includes/version.php ]; then
  echo "Downloading WordPress core..."
  rm -rf /tmp/wordpress && mkdir -p /tmp/wordpress
  wp core download --skip-content --force --path=/tmp/wordpress --allow-root
  rm -rf /tmp/wordpress/wp-content
  cp -a /tmp/wordpress/. /var/www/html/
  chown -R 33:33 /var/www/html || true
fi

# 2) wp-config.php (create if missing) + ensure DB constants
if [ ! -f wp-config.php ]; then
  wp config create \
    --dbname="$WORDPRESS_DB_NAME" \
    --dbuser="$WORDPRESS_DB_USER" \
    --dbpass="$WORDPRESS_DB_PASSWORD" \
    --dbhost="$WORDPRESS_DB_HOST" \
    --skip-check \
    --force \
    --allow-root
fi
wp config set DB_NAME     "$WORDPRESS_DB_NAME"     --type=constant --allow-root --quiet
wp config set DB_USER     "$WORDPRESS_DB_USER"     --type=constant --allow-root --quiet
wp config set DB_PASSWORD "$WORDPRESS_DB_PASSWORD" --type=constant --allow-root --quiet
wp config set DB_HOST     "$WORDPRESS_DB_HOST"     --type=constant --allow-root --quiet

# 3) Ensure writable dirs
install -d -m 775 -o 33 -g 33 /var/www/html/wp-content/uploads
install -d -m 775 -o 33 -g 33 /var/www/html/wp-content/upgrade
# WP-CLI cache (prevents the first-run warning)
install -d -m 775 -o www-data -g www-data /var/www/.wp-cli/cache || true
chown -R 33:33 /var/www/html/wp-content/uploads /var/www/html/wp-content/upgrade || true

# 4) Wait for DB (up to ~2 minutes)
for i in $(seq 1 40); do
  if wp db check --allow-root >/dev/null 2>&1; then echo "DB OK"; break; fi
  echo "Waiting for DB... ($i)"; sleep 3
done

# 5) Install if not already installed
if ! wp core is-installed --allow-root --quiet; then
  wp core install \
    --url="$WORDPRESS_URL" \
    --title="$WORDPRESS_TITLE" \
    --admin_user="$WORDPRESS_ADMIN_USER" \
    --admin_password="$WORDPRESS_ADMIN_PASSWORD" \
    --admin_email="$WORDPRESS_ADMIN_EMAIL" \
    --skip-email \
    --allow-root
  echo "WordPress installed"
else
  echo "WordPress was already installed"
fi

# 6) Ensure correct site URLs
wp option update home    "$WORDPRESS_URL" --allow-root || true
wp option update siteurl "$WORDPRESS_URL" --allow-root || true

# 7) Default plugin scaffolding (host bind-mount)
PLUGIN_SLUG="mi-plugin"
PLUGIN_DIR="/var/www/html/wp-content/plugins/${PLUGIN_SLUG}"
if [ ! -d "$PLUGIN_DIR" ] || [ -z "$(ls -A "$PLUGIN_DIR" 2>/dev/null || true)" ]; then
  echo "Creando plugin '$PLUGIN_SLUG' con WP-CLI..."
  wp scaffold plugin "$PLUGIN_SLUG" --skip-tests --allow-root
  chown -R 33:33 "$PLUGIN_DIR" || true
else
  echo "Plugin '$PLUGIN_SLUG' ya existe. Omito scaffolding."
fi

echo "Setup complete."
