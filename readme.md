# README — WordPress Dev with Docker (Windows/macOS)

A ready-to-use WordPress development environment with **Docker Compose**, **WP-CLI**, and **Composer**.  
Works the same on **Windows** (Docker Desktop + PowerShell) and **macOS** (Terminal).

---

## Requirements

- **Docker Desktop** (with `docker compose`)
- Free port: **8080** (web)
- Project folder containing:
  - `docker-compose.yml`
  - `ops/setup.sh`
  - `wp/wp-content/themes` and `wp/wp-content/plugins` *(created automatically on first run)*

---

## First run

From the project root:

```bash
docker compose up -d
docker compose logs setup
docker compose logs composer-setup
```

## When it finishes:

Admin: http://localhost:8080/wp-admin/
User: admin
Password: admin123

On Windows PowerShell, the same commands work as-is.


## Useful commands
Note: --rm removes the temporary container after it finishes, but your changes persist because they are written to the shared site volume.


## Check WP status/version

```bash
docker compose run --rm wpcli wp core is-installed --path=/var/www/html --url=http://localhost:8080
docker compose run --rm wpcli wp plugin list --path=/var/www/html --url=http://localhost:8080
```

## Use Composer inside a plugin

```bash
docker compose run --rm composer --version
docker compose run --rm composer init --working-dir=/app/mi-plugin
docker compose run --rm composer install --working-dir=/app/mi-plugin
```

## One-off commands (run from the project folder)

# WP version
docker compose run --rm wpcli wp core version --url=http://localhost:8080

# List/activate plugins

```bash
docker compose run --rm wpcli wp plugin list --url=http://localhost:8080
docker compose run --rm wpcli wp plugin install query-monitor --activate --url=http://localhost:8080
```

## Install and activate plugins
```bash
docker compose run --rm wpcli wp plugin install <slug> --activate --url=http://localhost:8080
```

## Scaffold a plugin
```bash
docker compose run --rm wpcli wp scaffold plugin mi-otro-plugin --url=http://localhost:8080
```

## Use Composer in your plugin
```bash
docker compose run --rm composer require vendor/package -d /app/mi-plugin
```
## Themes
```bash
docker compose run --rm wpcli wp theme list --url=http://localhost:8080
docker compose run --rm wpcli wp theme activate twentytwentyfour --url=http://localhost:8080
```

## Interactive session (optional)
If you prefer to jump in and run several commands:

```bash
docker compose run --rm wpcli bash
# inside the container:
wp --info
wp plugin list
exit
```

## Folder structure

wp-dev/
├─ docker-compose.yml
├─ ops/
│  └─ setup.sh
└─ wp/
   └─ wp-content/
      ├─ themes/
      └─ plugins/
         └─ mi-plugin/   # created on first run


## Tips & notes
Windows vs macOS: works the same. On Windows, if you edit ops/setup.sh, save with LF line endings (the script normalizes them if needed).

WP-CLI permissions: the compose file creates a wp_cli_cache volume with proper permissions to avoid cache warnings when installing plugins.

Database: defaults to MySQL 8.0 with user wpuser / password changeme_pw and DB wordpress (defined in docker-compose.yml).


## Troubleshooting
## Stuck on “waiting for DB…”

Check MySQL health:

```bash
docker compose ps
docker compose logs db
```
If something failed, restart:
```bash
docker compose down -v
docker compose up -d
docker compose logs -f setup
```

## Error installing plugins (permissions on /wp-content/upgrade)

setup.sh already creates uploads and upgrade as www-data. If you changed permissions manually, fix with:
```bash
docker compose exec wordpress bash -lc 'install -d -m 775 -o www-data -g www-data /var/www/html/wp-content/{uploads,upgrade} && chown -R www-data:www-data /var/www/html/wp-content'
```

## Port 8080 in use

Change WORDPRESS_PORT mapping in docker-compose.yml, e.g. - "8081:80", then bring it up again.

## Shut down & clean up
```bash
docker compose down
# or to wipe data and volumes too:
docker compose down -v
```

You’re set! This runs WordPress with WP-CLI and Composer integrated, and a base plugin (mi-plugin) scaffolded and ready for development.