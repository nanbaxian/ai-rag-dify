# 本地运行、宝塔部署与 API 文档说明

## 1. 项目结构

这个仓库是前后端分离的代码结构：

- `api/`：Python Flask 后端，负责业务 API、任务队列、权限、存储、模型等
- `web/`：Next.js 前端，负责控制台和 Web 界面
- `docker/`：Docker Compose 部署目录，包含数据库、Redis、Weaviate、Nginx 等中间件和运行服务

## 2. 本地运行

### 2.1 推荐方式

仓库已经提供了现成脚本，优先使用它们：

```bash
./dev/setup
./dev/start-docker-compose
./dev/start-api
./dev/start-web
./dev/start-worker
```

可选：

```bash
./dev/start-beat
```

### 2.2 启动顺序

1. `./dev/setup`
   - 复制 `api/.env.example` -> `api/.env`
   - 复制 `web/.env.example` -> `web/.env.local`
   - 复制 `docker/envs/middleware.env.example` -> `docker/middleware.env`
   - 安装后端和前端依赖

2. `./dev/start-docker-compose`
   - 启动 PostgreSQL / Redis / Weaviate 等基础服务

3. `./dev/start-api`
   - 运行后端
   - 会先执行数据库迁移
   - 默认端口是 `5001`

4. `./dev/start-web`
   - 运行前端
   - 默认访问 `http://localhost:3000`

5. `./dev/start-worker`
   - 启动 Celery worker
   - 负责异步任务、索引、调度、队列任务

### 2.3 本地运行前要改的关键变量

后端：

- `api/.env`
- 重点检查：
  - `CONSOLE_API_URL`
  - `SERVICE_API_URL`
  - `APP_WEB_URL`
  - `FILES_URL`
  - `INTERNAL_FILES_URL`
  - `COOKIE_DOMAIN`
  - `SECRET_KEY`

前端：

- `web/.env.local`
- 重点检查：
  - `NEXT_PUBLIC_API_PREFIX`
  - `NEXT_PUBLIC_PUBLIC_API_PREFIX`
  - `NEXT_PUBLIC_SOCKET_URL`
  - `NEXT_PUBLIC_COOKIE_DOMAIN`

## 3. 宝塔部署建议

### 3.1 推荐方案：Docker Compose 部署

这是最稳妥的方式，适合宝塔服务器：

1. 服务器安装 Docker 和 Docker Compose
2. 把仓库代码上传或拉到服务器
3. 进入 `docker/`
4. 复制环境文件：

```bash
cp .env.example .env
cp envs/middleware.env.example middleware.env
```

5. 修改 `docker/.env` 和 `docker/middleware.env`
6. 启动：

```bash
docker compose up -d
```

### 3.2 宝塔上如何接入

宝塔一般有两种接法：

#### 方案 A：Docker 自己占用 80 / 443

适合你希望尽量少改架构的情况。

- 让 `docker-compose.yaml` 里的 Nginx 容器直接监听 80 / 443
- 宝塔只负责查看日志、放行端口、做系统管理

#### 方案 B：宝塔 Nginx 反代到 Docker

适合宝塔已经在占用 80 / 443 的情况。

- 让 Docker 的 Nginx 改成其他宿主机端口
- 宝塔 Nginx 反向代理到容器端口
- 这样宝塔继续负责域名、证书和站点配置

### 3.3 生产环境必须改的变量

建议把 `docker/.env` 改成你的真实域名，例如：

- `CONSOLE_API_URL=https://dify.example.com`
- `SERVICE_API_URL=https://dify.example.com`
- `APP_WEB_URL=https://dify.example.com`
- `NEXT_PUBLIC_API_PREFIX=https://dify.example.com/console/api`
- `NEXT_PUBLIC_PUBLIC_API_PREFIX=https://dify.example.com/api`
- `NEXT_PUBLIC_SOCKET_URL=wss://dify.example.com`
- `COOKIE_DOMAIN=example.com`
- `NEXT_PUBLIC_COOKIE_DOMAIN=1` 或按你的域名策略配置

如果前后端分不同子域名，`COOKIE_DOMAIN` 必须是顶级域名，才能共享登录态。

### 3.4 数据持久化

Docker 部署时要保留这些目录：

- `docker/volumes/`
- `api/storage/` 或 Docker 挂载的存储路径

数据库、Redis、向量库和上传文件都依赖这些持久化卷。

## 4. API 文档整理方式

仓库已经有生成好的 API 文档目录：

- `api/openapi/markdown/console-swagger.md`
- `api/openapi/markdown/service-swagger.md`
- `api/openapi/markdown/web-swagger.md`

### 4.1 生成 OpenAPI JSON

```bash
cd api
uv run dev/generate_swagger_specs.py --output-dir openapi
```

### 4.2 生成 Markdown API 文档

```bash
cd api
uv run dev/generate_swagger_markdown_docs.py --swagger-dir openapi --markdown-dir openapi/markdown --keep-swagger-json
```

### 4.3 建议的文档整理结构

如果你要把文档整理成可维护的形式，建议拆成这几类：

1. `docs/deploy-local-bt-api.md`
   - 本地运行
   - 宝塔 / Docker 部署
   - 环境变量说明

2. `api/openapi/markdown/*.md`
   - 接口定义
   - 由脚本生成，尽量不要手工改

3. `docs/api-overview.md`
   - 说明前后端如何调用
   - 说明 console / service / web 三类接口的区别

4. `docs/api-env.md`
   - 汇总所有关键环境变量
   - 标出开发、测试、生产的取值差异

## 5. 你现在可以直接照着做的最短路径

### 本地

```bash
./dev/setup
./dev/start-docker-compose
./dev/start-api
./dev/start-web
./dev/start-worker
```

访问：

- 前端：`http://localhost:3000`
- 后端：`http://localhost:5001`

### 宝塔服务器

```bash
cd docker
cp .env.example .env
cp envs/middleware.env.example middleware.env
docker compose up -d
```

然后把域名、反代、Cookie 域名、WebSocket 地址改成你的真实线上配置。

## 6. 注意事项

- 不要把 `localhost` 直接带到线上环境
- 不要忘记设置 `SECRET_KEY`
- 前后端跨域或跨子域时，要同步配置 `COOKIE_DOMAIN`
- 如果要长期维护接口文档，尽量用脚本重新生成，不要手工编辑生成文件
