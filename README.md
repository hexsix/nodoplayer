# 诺多音乐播放器 (Nodo Player)

一个简单的单页面静态本地音乐播放器，使用 Vue.js 开发。

## 功能特点

- 从指定目录加载和播放音频文件
- 显示歌曲信息和专辑封面
- 播放控制：播放/暂停、上一曲/下一曲
- 音量控制
- 进度条显示和拖动定位
- 播放列表管理

## 开发环境设置

### 推荐的 IDE

[VSCode](https://code.visualstudio.com/) + [Volar](https://marketplace.visualstudio.com/items?itemName=Vue.volar)

### 安装依赖

```sh
npm install
```

### 开发环境编译和热重载

```sh
npm run dev
```

### 生产环境编译和压缩

```sh
npm run build
```

## 音乐文件配置

播放器从 `/music` 目录读取音乐文件和元数据。需要在该目录中创建一个 `playlist.json` 文件，格式如下：

```json
[
  {
    "id": 1,
    "title": "歌曲标题",
    "artist": "艺术家",
    "album": "专辑名称",
    "cover": "covers/封面文件.jpg",
    "file": "音乐文件.mp3"
  }
]
```

音乐文件和封面图片应放在 `/music` 目录下（封面图片可以放在 `/music/covers` 子目录中）。

## 使用 Docker 构建和运行

### 使用 Docker Compose

1. 在项目根目录创建 `music` 文件夹
2. 在 `music` 文件夹中放入音乐文件和 `playlist.json` 文件
3. 运行以下命令：

```sh
# 构建并启动应用
docker-compose up -d

# 停止应用
docker-compose down
```

应用将在 http://localhost:8080 上运行，并自动挂载本地的 `music` 目录。

### 手动构建 Docker 镜像

```sh
# 构建镜像
docker build -t nodo-player .

# 运行容器，挂载音乐目录
docker run -d -p 8080:80 -v $(pwd)/music:/usr/share/nginx/html/music --name nodo-player nodo-player
```

## 使用方法

1. 将音乐文件和元数据放入音乐目录
2. 打开播放器网页
3. 从播放列表中选择歌曲播放
4. 使用播放器控制播放、暂停、切换歌曲
5. 通过点击进度条调整播放位置
6. 使用音量滑块调整音量

## 技术栈

- Vue.js 3
- Howler.js (音频处理)
- Docker (容器化)
- Nginx (生产环境服务)
