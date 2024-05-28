FROM ghcr.io/linuxserver/baseimage-alpine-nginx:3.20

ARG BUILD_DATE
ARG VERSION
ARG MONICA_VERSION
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="thespad"
ARG MONICA_RELEASE_GPG_KEY="BDAB0D0D36A00466A2964E85DE15667131EA6018"
ENV MEMORY_LIMIT 512M


RUN \
  apk add --no-cache --virtual=build-dependencies \
    bzip2 \
    gpg \
    gpg-agent \
    gnupg && \
  apk add --no-cache \
    memcached \
    php83-apcu \
    php83-bcmath \
    php83-dom \
    php83-gd \
    php83-gmp \
    php83-intl \
    php83-pecl-memcached \
    php83-mysqli \
    php83-pdo_mysql \
    php83-redis \
    php83-sodium \
    php83-soap \
    php83-tokenizer \
    php83-xmlreader \
    postgresql15-client && \
  echo "**** configure php-fpm to pass env vars ****" && \
  sed -E -i 's/^;?clear_env ?=.*$/clear_env = no/g' /etc/php83/php-fpm.d/www.conf && \
  grep -qxF 'clear_env = no' /etc/php83/php-fpm.d/www.conf || echo 'clear_env = no' >> /etc/php83/php-fpm.d/www.conf && \
  echo "env[PATH] = /usr/local/bin:/usr/bin:/bin:/" >> /etc/php83/php-fpm.conf && \
  echo "**** setup php opcache ****" && \
  { \
      echo '[opcache]'; \
      echo 'opcache.enable=1'; \
      echo 'opcache.revalidate_freq=0'; \
      echo 'opcache.validate_timestamps=0'; \
      echo 'opcache.max_accelerated_files=20000'; \
      echo 'opcache.memory_consumption=192'; \
      echo 'opcache.max_wasted_percentage=10'; \
      echo 'opcache.interned_strings_buffer=16'; \
      echo 'opcache.fast_shutdown=1'; \
  } > /etc/php83/conf.d/opcache-recommended.ini; \
  \
  echo 'apc.enable_cli=1' >> /etc/php83/conf.d/docker-php-ext-apcu.ini; \
  \
  { \
      echo 'memory_limit=${MEMORY_LIMIT}'; \
  } > /etc/php83/conf.d/memory-limit.ini && \
  echo "**** install monica ****" && \
  mkdir -p /app/www && \
  if [ -z ${MONICA_VERSION+x} ]; then \
    MONICA_VERSION=$(curl -sX GET "https://api.github.com/repos/monicahq/monica/releases/latest" \
    | awk '/tag_name/{print $4;exit}' FS='[""]'); \
  fi && \
  curl -s -o \
    /tmp/monica.tar.bz2 -L \
    "https://github.com/monicahq/monica/releases/download/${MONICA_VERSION}/monica-${MONICA_VERSION}.tar.bz2" && \
  curl -s -o \
    "/tmp/monica.tar.bz2.asc" -L \
    "https://github.com/monicahq/monica/releases/download/${MONICA_VERSION}/monica-${MONICA_VERSION}.tar.bz2.asc" && \
  export GNUPGHOME="$(mktemp -d)" && \
  gpg --batch -q --keyserver keyserver.ubuntu.com --recv-keys "$MONICA_RELEASE_GPG_KEY" \
      || gpg --batch -q --keyserver pgp.mit.edu --recv-keys "$MONICA_RELEASE_GPG_KEY" \
      || gpg --batch -q --keyserver keyserver.pgp.com --recv-keys "$MONICA_RELEASE_GPG_KEY" \
      || gpg --batch -q --keyserver keys.openpgp.org --recv-keys "$MONICA_RELEASE_GPG_KEY" && \
  if ! gpg --batch -q --verify "/tmp/monica.tar.bz2.asc" "/tmp/monica.tar.bz2"; then \
    echo "File signature mismatch" \
    exit 1; \
  fi && \
  tar xf \
    /tmp/monica.tar.bz2 -C \
    /app/www --strip-components=1 && \
  cd /app/www && \
  composer install \
    --no-dev \
    --no-interaction && \
  printf "Linuxserver.io version: ${VERSION}\nBuild-date: ${BUILD_DATE}" > /build_version && \
  echo "**** cleanup ****" && \
  apk del --purge \
    build-dependencies && \
  rm -rf \
    /tmp/*

COPY root/ /

EXPOSE 80 443

VOLUME /config
