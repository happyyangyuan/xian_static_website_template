# xian_static_website_template
本代码库提供前端站点模板代码，与[后端模板代码](https://github.com/happyyangyuan/xian_apiserver_allinone_template)配合使用可以实现前端分离的快速开发框架效能。

## 前后端分离的支持
本代码模板提供的前端独立部署方案是基于
- NGINX反向代理到后端服务
- NGINX官方提供的docker镜像
- rancher-pipeline CI/CD
- k8s容器编排

### NGINX代理到后端服务
1. 通过Dockerfile构建NGINX镜像，将前端代码打包到NGINX镜像内
#### NGINX镜像Dockerfile示例
```Dockerfile
FROM nginx:latest

# 你需要适当修改本行COPY命令，将你的静态资源构建输出物复制到NGINX镜像内默认的web资源路径内
COPY webroot /usr/share/nginx/html

# 将NGINX自定义的配置文件复制到NGINX配置文件路径内
COPY nginx /etc/nginx/conf.d
```
#### NGINX配置文件
[nginx默认配置文件](nginx/default.conf)，文件内容请点连接跳转到代码查看。  
[nginx自定义反向代理配置](nginx/custom.conf)如下
```nginx.conf
# 我们自定义的配置文件
server {
    listen       80;
    server_name  your.hostname.com;

    location /backend {
        proxy_pass http://ip:port/backend
    }
}
```

### k8s 前端deployment编排
我们使用k8s的deployment来调度前端程序容器镜像的[deployment.yaml文件](deployment.yaml)如下，需要结合[rancher-pipeline的环境变量](https://rancher.com/docs/rancher/v2.x/en/k8s-in-rancher/pipelines/#pipeline-variable-substitution-reference)来阅读
```yaml
apiVersion: apps/v1beta2
kind: Deployment
metadata:
  labels:
    workload.user.cattle.io/workloadselector: deployment-${CICD_GIT_BRANCH}-${CICD_GIT_REPO_NAME}
  name: ${CICD_GIT_REPO_NAME}
  namespace: ${CICD_GIT_REPO_NAME}-${CICD_GIT_BRANCH}
spec:
  selector:
    matchLabels:
      workload.user.cattle.io/workloadselector: deployment-${CICD_GIT_BRANCH}-${CICD_GIT_REPO_NAME}
  template:
    metadata:
      labels:
        workload.user.cattle.io/workloadselector: deployment-${CICD_GIT_BRANCH}-${CICD_GIT_REPO_NAME}
    spec:
      containers:
      - image: ${CICD_REGISTRY}/${CICD_IMAGE}:${CICD_GIT_BRANCH}-${CICD_EXECUTION_SEQUENCE}
        name: ${CICD_GIT_REPO_NAME}
        ports:
        - containerPort: 80
          name: 80tcp01
          protocol: TCP
        resources:
          limits:
            cpu: "1"
            memory: 512Mi
          requests:
            cpu: 100m
      imagePullSecrets:
      - name: harbor

---
apiVersion: v1
kind: Service
metadata:
  name: ${CICD_GIT_REPO_NAME}-nodeport
  namespace: ${CICD_GIT_REPO_NAME}-${CICD_GIT_BRANCH}
spec:
  ports:
  - name: 80tcp01
    port: 80
    protocol: TCP
    targetPort: 80
  selector:
    workload.user.cattle.io/workloadselector: deployment-${CICD_GIT_BRANCH}-${CICD_GIT_REPO_NAME}
  type: NodePort
```

### rancher-pipeline CI/CD
关于rancher-pipeline，见[官方文档rancher-pipeline说明](https://rancher.com/docs/rancher/v2.x/en/k8s-in-rancher/pipelines/)
本代码提供了一个模板配置，如下
```yaml
stages:
- name: compile
  steps:
  - runScriptConfig:
      image: node
      shellScript: |-
        # 修改一下你的路径
        cd xxx/xxx
        npm i
        npm run build/dev
- name: frontend image
  steps:
  - publishImageConfig:
      dockerfilePath: ./Dockerfile
      buildContext: .
      tag: ${CICD_IMAGE}:${CICD_GIT_BRANCH}-${CICD_EXECUTION_SEQUENCE}
      pushRemote: true
      # 修改一下你的镜像私服地址
      registry: harbor.cedarhd.com
- name: deploy
  steps:
  - applyYamlConfig:
      path: ./deployment.yaml
timeout: 60
```

