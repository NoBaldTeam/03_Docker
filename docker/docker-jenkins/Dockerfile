FROM openjdk:8-jdk

RUN apt-get update && apt-get install -y git curl vim unzip zip && rm -rf /var/lib/apt/lists/*

ARG user=jenkins
ARG group=jenkins
ARG userpass=jenkins
ARG gid=1002
ARG uid=1002
ARG http_port=8080
ARG agent_port=50000

ENV JENKINS_HOME /var/jenkins_home
ENV JENKINS_SLAVE_AGENT_PORT ${agent_port}
ENV ANDROID_HOME /usr/local/android-sdk-linux
ENV ANDROID_NDK_HOME /usr/local/android-ndk-r13
ENV GRADLE_HOME /usr/local/gradle-4.4


# Jenkins is run with user `jenkins`, uid = 1000
# If you bind mount a volume from the host or a data container,
# ensure you use the same uid
# make jenkins user as root
RUN apt-get update &&  apt-get -y install sudo
RUN groupadd -g ${gid} ${group} \
    && useradd -d "$JENKINS_HOME" -u ${uid} -g ${gid} -G root -m -s /bin/bash ${user} 
RUN adduser  ${user} sudo
RUN echo 'jenkins:jenkins'|chpasswd

# Jenkins home directory is a volume, so configuration and build history
# can be persisted and survive image upgrades
# 可在创建容器的时候进行劵的挂载 到 、jenkins home
#VOLUME /var/jenkins_home
# 挂载宿主机android环境到jenkins镜像，创建容器时可覆盖
VOLUME /usr/local/android-sdk-linux
VOLUME /usr/local/android-ndk-r13
VOLUME /usr/local/gradle-4.4
VOLUME /mnt/APK_Test_Version
VOLUME /mnt/APK_Release_Version
VOLUME /work/workspace/jenkins/proj

RUN  chown jenkins:jenkins -R /work

ENV PATH ${PATH}:${ANDROID_NDK_HOME}
ENV PATH ${PATH}:${ANDROID_HOME}/tools:${ANDROID_HOME}/platform-tool
ENV PATH ${PATH}:${GRADLE_HOME}:${GRADLE_HOME}/bin

# 写入android环境到jenkins镜像环境变量
RUN echo "export PATH=${PATH}:${ANDROID_HOME}/tools:${ANDROID_HOME}/platform-tools" >> /etc/profile
RUN echo "export PATH=${PATH}:${ANDROID_NDK_HOME}" >> /etc/profile
RUN echo "export PATH=${PATH}:${GRADLE_HOME}/bin" >> /etc/profile
# `/usr/share/jenkins/ref/` contains all reference configuration we want
# to set on a fresh new installation. Use it to bundle additional plugins
# or config file with your custom jenkins Docker image.
RUN mkdir -p /usr/share/jenkins/ref/init.groovy.d
RUN mkdir -p /var/jenkins_home
# Use tini as subreaper in Docker container to adopt zombie processes
ARG TINI_VERSION=v0.16.1
COPY tini_pub.gpg /var/jenkins_home/tini_pub.gpg
RUN curl -fsSL https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-static-$(dpkg --print-architecture) -o /sbin/tini \
  && curl -fsSL https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-static-$(dpkg --print-architecture).asc -o /sbin/tini.asc \
  && gpg --import /var/jenkins_home/tini_pub.gpg \
  && gpg --verify /sbin/tini.asc \
  && rm -rf /sbin/tini.asc /root/.gnupg \
  && chmod +x /sbin/tini

COPY init.groovy /usr/share/jenkins/ref/init.groovy.d/tcp-slave-agent-port.groovy

# jenkins version being bundled in this docker image
ARG JENKINS_VERSION
ENV JENKINS_VERSION ${JENKINS_VERSION:-2.60.3}

# jenkins.war checksum, download will be validated using it
ARG JENKINS_SHA=2d71b8f87c8417f9303a73d52901a59678ee6c0eefcf7325efed6035ff39372a

# Can be used to customize where jenkins.war get downloaded from
ARG JENKINS_URL=https://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/${JENKINS_VERSION}/jenkins-war-${JENKINS_VERSION}.war

# could use ADD but this one does not check Last-Modified header neither does it allow to control checksum
# see https://github.com/docker/docker/issues/8331
RUN curl -fsSL ${JENKINS_URL} -o /usr/share/jenkins/jenkins.war \
  && echo "${JENKINS_SHA}  /usr/share/jenkins/jenkins.war" | sha256sum -c -

ENV JENKINS_UC https://updates.jenkins.io
ENV JENKINS_UC_EXPERIMENTAL=https://updates.jenkins.io/experimental
RUN chown -R ${user} "$JENKINS_HOME" /usr/share/jenkins/ref

# for main web interface:
EXPOSE ${http_port}

# will be used by attached slave agents:
EXPOSE ${agent_port}

ENV COPY_REFERENCE_FILE_LOG $JENKINS_HOME/copy_reference_file.log

USER ${user}

COPY jenkins-support /usr/local/bin/jenkins-support
COPY jenkins.sh /usr/local/bin/jenkins.sh
USER root
RUN chmod +x /usr/local/bin/jenkins.sh
USER ${user}
ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/jenkins.sh"]

# from a derived Dockerfile, can use `RUN plugins.sh active.txt` to setup /usr/share/jenkins/ref/plugins from a support bundle
COPY plugins.sh /usr/local/bin/plugins.sh
COPY install-plugins.sh /usr/local/bin/install-plugins.sh
