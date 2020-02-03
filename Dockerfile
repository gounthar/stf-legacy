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
RUN export DEBIAN_FRONTEND=noninteractive && \
    adduser \
      -s /sbin/nologin -S stf \
      stf-build && \
    adduser \
      -s /sbin/nologin -S stf-build \
      stf && \
#    sed -i'' 's@http://archive.ubuntu.com/ubuntu/@mirror://mirrors.ubuntu.com/mirrors.txt@' /etc/apt/sources.list && \
    apk update && apk upgrade 
    
RUN apk add --no-cache --virtual build-dependencies \
        build-base \
        gcc \
        wget \
        git \
        protobuf-dev \
        zeromq-dev \
        wget \
        python \
        bash \
        nodejs \
        npm 
    
#RUN curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py && python get-pip.py && which pip 
#ENV NODE_VERSION "v13.7.0"
#RUN mkdir mkdir -p /opt && cd /opt/ && \
#  curl http://nodejs.org/dist/$NODE_VERSION/node-$NODE_VERSION-linux-armv7l.tar.gz -o node-$NODE_VERSION-linux-armv7l.tar.gz && \
#  tar xzf node-$NODE_VERSION-linux-armv7l.tar.gz && mv node-$NODE_VERSION-linux-armv7l node
#ENV PATH "$PATH:/opt/node/bin"
#RUN echo "export PATH=$PATH:/opt/node/bin" >> ~/.bash_profile
#RUN ln -s /opt/node/bin/node /usr/bin/node && ln -s /opt/node/lib/node /usr/lib/node && 
RUN ln -s /opt/node/bin/node-waf /usr/bin/node-waf && node -v && npm -v

RUN  su stf-build -s /bin/bash -c '/usr/lib/node_modules/npm/node_modules/node-gyp/bin/node-gyp.js install' && \
    apk add --no-cache graphicsmagick yasm && \
    apk cache clean && apk del build-dependencies && \
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
