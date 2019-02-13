#!/bin/bash

#------------------------------------------------------------------------------#
# Android开发环境搭建脚本
# Gradle + Groovy + JAVA
# 目前只支持Ubuntu和CentOS系统
#------------------------------------------------------------------------------#

#解压后的文件存放目录，要修改的话，最好还是在~目录或者其子目录下，涉及到权限问题
WORK_DIR=/usr/local/Custom_Environment

# JDK下载链接
# 其他版本可以去http://ftp.osuosl.org/pub/funtoo/distfiles/oracle-java/ 查询
JDK8_TAR_URL=http://ftp.osuosl.org/pub/funtoo/distfiles/oracle-java/jdk-8u162-linux-x64.tar.gz
JDK7_TAR_URL=http://ftp.osuosl.org/pub/funtoo/distfiles/oracle-java/jdk-7u80-linux-x64.tar.gz

# Gradle 3.3下载链接 ，其他版本链接可以通过如下链接获取
# http://services.gradle.org/distributions/
Gradle_3_ZIP_URL=http://services.gradle.org/distributions/gradle-3.3-all.zip

#Groovy 下载链接
Groovy_ZIP_URL=http://dl.bintray.com/groovy/maven/apache-groovy-sdk-2.4.5.zip

# Google专门为中国的开发者提供了中国版本的服务，但是下载地址仍然是国外的
# https://developer.android.google.cn/studio/index.html
ANDROID_SDK_TGZ_URL=http://dl.google.com/android/android-sdk_r24.4.1-linux.tgz
# 填写需要下载的SDK版本
ANDROID_SDK_FRAMEWORK_VERSION=26
# 填写需要的Android build tools的版本
ANDROID_SDK_BUILD_TOOLS_VERSION=23.0.2

# 此开关控制是否要安装Android Studio
# 如果您用于桌面环境，通常是用于开发的，开启的可能行很大
# 如果您用于持续构建服务器，通常是不需要安装的，把此开发改为false即可
ANDROID_STUDIO_NEED=false

# 如下网站可以查看要安装的版本：
# http://tools.android.com/download/studio/canary
# https://developer.android.google.cn/studio/index.html
ANDROID_STUDIO_URL=https://dl.google.com/dl/android/studio/ide-zips/2.2.3.0/android-studio-ide-145.3537739-linux.zip

# 更新现有的以及下载最新的sdk
# 如果需要下载全部的，再加一个参数-a
#UPDATE_ANDROID_SDK=android update sdk --no-ui  
# 查看有哪些包可以更新 
#UODATE_ANDROID_LIST=android list sdk  

#------------------------------------------------------------------------------#

# 安装依赖库和工具
function installDependency() {
    # 如果是Ubuntu系统
    if [ -f "/etc/lsb-release" ] ; then
        echo  "========>System is：Ubuntu!!!"
        echo  "========>Update system......"
        sudo apt-get update -y >/dev/null 2>&1 
        echo  "========>Install Dependent package......"
        sudo apt-get install -y gcc-multilib lib32z1 lib32stdc++6  >/dev/null 2>&1 
        sudo apt-get install -y git subversion vim curl wget zip unzip >/dev/null 2>&1 
    # 如果是CentOS系统
    elif [ -f "/etc/redhat-release" ] ; then
        echo  "========>System is： Centos!!!"
        echo  "========>Update system......"
        sudo yum update -y >/dev/null 2>&1 
        echo  "========>Install Dependent package......"
        sudo yum install -y glibc.i686 zlib.i686 libstdc++.i686  >/dev/null 2>&1 
        sudo yum install -y git subversion vim curl wget  >/dev/null 2>&1 
    fi
}

