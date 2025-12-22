ARG PHP_VERSION=8.0

FROM php:${PHP_VERSION}-fpm-alpine

LABEL maintainer="Laravel Docker"

# Install system dependencies
RUN apk add --no-cache \
    git \
    curl \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    libwebp-dev \
    libzip-dev \
    zip \
    unzip \
    icu-dev \
    oniguruma-dev \
    libxml2-dev \
    linux-headers \
    $PHPIZE_DEPS \
    mysql-client \
    supervisor

# Configure GD extension
RUN docker-php-ext-configure gd \
    --with-freetype \
    --with-jpeg \
    --with-webp

# Install PHP extensions
RUN docker-php-ext-install \
    pdo \
    pdo_mysql \
    mysqli \
    mbstring \
    exif \
    pcntl \
    bcmath \
    gd \
    zip \
    intl \
    opcache \
    xml \
    soap

# Install Redis extension
RUN pecl install redis && docker-php-ext-enable redis

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Create system user
RUN addgroup -g 1000 www && \
    adduser -u 1000 -G www -h /home/www -D www

# Create log directory
RUN mkdir -p /var/log/php && \
    chown -R www:www /var/log/php

# Set working directory
WORKDIR /var/www/html

# Note: Source code is mounted as volume in docker-compose.yml
# No COPY needed here

# Switch to non-root user
USER www

# Expose port 9000
EXPOSE 9000

CMD ["php-fpm"]
