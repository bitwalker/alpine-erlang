FROM alpine:3.7

MAINTAINER Paul Schoenfelder <paulschoenfelder@gmail.com>

# Important!  Update this no-op ENV variable when this Dockerfile
# is updated with the current date. It will force refresh of all
# of the base images and things like `apt-get update` won't be using
# old cached versions when the Dockerfile is built.
ENV REFRESHED_AT=2017-12-11 \
    LANG=en_US.UTF-8 \
    HOME=/opt/app/ \
    BUILD_TEMP=/tmp/erlang-build \
    # Set this so that CTRL+G works properly
    TERM=xterm \
    ERLANG_VERSION=20.1.7

# Install Erlang
RUN \
    # Create default user and home directory, set owner to default
    mkdir -p "${HOME}" && \
    adduser -s /bin/sh -u 1001 -G root -h "${HOME}" -S -D default && \
    chown -R 1001:0 "${HOME}" && \
    # Add tagged repos as well as the edge repo so that we can selectively install edge packages
    echo "@main http://dl-cdn.alpinelinux.org/alpine/v3.7/main" >> /etc/apk/repositories && \
    echo "@community http://dl-cdn.alpinelinux.org/alpine/v3.7/community" >> /etc/apk/repositories && \
    echo "@edge http://nl.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories && \
    # Upgrade Alpine and base packages
    apk --no-cache upgrade && \
    # Distillery requires bash
    apk add --no-cache bash@main && \
    # Install Erlang/OTP deps
    apk add --no-cache pcre@edge && \
    apk add --no-cache \
      ca-certificates@main \
      openssl-dev@main \
      ncurses-dev@main \
      unixodbc-dev@main \
      zlib-dev@main && \
    # Install Erlang/OTP build deps
    apk add --no-cache --virtual .erlang-build \
      dpkg-dev@main dpkg@main \
      git@main autoconf@main build-base@main perl-dev@main && \
    mkdir -p ${BUILD_TEMP} && \
    # Shallow clone Erlang/OTP
    git clone -b OTP-$ERLANG_VERSION --single-branch --depth 1 https://github.com/erlang/otp.git ${BUILD_TEMP} && \
    cd ${BUILD_TEMP} && \
    # Erlang/OTP build env
    export ERL_TOP=${BUILD_TEMP} && \
    export PATH=$ERL_TOP/bin:$PATH && \
    export CPPFlAGS="-D_BSD_SOURCE $CPPFLAGS" && \
    # Configure
    ./otp_build autoconf && \
    ./configure --prefix=/usr \
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
    # Build
    make -j4 && make install && \
    # Cleanup
    apk del --force .erlang-build && \
    cd $HOME && \
    rm -rf ${BUILD_TEMP} && \
    # Update ca certificates
    update-ca-certificates --fresh

WORKDIR ${HOME}

CMD ["/bin/sh"]