# 下载并解压.tar.gz或者.tgz文件
# $1是要下载文件的URL
function downloadTGZFile() {
    fileName=`basename "$1"`
    if [ -f "$PWD/downloads/${fileName}" ] ; then #若文件存在
        sudo tar -tf $PWD/downloads/${fileName} > /dev/null # 列出.tar包中所有文件
        
        if [ $? -eq 0 ] ; then  #若列出OK
            echo "========>tar file exit ,enable,start tar zxf $fileName "
            sudo tar zxf $PWD/downloads/${fileName} -C ${WORK_DIR} > /dev/null #解压到指定目录
        else  
            echo "========>tar file exit ,but disable "
            sudo rm $PWD/downloads/${fileName}  # 否则删除文件 重新下载
            echo "========>Start down tar file :$fileName"
            wget -P $PWD/downloads --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" "$1" && \
            sudo tar zxf $PWD/downloads/${fileName} -C ${WORK_DIR}  > /dev/null
        fi
    else # 若文件不存在，下载解压
        echo "========>Tar file not exit ,start download $fileName "
        echo "========>Start down tar file :$fileName"
        wget -P $PWD/downloads/ --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" "$1" && \
        sudo tar -zvxf $PWD/downloads/${fileName} -C ${WORK_DIR}  > /dev/null
    fi
}

# 下载并解压.zip
# $1是要下载文件的URL
function downloadZipFile() {
    fileName=`basename "$1"`
    if [ -f "$PWD/downloads/${fileName}" ] ; then
        sudo unzip -t $PWD/downloads/${fileName} > /dev/null
        if [ $? -eq 0 ] ; then
            echo "========>Zip file exit ,enable,start unzip $fileName "
            sudo unzip -o  $PWD/downloads/${fileName} -d ${WORK_DIR} > /dev/null
        else
            echo "========>Zip file exit ,but disable ,start rm and redownload! $fileName"
            sudo rm $PWD/downloads/${fileName}
            echo "========>Start down tar file :$fileName"
            wget -P $PWD/downloads --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" "$1" && \
            sudo unzip  -o $PWD/downloads/${fileName} -d ${WORK_DIR} > /dev/null
        fi
    else
        echo "========>Zip file not exit ,start download $fileName "
        echo "========>Start down tar file :$fileName"
        wget -P $PWD/downloads --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" "$1" && \
        sudo unzip  -o $PWD/downloads/${fileName} -d ${WORK_DIR} > /dev/null
    fi
}

# 执行下载、解压文件
# $1是要下载文件的URL
function downloadFile() {
    fileName=`basename "$1"`
    extension=`echo "${fileName##*.}"` # 切割字符串，获取.最后一个字符
    echo "========>DownloadFile Url:$1 "
    echo "========>FileName: $fileName "
    echo "========>Extension: $extension"
    if [ "$extension" = "tgz" ] ; then
        downloadTGZFile $1
    elif [ "$extension" = "gz" ] ; then
        downloadTGZFile $1
    elif [ "$extension" = "zip" ] ; then
        downloadZipFile $1
    elif [ "$extension" = "war" ] ; then
        downloadZipFile $1
    elif [ "$extension" = "jar" ] ; then
        downloadZipFile $1
    fi
}

# 配置JDK环境变量
function configJDKEnv() {
    fileName=`basename "$JDK8_TAR_URL"`
    echo "========>JDKfileName: $fileName"
    dirName=`tar -tf $PWD/downloads/${fileName} | awk -F "/" '{print $1}' | sort | uniq`
    echo "========>JDKdirName: $dirName"
    javaHome=${WORK_DIR}/${dirName}
    echo "========>javaHome:$javaHome"
    
    sudo echo "export JAVA_HOME=${javaHome}" >> /etc/profile
    sudo echo "export PATH=\$JAVA_HOME/bin:\$PATH" >> /etc/profile
    sudo echo "export CLASSPATH=.:\$JAVA_HOME/lib/dt.jar:\$JAVA_HOME/lib/tools.jar" >> /etc/profile

    source /etc/profile
}

# 配置Android SDK的环境变量
function configAndroidSDKEnv() {
    fileName=`basename "$ANDROID_SDK_TGZ_URL"`
    echo "========>AndroidSDKfileName: $fileName"
    dirName=`tar -tf $PWD/downloads/${fileName} | awk -F "/" '{print $1}' | sort | uniq`
    echo "========>AndroidSDKdirName: $dirName"
    androidHome=${WORK_DIR}/${dirName}
    sudo chmod +x ${WORK_DIR}/${dirName}/tools/android
    sudo echo "========>androidHome: $androidHome"
    sudo echo "export ANDROID_HOME=${androidHome}" >> /etc/profile
    sudo echo "export PATH=\$ANDROID_HOME/tools:\$ANDROID_HOME/platform-tools:\$ANDROID_HOME/build-tools/${ANDROID_SDK_BUILD_TOOLS_VERSION}:\$PATH" >> /etc/profile
    source /etc/profile
}

