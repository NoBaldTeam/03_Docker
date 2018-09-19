FROM jenkins/slave:3.23-1
MAINTAINER hongbin.che<hongbin.che@itel-mobile.com>
LABEL Description="This is a base image, which allows connecting Jenkins agents via JNLP protocols" Vendor="Jenkins project" Version="3.23"

USER root
RUN apt-get update && apt-get install -y git curl vim unzip zip && rm -rf /var/lib/apt/lists/*

ARG user=apkserver
ARG group=apkserver
ARG userpass=apkserver
ARG gid=1007
ARG uid=1007

ENV JENKINS_HOME /var/jenkins_home
ENV ANDROID_HOME /usr/local/android-sdk-linux
ENV ANDROID_NDK_HOME /usr/local/android-ndk-r13
ENV GRADLE_HOME /usr/local/gradle-4.4
ENV JAVA_HOME /usr/local/jdk1.8.0_161

# make jenkins user as root
RUN apt-get update &&  apt-get -y install sudo
RUN groupadd -g ${gid} ${group} \
    && useradd -d "$JENKINS_HOME" -u ${uid} -g ${gid} -G root -m -s /bin/bash ${user} 
RUN adduser  ${user} sudo
RUN echo 'apkserver:apkserver'|chpasswd

# 可在创建容器的时候进行劵的挂载 到 、jenkins home
#VOLUME /var/jenkins_home
# 挂载宿主机android环境到jenkins镜像，创建容器时可覆盖
VOLUME /usr/local/android-sdk-linux
VOLUME /usr/local/android-ndk-r13
VOLUME /usr/local/gradle-4.4
VOLUME /usr/local/jdk1.8.0_161


ENV PATH ${PATH}:${ANDROID_NDK_HOME}
ENV PATH ${PATH}:${ANDROID_HOME}/tools:${ANDROID_HOME}/platform-tool
ENV PATH ${PATH}:${GRADLE_HOME}:${GRADLE_HOME}/bin
ENV PATH ${PATH}:${JAVA_HOME}:${JAVA_HOME}/bin

# 写入android环境到jenkins镜像环境变量
RUN echo "export PATH=${PATH}:${ANDROID_HOME}/tools:${ANDROID_HOME}/platform-tools" >> /etc/profile
RUN echo "export PATH=${PATH}:${ANDROID_NDK_HOME}" >> /etc/profile
RUN echo "export PATH=${PATH}:${GRADLE_HOME}/bin" >> /etc/profile
RUN echo "export PATH=${PATH}:${JAVA_HOME}/bin" >> /etc/profile

USER root

COPY jenkins-slave /usr/local/bin/jenkins-slave

ENTRYPOINT ["jenkins-slave"]

USER root
