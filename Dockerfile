FROM gounthar/docker-alpine-curl:latest
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
RUN adduser --shell /sbin/nologin --system stf-build && addgroup stf-build && adduser stf-build stf-build && \
    adduser --shell /sbin/nologin --system stf && addgroup stf && adduser stf stf && \
#    sed -i'' 's@http://archive.ubuntu.com/ubuntu/@mirror://mirrors.ubuntu.com/mirrors.txt@' /etc/apt/sources.list && \
    apk update && apk upgrade 
    
RUN apk add --no-cache --virtual build-dependencies \
        build-base \
        gcc \
        wget \
        fontconfig \
        git \
        make \
        protobuf-dev \
        strace \
        zeromq-dev \
        wget \
        bash && apk add --no-cache nodejs \
        python3 \
        npm 
RUN cd /opt && \
  curl -Ls "https://github.com/dustinblackman/phantomized/releases/download/2.1.1a/dockerized-phantomjs.tar.gz" | tar xz -C / && \
  ./build.sh && \
  wget https://raw.githubusercontent.com/ApioLab/phantomjs-2.1.1-linux-arm/master/phantomjs-2.1.1-linux-arm.tar.bz2 && \
  bunzip2 phantomjs-2.1.1-linux-arm.tar.bz2 && tar xvf phantomjs-2.1.1-linux-arm.tar && rm ./phantomjs-2.1.1-linux-arm.tar && \
  mv phantomjs-2.1.1-linux-arm phantomjs && chmod +x /opt/phantomjs/bin/phantomjs
ENV PATH /opt/phantomjs/bin:$PATH

RUN ln -s /opt/node/bin/node-waf /usr/bin/node-waf && node -v && npm -v && /opt/phantomjs/bin/phantomjs --version

RUN  su stf-build -s /bin/bash -c '/usr/lib/node_modules/npm/node_modules/node-gyp/bin/node-gyp.js install' && \
    apk add --no-cache graphicsmagick yasm 

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
    rm -rf /tmp/* && \
    apk del build-dependencies

# Switch to the app user.
USER stf

# Show help by default.
CMD stf --help
RUN ["cross-build-end"]
