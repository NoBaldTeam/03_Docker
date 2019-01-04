基于ELK的实时日志分析平台搭建
====



# 1. ELK介绍
　　ELK 是elastic公司提供的一套完整的日志收集、展示解决方案，是三个产品的首字母缩写，分别是ElasticSearch、Logstash 和 Kibana。
[![elk](https://itel-oss.oss-cn-beijing.aliyuncs.com/devops/elk/elk.webp "elk")](https://itel-oss.oss-cn-beijing.aliyuncs.com/devops/elk/elk.webp "elk")
　　ElasticSearch简称ES，它是一个实时的分布式搜索和分析引擎，它可以用于全文搜索，结构化搜索以及分析。它是一个建立在全文搜索引擎 Apache Lucene 基础上的搜索引擎，使用 Java 语言编写。
　　Logstash是一个具有实时传输能力的数据收集引擎，用来进行数据收集（如：读取文本文件）、解析，并将数据发送给ES。
　　Kibana为 Elasticsearch 提供了分析和可视化的 Web 平台。它可以在 Elasticsearch 的索引中查找，交互数据，并生成各种维度表格、图形。
  

# 2. 基于docker-compose搭建ELK
服务器规划：

|服务器IP| 用途 |收集日志类型 | |
|:-----:|-----|-----|-----|
|10.250.115.164|部署ELK主机|||
|10.250.115.232|应用服务器|tomcat、nginx||
|10.250.115.231|应用服务器|tomcat、nginx||

# 3. 搭建ELK服务
使用Docker快速的部署ELK，编写对应docker-compose.yml文件；
具体内容如下：
```
version: '2'
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch-oss:6.5.4
    container_name: elasticsearch
    volumes:
      - ./elasticsearch/config/elasticsearch.yml:/usr/share/elasticsearch/config/elasticsearch.yml:ro
      - ./elasticsearch/data:/usr/share/elasticsearch/data
    ports:
      - "9200:9200"
      - "9300:9300"
    environment:
      ES_JAVA_OPTS: "-Xmx256m -Xms256m"
    networks:
      - elk

  logstash:
    image: docker.elastic.co/logstash/logstash-oss:6.5.4 
    container_name: logstash
    volumes:
      - ./logstash/config/logstash.yml:/usr/share/logstash/config/logstash.yml:ro
      - ./logstash/pipeline:/usr/share/logstash/pipeline:ro
      - ./logstash/patterns:/usr/share/logstash/patterns:ro
    ports:
      - "5000:5000"
      - "9600:9600"
    environment:
      LS_JAVA_OPTS: "-Xmx256m -Xms256m"
    networks:
      - elk
    depends_on:
      - elasticsearch

  kibana:
    image: docker.elastic.co/kibana/kibana-oss:6.5.4
    container_name: kibana
    volumes:
      - ./kibana/config/:/usr/share/kibana/config:ro
    ports:
      - "5601:5601"
    networks:
      - elk
    depends_on:
      - elasticsearch

networks:
  elk:
    driver: bridge
```
#### elasticsearch部分：
需要在docker-compose.yml同级目录下创建文件夹：
```
mkdir -p  ./elasticsearch/config/
mkdir -p  ./elasticsearch/data
```
在 ./elasticsearch/config/ 下创建文件elasticsearch.yml，内容为：
```
---
cluster.name: "docker-cluster"
network.host: 0.0.0.0

# Details: https://github.com/elastic/elasticsearch/pull/17288
discovery.zen.minimum_master_nodes: 1

discovery.type: single-node
```
因为elasticsearch容器内data文件夹用户组为: 1000:10,修改data文件夹权限，不然创建容器时会报权限错误。
```
sudo chown 1000:10 -R ./elasticsearch/data
```
#### kibana部分：
需要在docker-compose.yml同级目录下创建文件夹：
```
mkdir -p ./kibana/config/
```
在 ./kibana/config/下创建文件kibana.yml，内容为：
```
---
server.name: kibana
server.host: "0"
elasticsearch.url: http://elasticsearch:9200
```
#### logstash部分：
需要在docker-compose.yml同级目录下创建文件夹：
```
mkdir -p ./logstash/pipeline
mkdir -p  ./logstash/config/
mkdir -p  ./logstash/patterns/
```
在 ./logstash/config/下创建文件logstash.yml，内容为：
```
http.host: "0.0.0.0"
path.config: /usr/share/logstash/pipeline
```
在 ./logstash/pipeline下创建文件logstash.conf，内容为：
```
input {
  beats {
    port => "5000"
  }
}
filter{

}

output {
  stdout { codec => rubydebug }
  elasticsearch {
        hosts => [ "10.250.115.164:9200" ]
        index => "logstash-%{[fields][document_type]}-%{+YYYY.MM.dd}"
    }
}
```
其中5000为logstash接收filebeat的入口，10.250.115.164:9200为elasticsearch服务入口。

这样按照如上完成配置后，在docker-compose.yml同级目录下执行如下命令即可启动容器，创建服务；
```
docker-compose up -d
```
如上部署具体文件存放在：当前git库


# 4. 搭建filebeat节点收集日志
filebeat节点采用直接运行可执行文件的方式去执行程序，检测日志文件的变化，然后上传变化到logstash。
具体部署软件包存放在：当前git库

将软件包存放到服务器/workspace/app/目录下。
主要修改下yaml文件夹下的filebeat.yml文件：
```
#=========================== Filebeat prospectors =============================
# List of prospectors to fetch data.
filebeat.prospectors:
#------------------------------ Log prospector --------------------------------
#################tomcat 8080#################
- input_type: log
  paths:
    - /workspace/app/tomcat/logs/*.txt
    - /workspace/app/tomcat/logs/*.log
  tail_files: true #文件末尾开始读取
  fields:
      document_type: tomcat231-8080
#################tomcat 8081#################
- input_type: log
  paths:
    - /workspace/app/tomcat-stat-8081/logs/*.txt
    - /workspace/app/tomcat-stat-8081/logs/*.log
  tail_files: true #文件末尾开始读取
  fields:
      document_type: tomcat231-stat-8081
#----------------------------- Logstash output ---------------------------------
output.logstash:
  # Boolean flag to enable or disable the output module.
  #enabled: true

  # The Logstash hosts
  hosts: ["10.250.115.164:5000"]
```
　　如果该filebeat节点有多个不同类型的日志文件需要监控，则配置多个input_type即可； fields: document_type对应logstash中配置的index，用于在kibana中创建index。
　　path改为需要监控的日路径即可，fields: document_type为该日志标签，用于区分。
　　按照如上配置完执行 ```sudo ./filebeat -e -c /workspace/app/filebeat/yaml/filebeat.yml &```即可启动服务。
  
# 5.Kibana创建过滤器监控日志更新
浏览器打开连接：[http://10.250.115.164:5601/app/kibana](http://10.250.115.164:5601/app/kibana "http://10.250.115.164:5601/app/kibana")
**创建index**
[![](https://itel-oss.oss-cn-beijing.aliyuncs.com/devops/elk/index-patterns.png)](https://itel-oss.oss-cn-beijing.aliyuncs.com/devops/elk/index-patterns.png)
[![](https://itel-oss.oss-cn-beijing.aliyuncs.com/devops/elk/create%20index%20pattern.png)](https://itel-oss.oss-cn-beijing.aliyuncs.com/devops/elk/create%20index%20pattern.png)
[![](https://itel-oss.oss-cn-beijing.aliyuncs.com/devops/elk/create%20index%20pattern%201.png)](https://itel-oss.oss-cn-beijing.aliyuncs.com/devops/elk/create%20index%20pattern%201.png)


**Discover查看：**
[![](https://itel-oss.oss-cn-beijing.aliyuncs.com/devops/elk/Discover.png)](https://itel-oss.oss-cn-beijing.aliyuncs.com/devops/elk/Discover.png)


