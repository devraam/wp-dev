#!/usr/bin/env bash
set -euo pipefail

export WP_CLI_ALLOW_ROOT=1
umask 002   # que el grupo también pueda escribir

# 0) Preparación
mkdir -p /var/www/html
cd /var/www/html

# Permisos base → TODO 33:33 (Debian www-data) para que wpcli y apache coincidan
chown -R 33:33 /var/www/html || true
chmod -R u+rwX,go+rX /var/www/html || true

# 1) Core: descarga a /tmp y copia (sin wp-content) si no existe
if [ ! -f wp-includes/version.php ]; then
  echo "Descargando WordPress core..."
  rm -rf /tmp/wordpress && mkdir -p /tmp/wordpress
  wp core download --skip-content --force --path=/tmp/wordpress --allow-root
  rm -rf /tmp/wordpress/wp-content
  cp -a /tmp/wordpress/. /var/www/html/
  chown -R 33:33 /var/www/html || true
fi

# 2) wp-config.php (crear si falta) + asegurar constantes
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

# 3) Asegura dirs de escritura
install -d -m 775 -o 33 -g 33 /var/www/html/wp-content/uploads
install -d -m 775 -o 33 -g 33 /var/www/html/wp-content/upgrade
# Cache de WP-CLI (evita el warning del primer uso)
install -d -m 775 -o www-data -g www-data /var/www/.wp-cli/cache || true
chown -R 33:33 /var/www/html/wp-content/uploads /var/www/html/wp-content/upgrade || true

# 4) Espera DB (hasta ~2 min)
for i in $(seq 1 40); do
  if wp db check --allow-root >/dev/null 2>&1; then echo "DB OK"; break; fi
  echo "Esperando DB... ($i)"; sleep 3
done

# 5) Instalar si no está
if ! wp core is-installed --allow-root --quiet; then
  wp core install \
    --url="$WORDPRESS_URL" \
    --title="$WORDPRESS_TITLE" \
    --admin_user="$WORDPRESS_ADMIN_USER" \
    --admin_password="$WORDPRESS_ADMIN_PASSWORD" \
    --admin_email="$WORDPRESS_ADMIN_EMAIL" \
    --skip-email \
    --allow-root
  echo "WordPress instalado"
else
  echo "WordPress ya estaba instalado"
fi

# 6) Asegura URLs correctas
wp option update home    "$WORDPRESS_URL" --allow-root || true
wp option update siteurl "$WORDPRESS_URL" --allow-root || true

# 7) Scaffolding de plugin por defecto (bind-mount del host)
PLUGIN_SLUG="mi-plugin"
PLUGIN_DIR="/var/www/html/wp-content/plugins/${PLUGIN_SLUG}"
if [ ! -d "$PLUGIN_DIR" ] || [ -z "$(ls -A "$PLUGIN_DIR" 2>/dev/null || true)" ]; then
  echo "Creando plugin '$PLUGIN_SLUG' con WP-CLI..."
  wp scaffold plugin "$PLUGIN_SLUG" --skip-tests --allow-root
  chown -R 33:33 "$PLUGIN_DIR" || true
else
  echo "Plugin '$PLUGIN_SLUG' ya existe. Omito scaffolding."
fi

echo "Setup terminado."