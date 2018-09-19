
## Jenkins中使用Docker容器搭建不同类型的节点

----

[TOC]

> 　　Jenkins中执行构建，往往master只做部署jenkins，执行构建在不同的节点之上，每个节点的环境各不相同，适用于构建不同类型的编译；但是如果需求的环境类型过多，在相同的节点下可能无法兼容，就需要很多的节点。
　　在物理机有限的情况下，这样的需求很难达到；本文在此介绍如何利用docker的容器技术部署jenkins及jenkins的各类特定环境的容器节点，使用docker容器运行jenkins、同时使用docker容器做jenkins节点去执行构建，可大大节省物理机的需求及隔离编译环境不受其他环境的影响。

---

### 1. Docker容器部署jenkins
　　此处基于官方Dockerhub仓库中的jenkins镜像的Dockerfile进行修改定制自己的jenkins镜像，制作镜像前需要考虑的以下因素:(1)权限；(2)需要安装的软件；(3)需要导入的环境变量；(4)jenkins的版本；(5)暴露的端口等。如上因素想好后即可编写适合自己的镜像文件dockerfile。
　　然后在制作运行容器时候的yml文件，编写该文件前需要考虑如下因素：(1)运行容器使用的镜像；(2)映射的端口；(3)需要挂载在宿主机的目录或者文件。
#### 1.1 编写制作jenkins镜像的Dockerfile
　　如下是我基于官方的jenkins镜像的Dockerfile修改后的内容：
关键几个点：(1)容器内创建用户和宿主机用户同名且uid/gid一致；(2)定义JENKINS_HOME等环境变量；(3)定义jenkins版本及对应sha256编码；(4)拷贝执行安装jenkins的脚本到容器中；
```shell
FROM openjdk:8-jdk

RUN apt-get update && apt-get install -y git curl vim unzip zip && rm -rf /var/lib/apt/lists/*

ARG user=apkserver
ARG group=apkserver
ARG userpass=apkserver
ARG gid=1007
ARG uid=1007
ARG http_port=8082
ARG agent_port=50000

ENV JENKINS_HOME /var/jenkins_home
ENV JENKINS_SLAVE_AGENT_PORT ${agent_port}
ENV ANDROID_HOME /usr/local/android-sdk-linux
ENV ANDROID_NDK_HOME /usr/local/android-ndk-r13
ENV GRADLE_HOME /usr/local/gradle-4.4
ENV JAVA_HOME /usr/local/jdk1.8.0_161


# Jenkins is run with user `jenkins`, uid = 1000
# If you bind mount a volume from the host or a data container,
# ensure you use the same uid
# make jenkins user as root
RUN apt-get update &&  apt-get -y install sudo
RUN groupadd -g ${gid} ${group} \
    && useradd -d "$JENKINS_HOME" -u ${uid} -g ${gid} -G root -m -s /bin/bash ${user} 
RUN adduser  ${user} sudo
RUN echo 'apkserver:apkserver'|chpasswd

# Jenkins home directory is a volume, so configuration and build history
# can be persisted and survive image upgrades
# 可在创建容器的时候进行劵的挂载 到 、jenkins home
#VOLUME /var/jenkins_home
# 挂载宿主机android环境到jenkins镜像，创建容器时可覆盖
VOLUME /usr/local/android-sdk-linux
VOLUME /usr/local/android-ndk-r13
VOLUME /usr/local/gradle-4.4
VOLUME /usr/local/jdk1.8.0_161

#RUN  chown apkserver:apkserver -R /work

ENV PATH ${PATH}:${ANDROID_NDK_HOME}
ENV PATH ${PATH}:${ANDROID_HOME}/tools:${ANDROID_HOME}/platform-tool
ENV PATH ${PATH}:${GRADLE_HOME}:${GRADLE_HOME}/bin
ENV PATH ${PATH}:${JAVA_HOME}:${JAVA_HOME}/bin

# 写入android环境到jenkins镜像环境变量
RUN echo "export PATH=${PATH}:${ANDROID_HOME}/tools:${ANDROID_HOME}/platform-tools" >> /etc/profile
RUN echo "export PATH=${PATH}:${ANDROID_NDK_HOME}" >> /etc/profile
RUN echo "export PATH=${PATH}:${GRADLE_HOME}/bin" >> /etc/profile
RUN echo "export PATH=${PATH}:${JAVA_HOME}/bin" >> /etc/profile
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
ENV JENKINS_VERSION ${JENKINS_VERSION:-2.138.1}

# jenkins.war checksum, download will be validated using it
#ARG JENKINS_SHA=2d71b8f87c8417f9303a73d52901a59678ee6c0eefcf7325efed6035ff39372a
ARG JENKINS_SHA=ecb84b6575e86957b902cce5e68e360e6b0768b0921baa405e61d314239e5b27
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
```
　　如上Dockerfile编写完成后，执行：docker build -t  \${image name}:${version tag} . ;创建镜像，至此镜像创建完毕；我执行的命令为：``` docker build -t itel_docker_jenkins_2.138.1:v1.0 .```;完成后执行docker images 可查看到生成的镜像信息。
  [![jenkins images](http://pbdkyxc0r.bkt.clouddn.com/jenkins%20images.png "jenkins images")](http://pbdkyxc0r.bkt.clouddn.com/jenkins%20images.png "jenkins images")
#### 1.2 编写运行jenkins容器的编排YML文件
　　如下是我编写的适合于我的环境的docker-compose.yml文件内容：
关键几个点：(1)创建容器的镜像及版本；(2)容器名称；(3)暴露的端口；(3)环境变量定义；(4)挂载到容器的的目录及文件。
```yaml
jenkins:
  image: itel_jenkins_2.138.1:v1.0
  container_name: jenkins89
  restart: always
  ports:
    - 50000:50000
    - 10.250.1.89:8082:8080
  environment:
    JAVA_OPTS: "-Djava.awt.headless=true"
  volumes:
    - /home/apkserver/jenkins_volume:/var/jenkins_home
    - /usr/local/android-sdk-linux:/usr/local/android-sdk-linux
    - /usr/local/android-ndk-r13:/usr/local/android-ndk-r13
    - /usr/local/gradle-4.4:/usr/local/gradle-4.4
    - /usr/local/jdk1.8.0_161:/usr/local/jdk1.8.0_161
    - /etc/localtime:/etc/localtime
    - /etc/timezone:/etc/timezone
    - /var/run/docker.sock:/var/run/docker.sock
    - /usr/bin/docker:/bin/docker
    - /usr/lib/x86_64-linux-gnu/libltdl.so.7:/usr/lib/x86_64-linux-gnu/libltdl.so.7
    - /var/lib/docker:/var/lib/docker
```
　　编写好如上YAML文件后，在docker-compose.yml所在目录执行```docker-compose up -d```，便能启动容器，启动后执行：```docker  ps```就能看到容器的相关信息，然后打开定义的ip端口就能启动jenkins，首次启动jenkins容器需要输入一串随机的密码，执行```docker logs -f ${容器名称}```就能看到启动容器过程中的log信息，首次启动会输出该随机密码。
 [![jenkins container](http://pbdkyxc0r.bkt.clouddn.com/jenkins%20container.png "jenkins container")](http://pbdkyxc0r.bkt.clouddn.com/jenkins%20container.png "jenkins container")
 [![](http://pbdkyxc0r.bkt.clouddn.com/jenkins%20%E7%95%8C%E9%9D%A2.png)](http://pbdkyxc0r.bkt.clouddn.com/jenkins%20%E7%95%8C%E9%9D%A2.png)
　　如上jenkins镜像及容器创建启动后，就能启动一个jenkins，启动jenkins后，可进行一些基础的配置：账户登录认证、插件安装、邮箱配置、环境变量配置、一些公共资源的配置。然后将部署该jenkins的docker容器相关的dockerfile、docker-compose.yml、以及挂载出来的jenkins-home文件夹备份；然后利用该三份备份。就能在别的docker环境下，执行2个命令就能快速的部署jenkins，还能保持jenkins的通用配置。
  
  ---
  
### 2. Docker容器创建jenkins构建节点
　　完成docker中部署jenkins后，接下来就进行利用docker容器创建jenkins节点的操作，本次基于dockerhub官方镜像Jenkins JNLP Agent Docker image：jenkinsci/jnlp-slave的dockerfile文件就行修改，创建适合自己的客制化节点镜像，本次创建的镜像环境为编译android的环境。
#### 2.1 编写制作节点镜像的Dockerfile
　　如下是我的节点容器的镜像的dockerfile：
  需要注意一下几点：(1)用户uid/gid与宿主机一致；(2)挂载需要的环境解压包文件夹到容器；(3)将其导入到容器的环境变量。
  
  ```shell
FROM jenkins/slave:3.23-1
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
```
　　如上Dockerfile文件编写完成后，在其所在目录执行```docker build -t ${docker images name}:${version tag} .```;便能创建镜像，我执行的命令是：```docker build -t itel_docker_slave_android:v1.0 .```,然后执行docker images 命令，就能看到创建镜像信息。
  [![jenkins slave](http://pbdkyxc0r.bkt.clouddn.com/jenkins%20slave%20android.png "jenkins slave")](http://pbdkyxc0r.bkt.clouddn.com/jenkins%20slave%20android.png "jenkins slave")

#### 2.2 编写运行节点容器的编排YML文件
　　如下是我编写的jenkins节点容器的yaml文件：
  需要注意以下几点：
  (1)运行容器的镜像名称及版本、容器的名称；
  (2)JENKINS_URL:Jenkins服务器地址;
  (3)JENKINS_NAME:jenkins创建节点的名称；
  (4)JENKINS_SECRET：创建节点后产生的一串密码，由jenkins产生。
  (5)挂载环境包所在目录、工作空间目录、时区文件目录、docker相关目录
  [![slaveconfig](http://pbdkyxc0r.bkt.clouddn.com/jenkins%20slave%20config.png "slaveconfig")](http://pbdkyxc0r.bkt.clouddn.com/jenkins%20slave%20config.png "slaveconfig")
  [![slave config2](http://pbdkyxc0r.bkt.clouddn.com/jenkins%20slave%20config%202.png "slave config2")](http://pbdkyxc0r.bkt.clouddn.com/jenkins%20slave%20config%202.png "slave config2")
  
  ```yaml
slave3:
  image: itel_docker_slave_android:v1.1
  container_name: docker-agent-android
  restart: always
  environment:
    JAVA_OPTS: "-Djava.awt.headless=true"
    JENKINS_URL: "http://10.250.1.89:8082/"
    JENKINS_NAME: "docker-agent-android"
    JENKINS_SECRET: "6e57e274695ecb5aedbd6f9f743b6f70b0c8c79cb8245637420958d4b3f829ca "
  volumes:
    - /home/apkserver/jenkins_slave3_android:/var/jenkins_home
    - /usr/local/android-sdk-linux:/usr/local/android-sdk-linux
    - /usr/local/android-ndk-r13:/usr/local/android-ndk-r13
    - /usr/local/gradle-4.4:/usr/local/gradle-4.4
    - /usr/local/jdk1.8.0_161:/usr/local/jdk1.8.0_161
    - /etc/localtime:/etc/localtime
    - /etc/timezone:/etc/timezone
    - /var/run/docker.sock:/var/run/docker.sock
    - /usr/bin/docker:/bin/docker
    - /usr/lib/x86_64-linux-gnu/libltdl.so.7:/usr/lib/x86_64-linux-gnu/libltdl.so.7
    - /var/lib/docker:/var/lib/docker
```
　　完成如上编排YAML文件编写后执行```docker-compose up -d```,便能启动名为：docker-agent-android的容器，执行```docker ps```便能看到启动的容器信息。
  [![slave info](http://pbdkyxc0r.bkt.clouddn.com/slave%20info.png "slave info")](http://pbdkyxc0r.bkt.clouddn.com/slave%20info.png "slave info")
　　执行完如上操作后进入到jenkins节点界面刷新，便能看到运行的docker容器已经生效，绑定到了jenkins节点。
  [![slave list](http://pbdkyxc0r.bkt.clouddn.com/jenkins%20slave%20list.png "slave list")](http://pbdkyxc0r.bkt.clouddn.com/jenkins%20slave%20list.png "slave list")
　　至此，在docker容器中部署jenkins及绑定docker容器作为jenkins节点的部署操作完成；剩下的就是根据自己的需求去客制化不同的docker镜像(环境各不相同)，然后具有创建的镜像运行容器去作为jenkins的节点供构建应用使用。

> 文章中使用到的具体配置文件及附属的脚本文件可联系作者获取；作者微信：chb635252544。