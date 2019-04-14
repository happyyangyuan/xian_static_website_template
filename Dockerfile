FROM nginx:latest

# 你需要适当修改本行COPY命令，将你的静态资源构建输出物复制到NGINX镜像内默认的web资源路径内
COPY webroot /usr/share/nginx/html

# 将NGINX自定义的配置文件复制到NGINX配置文件路径内
COPY nginx /etc/nginx/conf.d
