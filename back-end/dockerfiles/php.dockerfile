FROM php:8.3-fpm-alpine3.21

ARG UID=1000
ARG GID=1000
ARG USER=laravel

ENV UID=${UID}
ENV GID=${GID}
ENV USER=${USER}

RUN mkdir -p /var/www/html

WORKDIR /var/www/html

# MacOS staff group's gid is 20, so is the dialout group in alpine linux. We're not using it, let's just remove it.
RUN delgroup dialout

RUN addgroup -g ${GID} --system ${USER}
RUN adduser -G ${USER} --system -D -s /bin/sh -u ${UID} ${USER}

RUN sed -i "s/user = www-data/user = ${USER}/g" /usr/local/etc/php-fpm.d/www.conf
RUN sed -i "s/group = www-data/group = ${USER}/g" /usr/local/etc/php-fpm.d/www.conf
RUN echo "php_admin_flag[log_errors] = on" >> /usr/local/etc/php-fpm.d/www.conf

RUN apk add --no-cache \
    libpng-dev \
    jpeg-dev \
    zip \
    libzip-dev \
    && docker-php-ext-configure gd --enable-gd --with-jpeg \
    && docker-php-ext-install gd zip pdo pdo_mysql exif

RUN mkdir -p /usr/src/php/ext/redis \
    && curl -L https://github.com/phpredis/phpredis/archive/5.3.4.tar.gz | tar xvz -C /usr/src/php/ext/redis --strip 1 \
    && echo 'redis' >> /usr/src/php-available-exts \
    && docker-php-ext-install redis

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

CMD ["php-fpm", "-y", "/usr/local/etc/php-fpm.conf", "-R"]
