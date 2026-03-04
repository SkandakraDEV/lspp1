# ---------- Stage 1: Vendor Builder ----------
FROM php:8.4-cli AS vendor

WORKDIR /app

RUN apt-get update \
 && apt-get install -y --no-install-recommends git unzip libzip-dev \
 && docker-php-ext-install zip \
 && rm -rf /var/lib/apt/lists/*

COPY composer.json ./
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

RUN composer install \
    --no-dev \
    --no-scripts \
    --optimize-autoloader \
    --no-interaction

# ---------- Stage 2: Asset Builder ----------
FROM node:20 AS assets

WORKDIR /app
COPY package*.json ./
RUN npm install

COPY . .
RUN npm run build

# ---------- Stage 3: Final Production ----------
FROM php:8.4-apache

WORKDIR /var/www/html

ENV APACHE_DOCUMENT_ROOT=/var/www/html/public

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libzip-dev \
    unzip \
 && docker-php-ext-install pdo_mysql mbstring bcmath gd zip \
 && a2enmod rewrite \
 && sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' \
    /etc/apache2/sites-available/*.conf \
    /etc/apache2/apache2.conf \
    /etc/apache2/conf-available/*.conf \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*


# Copy source
COPY . .

RUN mkdir -p storage/framework/views \
    storage/framework/cache \
    storage/framework/sessions \
    && chown -R www-data:www-data storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache
    

COPY --from=assets /app/public/build public/build

RUN chown -R www-data:www-data storage bootstrap

COPY docker/php/custom.ini /usr/local/etc/php/conf.d/custom.ini

# Copy vendor dari stage sebelumnya
COPY --from=vendor /app/vendor ./vendor

# Copy assets dari stage assets

RUN chown -R www-data:www-data storage bootstrap/cache

EXPOSE 80
CMD ["apache2-foreground"]
