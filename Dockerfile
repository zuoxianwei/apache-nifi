# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements. See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership. The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License. You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied. See the License for the
# specific language governing permissions and limitations
# under the License.
#

FROM openjdk:8-jre
LABEL maintainer="Apache NiFi <dev@nifi.apache.org>"
LABEL site="https://nifi.apache.org"

ARG UID=1000
ARG GID=1000
ARG NIFI_VERSION=1.6.0
ARG MIRROR=https://archive.apache.org/dist

ENV NIFI_BASE_DIR /opt/nifi 
ENV NIFI_HOME=${NIFI_BASE_DIR}/nifi-${NIFI_VERSION} \
    NIFI_TOOLKIT_HOME=$NIFI_BASE_DIR/nifi-toolkit-$NIFI_VERSION \
    NIFI_BINARY_URL=/nifi/${NIFI_VERSION}/nifi-${NIFI_VERSION}-bin.tar.gz \
    NIFI_TOOLKIT_URL=/nifi/${NIFI_VERSION}/nifi-toolkit-${NIFI_VERSION}-bin.tar.gz

# Setup NiFi user
RUN groupadd -g ${GID} nifi || groupmod -n nifi `getent group ${GID} | cut -d: -f1` \
    && useradd --shell /bin/bash -u ${UID} -g ${GID} -m nifi \
    && mkdir -p ${NIFI_HOME}/conf/templates \
    && mkdir -p $NIFI_BASE_DIR/data \
    && mkdir -p $NIFI_BASE_DIR/flowfile_repository \
    && mkdir -p $NIFI_BASE_DIR/content_repository \
    && mkdir -p $NIFI_BASE_DIR/provenance_repository \
    && mkdir -p $NIFI_BASE_DIR/logs \
    && chown -R nifi:nifi ${NIFI_BASE_DIR} \ 
    && apt-get update \
    && apt-get install -y jq xmlstarlet procps

# Download, validate, and expand Apache NiFi binary and Nifi tools binary.
RUN curl -fSL ${MIRROR}/${NIFI_BINARY_URL} -o ${NIFI_BASE_DIR}/nifi-${NIFI_VERSION}-bin.tar.gz \
    && echo "$(curl ${MIRROR}/${NIFI_BINARY_URL}.sha256) *${NIFI_BASE_DIR}/nifi-${NIFI_VERSION}-bin.tar.gz" | sha256sum -c - \
    && tar -xvzf ${NIFI_BASE_DIR}/nifi-${NIFI_VERSION}-bin.tar.gz -C ${NIFI_BASE_DIR} \
    && rm ${NIFI_BASE_DIR}/nifi-${NIFI_VERSION}-bin.tar.gz \
    && curl -fSL ${MIRROR}/${NIFI_TOOLKIT_URL} -o ${NIFI_BASE_DIR}/nifi-toolkit-${NIFI_VERSION}-bin.tar.gz \
    && echo "$(curl ${MIRROR}/${NIFI_TOOLKIT_URL}.sha256) *${NIFI_BASE_DIR}/nifi-toolkit-${NIFI_VERSION}-bin.tar.gz" | sha256sum -c - \
    && tar -xvzf ${NIFI_BASE_DIR}/nifi-toolkit-${NIFI_VERSION}-bin.tar.gz -C ${NIFI_BASE_DIR} \
    && rm ${NIFI_BASE_DIR}/nifi-toolkit-${NIFI_VERSION}-bin.tar.gz \
    && chown -R nifi:nifi ${NIFI_HOME}

# Establish best practices for running NiFi
RUN echo "*  hard  nofile  50000" >> /etc/security/limits.conf \
    && echo "*  soft  nofile  50000" >> /etc/security/limits.conf \
    && echo "*  hard  nproc  10000" >> /etc/security/limits.conf \
    && echo "*  soft  nproc  10000" >> /etc/security/limits.conf \
    && echo "vm.swappiness = 0" >> /etc/sysctl.conf \
    && sysctl -w net.ipv4.netfilter.ip_conntrack_tcp_timeout_time_wait="1" \
    && sysctl -w net.ipv4.ip_local_port_range="10000 65000"

# Web HTTP(s) & Socket Site-to-Site Ports
EXPOSE 8080 8443 10000

COPY ./files/nifi-env.sh $NIFI_HOME/bin/nifi-env.sh

COPY ./files/docker-entrypoint.sh /
RUN chmod 700 /docker-entrypoint.sh

WORKDIR $NIFI_HOME

# Apply configuration and start NiFi
ENTRYPOINT      ["/docker-entrypoint.sh"]
CMD             ["bin/nifi.sh", "run"]
