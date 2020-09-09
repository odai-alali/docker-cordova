FROM ubuntu:18.04
MAINTAINER Odai Alali

# -----------------------------------------------------------------------------
# General environment variables
# -----------------------------------------------------------------------------
ENV DEBIAN_FRONTEND=noninteractive

# -----------------------------------------------------------------------------
# Install system basics
# -----------------------------------------------------------------------------
RUN \
  apt-get update -qqy && \
  apt-get install -qqy --allow-unauthenticated \
          apt-transport-https \
          software-properties-common \
          python \
          make \
          g++ \
          curl \
          expect \
          zip \
          libsass-dev \
          git \
          sudo

# -----------------------------------------------------------------------------
# Install Java
# -----------------------------------------------------------------------------
ARG JAVA_VERSION
ENV JAVA_VERSION ${JAVA_VERSION:-8}

ENV JAVA_HOME ${JAVA_HOME:-/usr/lib/jvm/java-${JAVA_VERSION}-openjdk-amd64}
# For JDK 9 and JDK 10 uncomment the following
#ENV JAVA_OPTS '-XX:+IgnoreUnrecognizedVMOptions --add-modules java.se.ee'

RUN add-apt-repository ppa:openjdk-r/ppa -y && \
  apt-get update -qqy && \
  apt-get install openjdk-${JAVA_VERSION}-jdk -qqy

# -----------------------------------------------------------------------------
# Install Android / Android SDK / Android SDK elements
# -----------------------------------------------------------------------------

ENV ANDROID_HOME /opt/android-sdk-linux
ENV PATH ${PATH}:${ANDROID_HOME}/tools:${ANDROID_HOME}/tools/bin:${ANDROID_HOME}/platform-tools:/opt/tools

# Check https://cordova.apache.org/docs/en/latest/guide/platforms/android/ first, and make sure you've the latest "cordova-android" in package.json
ARG ANDROID_PLATFORMS_VERSION
ENV ANDROID_PLATFORMS_VERSION ${ANDROID_PLATFORMS_VERSION:-29}

ARG ANDROID_BUILD_TOOLS_VERSION
ENV ANDROID_BUILD_TOOLS_VERSION ${ANDROID_BUILD_TOOLS_VERSION:-29.0.3}

RUN \
  echo ANDROID_HOME=${ANDROID_HOME} >> /etc/environment && \
  dpkg --add-architecture i386 && \
  apt-get update -qqy && \
  apt-get install -qqy --allow-unauthenticated\
          gradle  \
          libc6-i386 \
          lib32stdc++6 \
          lib32gcc1 \
          lib32ncurses5 \
          lib32z1 \
          qemu-kvm \
          kmod && \
  mkdir -p /root/.android && touch /root/.android/repositories.cfg  && \
  cd /opt && \
  curl -SLo sdk-tools-linux.zip https://dl.google.com/android/repository/sdk-tools-linux-4333796.zip && \
  unzip sdk-tools-linux.zip -d ${ANDROID_HOME} && rm -f sdk-tools-linux.zip && chmod 775 ${ANDROID_HOME} -R && \
  yes | sdkmanager --update  && yes | sdkmanager --licenses && \
  sdkmanager "tools" && \
  sdkmanager "platform-tools" && \
  sdkmanager "platforms;android-${ANDROID_PLATFORMS_VERSION}" && \
  sdkmanager "build-tools;${ANDROID_BUILD_TOOLS_VERSION}"

# -----------------------------------------------------------------------------
# Install Node, NPM, yarn
# -----------------------------------------------------------------------------
ARG NODE_VERSION
ENV NODE_VERSION ${NODE_VERSION:-12.18.3}

ARG PACKAGE_MANAGER
ENV PACKAGE_MANAGER ${PACKAGE_MANAGER:-npm}

RUN buildDeps='xz-utils' \
    && ARCH= && dpkgArch="$(dpkg --print-architecture)" \
    && case "${dpkgArch##*-}" in \
     amd64) ARCH='x64';; \
     ppc64el) ARCH='ppc64le';; \
     s390x) ARCH='s390x';; \
     arm64) ARCH='arm64';; \
     armhf) ARCH='armv7l';; \
     i386) ARCH='x86';; \
     *) echo "unsupported architecture"; exit 1 ;; \
    esac \
    # gpg keys listed at https://github.com/nodejs/node#release-keys
    && set -ex \
    && for key in \
     94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
     FD3A5288F042B6850C66B31F09FE44734EB7990E \
     71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
     DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
     C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
     B9AE9905FFD7803F25714661B63B535A4C206CA9 \
     77984A986EBC2AA786BC0F66B01FBB92821C587A \
     8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
     4ED778F539E3634C779C87C6D7062848A1AB005C \
     A48C2BEE680E841632CD4E44F07496B3EB3C1762 \
     B9E2F5981AA6E0CD28160D9FF13993A75599653C \
    ; do \
     gpg --batch --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$key" || \
     gpg --batch --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "$key" || \
     gpg --batch --keyserver hkp://pgp.mit.edu:80 --recv-keys "$key" ; \
    done \
    && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-$ARCH.tar.xz" \
    && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
    && gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \
    && grep " node-v$NODE_VERSION-linux-$ARCH.tar.xz\$" SHASUMS256.txt | sha256sum -c - \
    && tar -xJf "node-v$NODE_VERSION-linux-$ARCH.tar.xz" -C /usr/local --strip-components=1 --no-same-owner \
    && rm "node-v$NODE_VERSION-linux-$ARCH.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt \
    && ln -s /usr/local/bin/node /usr/local/bin/nodejs

ARG YARN_VERSION
ENV YARN_VERSION ${YARN_VERSION:-1.22.5}

RUN set -ex \
  && for key in \
    6A010C5166006599AA17F08146C2130DFD2497F5 \
  ; do \
    gpg --batch --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$key" || \
    gpg --batch --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "$key" || \
    gpg --batch --keyserver hkp://pgp.mit.edu:80 --recv-keys "$key" ; \
  done \
  && curl -fsSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz" \
  && curl -fsSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz.asc" \
  && gpg --batch --verify yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz \
  && mkdir -p /opt \
  && tar -xzf yarn-v$YARN_VERSION.tar.gz -C /opt/ \
  && ln -s /opt/yarn-v$YARN_VERSION/bin/yarn /usr/local/bin/yarn \
  && ln -s /opt/yarn-v$YARN_VERSION/bin/yarnpkg /usr/local/bin/yarnpkg \
  && rm yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz

# -----------------------------------------------------------------------------
# Clean up
# -----------------------------------------------------------------------------
RUN \
  apt-get clean && \
  apt-get autoclean && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# -----------------------------------------------------------------------------
# Install Global node modules
# -----------------------------------------------------------------------------

ARG CORDOVA_VERSION
ENV CORDOVA_VERSION ${CORDOVA_VERSION:-10.0.0}

RUN \
  if [ "${PACKAGE_MANAGER}" != "yarn" ]; then \
    npm install -g cordova@"${CORDOVA_VERSION}" cordova-check-plugins; \
  else \
    yarn global add cordova@"${CORDOVA_VERSION}" cordova-check-plugins && \
    export PATH="$(yarn global bin):$PATH"; \
  fi && \
  ${PACKAGE_MANAGER} cache clean --force

RUN echo 'n' | cordova

# -----------------------------------------------------------------------------
# WORKDIR is the generic /app folder. All volume mounts of the actual project
# code need to be put into /app.
# -----------------------------------------------------------------------------
WORKDIR /app