# 构建阶段
FROM --platform=linux/amd64 node:18-alpine as build-stage
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

# 生产阶段
FROM --platform=linux/amd64 nginx:stable-alpine as production-stage
# 添加默认音乐目录
RUN mkdir -p /usr/share/nginx/html/music
COPY --from=build-stage /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
