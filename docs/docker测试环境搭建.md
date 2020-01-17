- [示意图](#自动化测试/部署示意图)
- [环境安装配置](#环境安装配置)
  - [安装docker](#安装docker)
  - [docker配置](#docker配置)
  - [docker配置swarm](#docker配置swarm)
	- [作为worker节点加入](#作为worker节点加入)
	- [作为manager节点加入](#作为manager节点加入)
	- [离开集群](#离开集群)
	- [连接私有仓库](#连接私有仓库)
- [节点管理相关命令](#节点管理相关命令)
- [gitlab-runner配置](#gitlab-runner配置)
	- [安装gitlab-runner](#安装gitlab-runner)
	- [注册gitlab-runner](#注册gitlab-runner)
	- [配置用户权限](#配置用户权限)
	- [runner脚本](#runner脚本)

## 自动化测试/部署示意图
![](src/ci&docker.jpg)
## 环境安装配置
### 安装docker
- windows安装
`windows`安装`docker`需要依赖`Hyper-V`技术, [windows安装参考](http://www.runoob.com/docker/windows-docker-install.html)

安装包下载, 官网地址: [https://store.docker.com/editions/community/docker-ce-desktop-windows](https://store.docker.com/editions/community/docker-ce-desktop-windows)

安装包下载, 局域网`ftp`: [ftp://192.168.1.107:21](ftp://192.168.1.107:21)
```
需要注意, 开启Hyper-V后, 虚拟机不能正常开启, 至于是使用宿主机还是虚拟机安装docker, 请酌情考虑.
```
- linux安装
```
// centos
sudo yum install docker

// ubuntu
sudo apt-get install docker.io
```

### docker配置
* `docker`运行
`service docker start`
* `docker`安装`swarm`
    ```
    docker search swarm
    docker pull swarm
    ```
### docker配置swarm
加入集群的节点有两种身份: `worker`和`manager`.
局域网主机`192.168.1.106`上已经部署了`docker`的私有仓库以及`swarm manager`, 我们只需要将本地的`docker`加入到`swarm`中就可以接受`manager`的管理。
##### 作为worker节点加入
运行:
```sh
docker swarm join --token SWMTKN-1-2bixohzvvs5z1ad2lyvtpmxnby2k7t91io62g5wb2uij83f135-1xv2cysol0omqkawxnlchldts 47.99.193.140:2377
```
若看到输出:
```
This node joined a swarm as a worker.
```
说明`worker`节点加入集群成功.

##### 作为manager节点加入
运行:
```sh
docker swarm join --token SWMTKN-1-2bixohzvvs5z1ad2lyvtpmxnby2k7t91io62g5wb2uij83f135-a97gfcsi6j1r4yf7jmvp8ps8r 47.99.193.140:2377
```

##### 离开集群
在加入新的集群或者重新加入集群需要先离开之前已经加入的集群.
```
docker swarm leave --force
```

##### 连接私有仓库
在需要与仓库通信的节点上, 将manager的`ip + port`加入`daemon.json`
```sh
touch /etc/docker/daemon.json
vi /etc/docker/daemon.json
// input ↓

{
"insecure-registries":["192.168.1.106:5000","47.99.193.140:7011"]
}
```
然后重启`docker`服务:
```sh
service docker restart
```

### 节点管理相关命令
* 私有仓库搭建
```sh
docker run -d -p 5000:5000 -v /home/dockerRegistry:/var/lib/registry registry
```
* 私有仓库查询所有镜像
```sh
curl -XGET http://192.168.1.106:5000/v2/_catalog
```
* 私有仓库查询镜像tags
```sh
curl -XGET http://192.168.1.106:5000/v2/ipfs/ipfsminer/tags/list
```
* 启动service
```sh
docker service create --replicas 20 --name ipfsminer 192.168.1.106:5000/ipfs/ipfsminer:v9 /bin/bash /home/install.sh
```
* 关闭service
```sh
docker service rm ipfsminer
```
* 查看当前所有任务
```sh
docker service ls
```
* 查看任务详细信息
```sh
docker service ps ipfsminer
```
* 查看当前集群节点情况
```sh
docker node ls
```
* 删除集群某个节点
```sh
docker node ls
docker node rm xxxxxxxxx
```
* 删除所有容器
```sh
docker rm $(docker ps -aq)
```
* 查看/删除镜像
```sh
// 查看所有镜像
docker image ls
// 删除所有镜像, 前提是删除所有容器
docker image rm $(docker image ls)
```
## docker swarm监控
1. cAdvisor + InfluxDB + Grarana

#### dashboard.json
[dashboard](https://github.com/botleg/swarm-monitoring/blob/master/dashboard.json), 需要将内容做出如下修改, 修改database名称
```
{
  "__inputs": [
    {
      "name": "DS_INFLUX",
      "label": "influx",
      "description": "",
      "type": "datasource",
      "pluginId": "influxdb",
      "pluginName": "InfluxDB"
    }
  ],
  "__requires": [
    {
      "type": "grafana",
      "id": "grafana",
      "name": "Grafana",
      "version": "4.2.0"
    },
    {
      "type": "panel",
      "id": "graph",
      "name": "Graph",
      "version": ""
    },
    {
      "type": "datasource",
      "id": "influxdb",
      "name": "InfluxDB",
      "version": "1.0.0"
    }
  ],
  "annotations": {
    "list": []
  },
  "editable": true,
  "gnetId": null,
  "graphTooltip": 0,
  "hideControls": false,
  "id": 2,
  "links": [],
  "refresh": "5s",
  "rows": [
    {
      "collapse": false,
      "height": 250,
      "panels": [
        {
          "aliasColors": {},
          "bars": false,
          "dashLength": 10,
          "dashes": false,
          "datasource": "InfluxDB",
          "fill": 1,
          "id": 1,
          "interval": "",
          "legend": {
            "alignAsTable": true,
            "avg": true,
            "current": true,
            "max": true,
            "min": true,
            "rightSide": false,
            "show": true,
            "total": true,
            "values": true
          },
          "lines": true,
          "linewidth": 1,
          "links": [],
          "nullPointMode": "connected",
          "percentage": false,
          "pointradius": 5,
          "points": false,
          "renderer": "flot",
          "seriesOverrides": [],
          "spaceLength": 10,
          "span": 6,
          "stack": false,
          "steppedLine": false,
          "targets": [
            {
              "alias": "Memory {host: $tag_machine, container: $tag_container_name}",
              "dsType": "influxdb",
              "groupBy": [
                {
                  "params": [
                    "$__interval"
                  ],
                  "type": "time"
                },
                {
                  "params": [
                    "machine"
                  ],
                  "type": "tag"
                },
                {
                  "params": [
                    "container_name"
                  ],
                  "type": "tag"
                }
              ],
              "measurement": "memory_usage",
              "orderByTime": "ASC",
              "policy": "default",
              "query": "SELECT \"value\" FROM \"memory_usage\" WHERE \"container_name\" =~ /^$container$/ AND \"machine\" =~ /^$host$/ AND $timeFilter",
              "rawQuery": false,
              "refId": "A",
              "resultFormat": "time_series",
              "select": [
                [
                  {
                    "params": [
                      "value"
                    ],
                    "type": "field"
                  },
                  {
                    "params": [],
                    "type": "mean"
                  }
                ]
              ],
              "tags": [
                {
                  "key": "container_name",
                  "operator": "=~",
                  "value": "/^$container$*/"
                },
                {
                  "condition": "AND",
                  "key": "machine",
                  "operator": "=~",
                  "value": "/^$host$/"
                }
              ]
            }
          ],
          "thresholds": [],
          "timeFrom": null,
          "timeShift": null,
          "title": "Memory",
          "tooltip": {
            "shared": true,
            "sort": 0,
            "value_type": "individual"
          },
          "type": "graph",
          "xaxis": {
            "buckets": null,
            "mode": "time",
            "name": null,
            "show": true,
            "values": []
          },
          "yaxes": [
            {
              "format": "decbytes",
              "label": null,
              "logBase": 1,
              "max": null,
              "min": null,
              "show": true
            },
            {
              "format": "short",
              "label": null,
              "logBase": 1,
              "max": null,
              "min": null,
              "show": true
            }
          ]
        },
        {
          "aliasColors": {},
          "bars": false,
          "dashLength": 10,
          "dashes": false,
          "datasource": "InfluxDB",
          "fill": 1,
          "id": 2,
          "legend": {
            "alignAsTable": true,
            "avg": true,
            "current": true,
            "max": true,
            "min": true,
            "show": true,
            "total": true,
            "values": true
          },
          "lines": true,
          "linewidth": 1,
          "links": [],
          "nullPointMode": "connected",
          "percentage": false,
          "pointradius": 5,
          "points": false,
          "renderer": "flot",
          "seriesOverrides": [],
          "spaceLength": 10,
          "span": 6,
          "stack": false,
          "steppedLine": false,
          "targets": [
            {
              "alias": "CPU {host: $tag_machine, container: $tag_container_name}",
              "dsType": "influxdb",
              "groupBy": [
                {
                  "params": [
                    "$interval"
                  ],
                  "type": "time"
                },
                {
                  "params": [
                    "machine"
                  ],
                  "type": "tag"
                },
                {
                  "params": [
                    "container_name"
                  ],
                  "type": "tag"
                }
              ],
              "measurement": "cpu_usage_total",
              "orderByTime": "ASC",
              "policy": "default",
              "refId": "A",
              "resultFormat": "time_series",
              "select": [
                [
                  {
                    "params": [
                      "value"
                    ],
                    "type": "field"
                  },
                  {
                    "params": [],
                    "type": "mean"
                  },
                  {
                    "params": [
                      "10s"
                    ],
                    "type": "derivative"
                  }
                ]
              ],
              "tags": [
                {
                  "key": "container_name",
                  "operator": "=~",
                  "value": "/^$container$*/"
                },
                {
                  "condition": "AND",
                  "key": "machine",
                  "operator": "=~",
                  "value": "/^$host$/"
                }
              ]
            }
          ],
          "thresholds": [],
          "timeFrom": null,
          "timeShift": null,
          "title": "CPU",
          "tooltip": {
            "shared": true,
            "sort": 0,
            "value_type": "individual"
          },
          "type": "graph",
          "xaxis": {
            "buckets": null,
            "mode": "time",
            "name": null,
            "show": true,
            "values": []
          },
          "yaxes": [
            {
              "format": "hertz",
              "label": null,
              "logBase": 1,
              "max": null,
              "min": null,
              "show": true
            },
            {
              "format": "short",
              "label": null,
              "logBase": 1,
              "max": null,
              "min": null,
              "show": true
            }
          ]
        }
      ],
      "repeat": null,
      "repeatIteration": null,
      "repeatRowId": null,
      "showTitle": false,
      "title": "Dashboard Row",
      "titleSize": "h6"
    },
    {
      "collapse": false,
      "height": 250,
      "panels": [
        {
          "aliasColors": {},
          "bars": false,
          "dashLength": 10,
          "dashes": false,
          "datasource": "InfluxDB",
          "fill": 1,
          "id": 3,
          "legend": {
            "alignAsTable": true,
            "avg": true,
            "current": true,
            "max": true,
            "min": true,
            "show": true,
            "total": true,
            "values": true
          },
          "lines": true,
          "linewidth": 1,
          "links": [],
          "nullPointMode": "connected",
          "percentage": false,
          "pointradius": 5,
          "points": false,
          "renderer": "flot",
          "seriesOverrides": [],
          "spaceLength": 10,
          "span": 6,
          "stack": false,
          "steppedLine": false,
          "targets": [
            {
              "alias": "Usage {host: $tag_machine, container: $tag_container_name}",
              "dsType": "influxdb",
              "groupBy": [
                {
                  "params": [
                    "$interval"
                  ],
                  "type": "time"
                },
                {
                  "params": [
                    "container_name"
                  ],
                  "type": "tag"
                },
                {
                  "params": [
                    "machine"
                  ],
                  "type": "tag"
                }
              ],
              "measurement": "fs_usage",
              "orderByTime": "ASC",
              "policy": "default",
              "refId": "A",
              "resultFormat": "time_series",
              "select": [
                [
                  {
                    "params": [
                      "value"
                    ],
                    "type": "field"
                  },
                  {
                    "params": [],
                    "type": "mean"
                  }
                ]
              ],
              "tags": [
                {
                  "key": "machine",
                  "operator": "=~",
                  "value": "/^$host$/"
                },
                {
                  "condition": "AND",
                  "key": "container_name",
                  "operator": "=~",
                  "value": "/^$container$*/"
                }
              ]
            },
            {
              "alias": "Limit {host: $tag_machine, container: $tag_container_name}",
              "dsType": "influxdb",
              "groupBy": [
                {
                  "params": [
                    "$interval"
                  ],
                  "type": "time"
                },
                {
                  "params": [
                    "container_name"
                  ],
                  "type": "tag"
                },
                {
                  "params": [
                    "machine"
                  ],
                  "type": "tag"
                }
              ],
              "measurement": "fs_limit",
              "orderByTime": "ASC",
              "policy": "default",
              "refId": "B",
              "resultFormat": "time_series",
              "select": [
                [
                  {
                    "params": [
                      "value"
                    ],
                    "type": "field"
                  },
                  {
                    "params": [],
                    "type": "mean"
                  }
                ]
              ],
              "tags": [
                {
                  "key": "machine",
                  "operator": "=~",
                  "value": "/^$host$/"
                },
                {
                  "condition": "AND",
                  "key": "container_name",
                  "operator": "=~",
                  "value": "/^$container$*/"
                }
              ]
            }
          ],
          "thresholds": [],
          "timeFrom": null,
          "timeShift": null,
          "title": "File System",
          "tooltip": {
            "shared": true,
            "sort": 0,
            "value_type": "individual"
          },
          "type": "graph",
          "xaxis": {
            "buckets": null,
            "mode": "time",
            "name": null,
            "show": true,
            "values": []
          },
          "yaxes": [
            {
              "format": "decbytes",
              "label": null,
              "logBase": 1,
              "max": null,
              "min": null,
              "show": true
            },
            {
              "format": "short",
              "label": null,
              "logBase": 1,
              "max": null,
              "min": null,
              "show": true
            }
          ]
        },
        {
          "aliasColors": {},
          "bars": false,
          "dashLength": 10,
          "dashes": false,
          "datasource": "InfluxDB",
          "fill": 1,
          "id": 4,
          "legend": {
            "alignAsTable": true,
            "avg": true,
            "current": true,
            "max": true,
            "min": true,
            "show": true,
            "total": true,
            "values": true
          },
          "lines": true,
          "linewidth": 1,
          "links": [],
          "nullPointMode": "connected",
          "percentage": false,
          "pointradius": 5,
          "points": false,
          "renderer": "flot",
          "seriesOverrides": [],
          "spaceLength": 10,
          "span": 6,
          "stack": false,
          "steppedLine": false,
          "targets": [
            {
              "alias": "RX {host: $tag_machine, container: $tag_container_name}",
              "dsType": "influxdb",
              "groupBy": [
                {
                  "params": [
                    "$interval"
                  ],
                  "type": "time"
                },
                {
                  "params": [
                    "container_name"
                  ],
                  "type": "tag"
                },
                {
                  "params": [
                    "machine"
                  ],
                  "type": "tag"
                }
              ],
              "measurement": "rx_bytes",
              "orderByTime": "ASC",
              "policy": "default",
              "refId": "A",
              "resultFormat": "time_series",
              "select": [
                [
                  {
                    "params": [
                      "value"
                    ],
                    "type": "field"
                  },
                  {
                    "params": [],
                    "type": "mean"
                  },
                  {
                    "params": [
                      "10s"
                    ],
                    "type": "derivative"
                  }
                ]
              ],
              "tags": [
                {
                  "key": "machine",
                  "operator": "=~",
                  "value": "/^$host$/"
                },
                {
                  "condition": "AND",
                  "key": "container_name",
                  "operator": "=~",
                  "value": "/^$container$*/"
                }
              ]
            },
            {
              "alias": "TX {host: $tag_machine, container: $tag_container_name}",
              "dsType": "influxdb",
              "groupBy": [
                {
                  "params": [
                    "$interval"
                  ],
                  "type": "time"
                },
                {
                  "params": [
                    "container_name"
                  ],
                  "type": "tag"
                },
                {
                  "params": [
                    "machine"
                  ],
                  "type": "tag"
                }
              ],
              "measurement": "tx_bytes",
              "orderByTime": "ASC",
              "policy": "default",
              "refId": "B",
              "resultFormat": "time_series",
              "select": [
                [
                  {
                    "params": [
                      "value"
                    ],
                    "type": "field"
                  },
                  {
                    "params": [],
                    "type": "mean"
                  },
                  {
                    "params": [
                      "10s"
                    ],
                    "type": "derivative"
                  }
                ]
              ],
              "tags": [
                {
                  "key": "machine",
                  "operator": "=~",
                  "value": "/^$host$/"
                },
                {
                  "condition": "AND",
                  "key": "container_name",
                  "operator": "=~",
                  "value": "/^$container$*/"
                }
              ]
            }
          ],
          "thresholds": [],
          "timeFrom": null,
          "timeShift": null,
          "title": "Network",
          "tooltip": {
            "shared": true,
            "sort": 0,
            "value_type": "individual"
          },
          "type": "graph",
          "xaxis": {
            "buckets": null,
            "mode": "time",
            "name": null,
            "show": true,
            "values": []
          },
          "yaxes": [
            {
              "format": "Bps",
              "label": null,
              "logBase": 1,
              "max": null,
              "min": null,
              "show": true
            },
            {
              "format": "short",
              "label": null,
              "logBase": 1,
              "max": null,
              "min": null,
              "show": true
            }
          ]
        }
      ],
      "repeat": null,
      "repeatIteration": null,
      "repeatRowId": null,
      "showTitle": false,
      "title": "Dashboard Row",
      "titleSize": "h6"
    }
  ],
  "schemaVersion": 14,
  "style": "dark",
  "tags": [],
  "templating": {
    "list": [
      {
        "allValue": "",
        "current": {
          "text": "backbox.corde.org",
          "value": "backbox.corde.org"
        },
        "datasource": "InfluxDB",
        "hide": 0,
        "includeAll": true,
        "label": "Host",
        "multi": false,
        "name": "host",
        "options": [],
        "query": "show tag values with key = \"machine\"",
        "refresh": 1,
        "regex": "",
        "sort": 0,
        "tagValuesQuery": "",
        "tags": [],
        "tagsQuery": "",
        "type": "query",
        "useTags": false
      },
      {
        "allValue": null,
        "current": {
          "text": "/",
          "value": "/"
        },
        "datasource": "InfluxDB",
        "hide": 0,
        "includeAll": false,
        "label": "Container",
        "multi": false,
        "name": "container",
        "options": [],
        "query": "show tag values with key = \"container_name\" WHERE machine =~ /^$host$/",
        "refresh": 1,
        "regex": "/([^.]+)/",
        "sort": 0,
        "tagValuesQuery": "",
        "tags": [],
        "tagsQuery": "",
        "type": "query",
        "useTags": false
      }
    ]
  },
  "time": {
    "from": "now-6h",
    "to": "now"
  },
  "timepicker": {
    "refresh_intervals": [
      "5s",
      "10s",
      "30s",
      "1m",
      "5m",
      "15m",
      "30m",
      "1h",
      "2h",
      "1d"
    ],
    "time_options": [
      "5m",
      "15m",
      "1h",
      "6h",
      "12h",
      "24h",
      "2d",
      "7d",
      "30d"
    ]
  },
  "timezone": "browser",
  "title": "cAdvisor",
  "version": 2
}
```

## gitlab-runner配置
### 安装gitlab-runner
[参考文档](https://docs.gitlab.com/runner/install/linux-manually.html)

### 注册gitlab-runner
从gitlab服务器的项目设置中获取`url`, `token`:
![](./src/gitlab-register.jpg)
```bash
gitlab-runner register
// input args if need
```

### 配置用户权限
因为要使用脚本操作到`GOPATH`目录, 需要取得管理员权限
```sh
su root
chmod u+w /etc/sudoers
// 在 root ALL=(ALL) ALL 这一行下面, 再加入一行：gitlab-runner ALL=(ALL) ALL
// 添加 gitlab-runner ALL=(ALL) NOPASSWD: ALL 到末尾
chmod u-w /etc/sudoers
```
### runner脚本
#### deployCommon
```sh
#!/bin/bash
echo "ptfsCommon deploying..."
common_path="/home/GoWork/src/github.com/PTFS/node_common"
if [ ! -d "$common_path" ];
then
	echo "node_common not found"
	sudo git clone http://username:password@192.168.1.2:8090/PTFS/node_common.git $GOPATH/src/github.com/PTFS/node_common
	cd $GOPATH/src/github.com/PTFS/node_common/
else
	echo "node_common found"
	cd $common_path
	sudo git pull
fi
cd $GOPATH/src/github.com/PTFS/node_common/
sudo cp -rf ./github.com/. $GOPATH/src/github.com/
sudo cp -rf ./golang.org/. $GOPATH/src/golang.org/

```

#### deployProto
```sh
#!/bin/bash
echo "ptfsProto deploying..."
proto_path="/home/GoWork/src/github.com/PTFS/node_proto"
if [ ! -d "$proto_path" ];
then
	echo "node_proto not found, start clone..."
	sudo git clone http://limo:limo12345678@192.168.1.2:8090/PTFS/node_proto.git $GOPATH/src/github.com/PTFS/node_proto
	cd $GOPATH/src/github.com/PTFS/node_proto/
else
	echo "node_proto found, start fetch..."
	cd $proto_path
	sudo git pull
fi
cd $GOPATH/src/github.com/PTFS/node_proto/
echo "ptfsProto deploy finished."

```

#### deployMiner
```sh
#!/bin/bash
echo "ptfsMiner deploying..."
miner_path="/home/GoWork/src/github.com/PTFS/node_miner"
if [ ! -d "$miner_path" ];
then
	echo "node_miner not found, start clone..."
	sudo git clone http://limo:limo12345678@192.168.1.2:8090/PTFS/node_miner.git $GOPATH/src/github.com/PTFS/node_miner
	cd $GOPATH/src/github.com/PTFS/node_miner/
	sudo chmod 777 $GOPATH/src/github.com/PTFS/node_miner/cmd/ipfs/
else
	echo "node_miner found, start fetch..."
	cd $miner_path
	sudo git pull
fi
cd $GOPATH/src/github.com/PTFS/node_miner/cmd/ipfs/
source /etc/profile
go build
echo "build successed. Coping to the docker folder, update ipfsMiner image..."
echo "Wait a moment......"
sudo cp $GOPATH/src/github.com/PTFS/node_miner/cmd/ipfs/ipfs /home/dockerImgMaker/ipfs
cd /home/dockerImgMaker/

if sudo /home/dockerImgMaker/install.sh ;
then 
	echo "update image successed."
else
	1>&2 exit 1
fi

echo "ptfsMiner deploy finished."

```