# 更新Android SDK 可自行修改下载版本参数，也可后期手动更新
function updateAndroidSDK() {
	which sdkmanager 2> /dev/null # 是否存在sdkmanager 
	if [ $? -eq 0 ] ; then
		sdkmanager "platforms;android-${ANDROID_SDK_FRAMEWORK_VERSION}" "platform-tools" "build-tools;${ANDROID_SDK_BUILD_TOOLS_VERSION}" "extras;android;m2repository" "extras;google;m2repository" "cmake;3.6.3155560" "tools"
	else  # 直接使用android命令更新
        echo "========>Start Update Android SDK!"
		echo y | android update sdk --no-ui --all --filter android-${ANDROID_SDK_FRAMEWORK_VERSION},platform-tools,build-tools-${ANDROID_SDK_BUILD_TOOLS_VERSION},extra-android-m2repository  > /dev/null
	fi
}

function  configGradleEnv() {
    fileName=`basename "$Gradle_3_ZIP_URL"`
    echo "========>GradlefileName: $fileName"
    #dirName=`unzip -t $PWD/downloads/${fileName} | awk -F "/" '{print $1}' | sort | uniq`
    dirName=`unzip -v  $PWD/downloads/${fileName} |awk -F " " '{print $8}' | sort  | awk -F  "/" '{print $1}' |sed -n '6P;'`
    echo "========>GradledirName: $dirName"
    GradleHome=${WORK_DIR}/${dirName}
    echo "========>GradleHome: $GradleHome"
    sudo echo "export GRADLE_HOME=${GradleHome}" >> /etc/profile
    sudo echo "export PATH=\$GRADLE_HOME/bin:\$PATH" >> /etc/profile
    sudo echo "export CLASSPATH=.:\$GRADLE_HOME/lib/" >> /etc/profile
    source /etc/profile
}

function  configGroovyEnv() {
    fileName=`basename "$Groovy_ZIP_URL"`
    echo "========>GroovyfileName: $fileName"
    #dirName=`unzip -t $PWD/downloads/${fileName} | awk -F "/" '{print $1}' | sort | uniq`
    dirName=`unzip -v  $PWD/downloads/${fileName}   |awk -F " " '{print $8}' | sort  | awk -F  "/" '{print $1}' |sed -n '6P;'`
    echo "========>GroovydirName: $dirName"
    GroovyHome=${WORK_DIR}/${dirName}
    echo "========>GroovyHome: $GroovyHome"
    sudo echo "export GROOVY_HOME=${GroovyHome}" >> /etc/profile
    sudo echo "export PATH=\$GROOVY_HOME/bin:\$PATH" >> /etc/profile
    sudo echo "export CLASSPATH=.:\$GROOVY_HOME/lib/" >> /etc/profile
    source /etc/profile

}



function main() {
    # 如果不存在此文件夹，就创建
    if [ ! -d "${WORK_DIR}" ]; then
        mkdir -p ${WORK_DIR}
    fi
    if [ ! -d "$PWD/downloads" ]; then
        mkdir -p $PWD/downloads
    fi

    cd ~
    
    #系统判断,安装依赖包
    installDependency
    echo "######################################################################"
    downloadFile $JDK8_TAR_URL
    configJDKEnv
    echo "######################################################################"
    downloadFile $Gradle_3_ZIP_URL
    configGradleEnv
    echo "######################################################################"
    downloadFile $ANDROID_SDK_TGZ_URL
    configAndroidSDKEnv
    updateAndroidSDK
   
    echo "######################################################################"
    if  [ "$ANDROID_STUDIO_NEED" = "false" ];then 
        echo "========> No Need install Android Studio!!!"
    else
        downloadFile $ANDROID_STUDIO_URL
    fi
    echo "######################################################################"
    downloadFile $Groovy_ZIP_URL
    configGroovyEnv
    
    echo "######################################################################"
    
    cd - > /dev/null
}

main
