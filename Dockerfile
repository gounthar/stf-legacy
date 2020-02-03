FROM gounthar/alpine-linux-curl:latest
# Sneak the stf executable into $PATH.
ENV PATH /app/bin:$PATH

# Work in app dir by default.
WORKDIR /app

# Export default app port, not enough for all processes but it should do
# for now.
EXPOSE 3000

# Install app requirements. Trying to optimize push speed for dependant apps
# by reducing layers as much as possible. Note that one of the final steps
# installs development files for node-gyp so that npm install won't have to
# wait for them on the first native module installation.
RUN export DEBIAN_FRONTEND=noninteractive && \
    adduser \
      -s /sbin/nologin -S stf \
      stf-build && \
    adduser \
      -s /sbin/nologin -S stf-build \
      stf && \
#    sed -i'' 's@http://archive.ubuntu.com/ubuntu/@mirror://mirrors.ubuntu.com/mirrors.txt@' /etc/apt/sources.list && \
    apk update && \
    apk add --virtual build-dependencies \
        build-base \
        gcc \
        wget \
    git && \
    apk add wget python bash nodejs && \
    cd /tmp && touch /bin/node-install
RUN curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py && python get-pip.py && \
    wget -O- https://raw.githubusercontent.com/audstanley/NodeJs-Raspberry-Pi/master/Install-Node.sh | bash && \ 
    node -v && \
    wget --progress=dot:mega \
      https://nodejs.org/dist/v6.11.2/node-v6.11.2-linux-arm64.tar.xz && \
#    tar -xJf node-v*.tar.xz --strip-components 1 -C /usr/local && \
#    rm node-v*.tar.xz && \
    su stf-build -s /bin/bash -c '/usr/local/lib/node_modules/npm/node_modules/node-gyp/bin/node-gyp.js install' && \
    apk add libzmq3-dev libprotobuf-dev git graphicsmagick yasm && \
    apk clean && \
    rm -rf /var/cache/apt/* /var/lib/apt/lists/*

# Copy app source.
COPY . /tmp/build/

# Give permissions to our build user.
RUN mkdir -p /app && \
    chown -R stf-build:stf-build /tmp/build /app

# Switch over to the build user.
USER stf-build

# Run the build.
RUN set -x && \
    cd /tmp/build && \
    export PATH=$PWD/node_modules/.bin:$PATH && \
    npm install --loglevel http && \
    npm pack && \
    tar xzf stf-*.tgz --strip-components 1 -C /app && \
    bower cache clean && \
    npm prune --production && \
    mv node_modules /app && \
    npm cache clean && \
    rm -rf ~/.node-gyp && \
    cd /app && \
    rm -rf /tmp/*

# Switch to the app user.
USER stf

# Show help by default.
CMD stf --help
RUN ["cross-build-end"]
