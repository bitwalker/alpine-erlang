FROM alpine:3.12.1 AS build

# Important!  Update this no-op ENV variable when this Dockerfile
# is updated with the current date. It will force refresh of all
# of the base images and things like `apt-get update` won't be using
# old cached versions when the Dockerfile is built.
ENV REFRESHED_AT=2020-11-09 \
    LANG=en_US.UTF-8 \
    HOME=/opt/app/ \
    TERM=xterm \
    ERLANG_VERSION=23.1.2

# Add tagged repos as well as the edge repo so that we can selectively install edge packages
RUN \
    echo "@main http://dl-cdn.alpinelinux.org/alpine/v3.12/main" >> /etc/apk/repositories && \
    echo "@community http://dl-cdn.alpinelinux.org/alpine/v3.12/community" >> /etc/apk/repositories && \
    echo "@edge http://dl-cdn.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories

# Upgrade Alpine and base packages
RUN apk --no-cache --update --available upgrade

# Install bash and Erlang/OTP deps
RUN \
    apk add --no-cache --update pcre@edge && \
    apk add --no-cache --update \
      bash \
      ca-certificates \
      openssl-dev \
      ncurses-dev \
      unixodbc-dev \
      zlib-dev

# Install Erlang/OTP build deps
RUN \
    apk add --no-cache --virtual .erlang-build \
      dpkg-dev \
      dpkg \
      binutils \
      git \
      autoconf \
      build-base \
      perl-dev

WORKDIR /tmp/erlang-build

COPY patches /tmp/patches

# Clone, Configure, Build
RUN \
    # Shallow clone Erlang/OTP
    git clone -b OTP-$ERLANG_VERSION --single-branch --depth 1 https://github.com/erlang/otp.git . && \
    # Erlang/OTP build env
    export ERL_TOP=/tmp/erlang-build && \
    export PATH=$ERL_TOP/bin:$PATH && \
    export CPPFlAGS="-D_BSD_SOURCE $CPPFLAGS" && \
    # Configure
    ./otp_build autoconf && \
    ./configure \
      --prefix=/usr/local \
      --build="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
      --sysconfdir=/etc \
      --mandir=/usr/share/man \
      --infodir=/usr/share/info \
      --without-javac \
      --without-wx \
      --without-debugger \
      --without-observer \
      --without-jinterface \
      --without-cosEvent\
      --without-cosEventDomain \
      --without-cosFileTransfer \
      --without-cosNotification \
      --without-cosProperty \
      --without-cosTime \
      --without-cosTransactions \
      --without-et \
      --without-gs \
      --without-ic \
      --without-megaco \
      --without-orber \
      --without-percept \
      --without-typer \
      --enable-threads \
      --enable-shared-zlib \
      --enable-ssl=dynamic-ssl-lib \
      --enable-hipe && \
    make -j4

# Install to temporary location
RUN \
    make DESTDIR=/tmp install && \
    # Strip install to reduce size
    ln -s /tmp/usr/local/lib/erlang /usr/local/lib/erlang && \
    /tmp/usr/local/bin/erl -eval "beam_lib:strip_release('/tmp/usr/local/lib/erlang/lib')" -s init stop > /dev/null && \
    (/usr/bin/strip /tmp/usr/local/lib/erlang/erts-*/bin/* || true) && \
    rm -rf /tmp/usr/local/lib/erlang/usr/ && \
    rm -rf /tmp/usr/local/lib/erlang/misc/ && \
    for DIR in /tmp/usr/local/lib/erlang/erts* /tmp/usr/local/lib/erlang/lib/*; do \
        rm -rf ${DIR}/src/*.erl; \
        rm -rf ${DIR}/doc; \
        rm -rf ${DIR}/man; \
        rm -rf ${DIR}/examples; \
        rm -rf ${DIR}/emacs; \
        rm -rf ${DIR}/c_src; \
    done && \
    rm -rf /tmp/usr/local/lib/erlang/erts-*/lib/ && \
    rm /tmp/usr/local/lib/erlang/erts-*/bin/dialyzer && \
    rm /tmp/usr/local/lib/erlang/erts-*/bin/erlc && \
    rm /tmp/usr/local/lib/erlang/erts-*/bin/typer && \
    rm /tmp/usr/local/lib/erlang/erts-*/bin/ct_run

### Final Image

FROM alpine:3.12.1

MAINTAINER Paul Schoenfelder <paulschoenfelder@gmail.com>

ENV LANG=en_US.UTF-8 \
    HOME=/opt/app/ \
    # Set this so that CTRL+G works properly
    TERM=xterm \
    PATH=/usr/local/bin:${PATH}

# Copy Erlang/OTP installation
COPY --from=build /tmp/usr/local /usr/local

WORKDIR ${HOME}

RUN \
    # Create default user and home directory, set owner to default
    adduser -s /bin/sh -u 1001 -G root -h "${HOME}" -S -D default && \
    chown -R 1001:0 "${HOME}" && \
    # Add tagged repos as well as the edge repo so that we can selectively install edge packages
    echo "@main http://dl-cdn.alpinelinux.org/alpine/v3.12/main" >> /etc/apk/repositories && \
    echo "@community http://dl-cdn.alpinelinux.org/alpine/v3.12/community" >> /etc/apk/repositories && \
    echo "@edge http://dl-cdn.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories && \
    # Upgrade Alpine and base packages
    apk --no-cache --update --available upgrade && \
    # Install bash and Erlang/OTP deps
    apk add --no-cache --update pcre@edge && \
    apk add --no-cache --update \
      bash \
      ca-certificates \
      openssl \
      ncurses \
      unixodbc \
      zlib && \
    # Update ca certificates
    update-ca-certificates --fresh

CMD ["/usr/bin/bash"]
