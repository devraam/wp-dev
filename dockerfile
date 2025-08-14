# Etapa builder con Composer
FROM composer:2 AS builder
WORKDIR /app
COPY wp/wp-content/plugins/mi-plugin/ /app/
RUN composer install --no-dev --prefer-dist --no-interaction --optimize-autoloader

# Imagen final de WordPress
FROM wordpress:php8.2-apache
# Copia el código del plugin
COPY wp/wp-content/plugins/mi-plugin/ /var/www/html/wp-content/plugins/mi-plugin/
# Copia vendor generado en build
COPY --from=builder /app/vendor/ /var/www/html/wp-content/plugins/mi-plugin/vendor/
