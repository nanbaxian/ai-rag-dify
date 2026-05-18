# 本地运行、宝塔直跑与 API 文档说明

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
   - 默认访问 `http://localhost:3002`

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

## 3. 宝塔直跑（无 Docker）

这条路径适合你要在服务器上直接跑源码，不使用 Docker。

### 3.1 你需要先准备的服务

至少准备这些运行时：

- Python 3.12
- Node.js 20+
- pnpm
- `uv`
- PostgreSQL
- Redis
- 向量数据库

说明：

- 仓库默认配置指向 Weaviate
- 如果你不想单独部署 Weaviate，需要改成你自己能长期维护的向量存储方案

### 3.2 推荐进程拆分

建议在宝塔服务器上拆成 4 个进程：

1. 后端 API
2. Celery worker
3. 前端 Web
4. Nginx 反向代理

### 3.3 安装依赖

在仓库根目录执行：

```bash
cd api
uv sync --group dev
cd ..
pnpm install
```

### 3.4 配置环境文件

使用这两个文件，不要用 Docker 的 `.env`：

- `api/.env`
- `web/.env.local`

先从示例复制：

```bash
cp api/.env.example api/.env
cp web/.env.example web/.env.local
```

然后重点修改：

- `api/.env`
  - `CONSOLE_API_URL`
  - `SERVICE_API_URL`
  - `APP_WEB_URL`
  - `FILES_URL`
  - `INTERNAL_FILES_URL`
  - `COOKIE_DOMAIN`
  - `SECRET_KEY`
  - `DB_HOST`
  - `DB_PORT`
  - `DB_DATABASE`
  - `REDIS_HOST`
  - `REDIS_PORT`

- `web/.env.local`
  - `NEXT_PUBLIC_API_PREFIX`
  - `NEXT_PUBLIC_PUBLIC_API_PREFIX`
  - `NEXT_PUBLIC_SOCKET_URL`
  - `NEXT_PUBLIC_COOKIE_DOMAIN`

如果前后端用不同子域名，`COOKIE_DOMAIN` 要填顶级域名。

### 3.5 数据库迁移

先执行迁移：

```bash
cd api
uv run flask db upgrade
```

### 3.6 启动后端

开发调试可以用：

```bash
cd api
uv run flask run --host 0.0.0.0 --port 5001 --debug
```

生产建议用 `gunicorn`，仓库的容器入口也是这么做的，参数见 [api/docker/entrypoint.sh](/c:/wamp64/www/ai-rag-dify/api/docker/entrypoint.sh#L126)：

```bash
cd api
uv run gunicorn \
  --bind 0.0.0.0:5001 \
  --workers 1 \
  --worker-class geventwebsocket.gunicorn.workers.GeventWebSocketWorker \
  --worker-connections 10 \
  --timeout 200 \
  app:socketio_app
```

### 3.7 启动 worker

```bash
cd api
uv run celery -A celery_entrypoint.celery worker -P gevent -c 1 --max-tasks-per-child 50 --loglevel INFO -Q dataset,dataset_summary,priority_dataset,priority_pipeline,pipeline,mail,ops_trace,app_deletion,plugin,workflow_storage,conversation,workflow,schedule_poller,schedule_executor,triggered_workflow_dispatcher,trigger_refresh_publisher,trigger_refresh_executor,retention,workflow_based_app_execution
```

如果你是社区版，这个队列列表和仓库默认逻辑是一致的。

### 3.8 启动前端

```bash
cd web
pnpm build
pnpm start
```

默认前端服务跑在 `3002`。

### 3.9 宝塔 Nginx 反代

宝塔里把域名反代到你的前端和后端：

- 前端：`http://127.0.0.1:3002`
- 后端：`http://127.0.0.1:5001`

如果你想只暴露一个域名，常见做法是：

- `https://your-domain.com` -> 前端
- `https://your-domain.com/console/api` -> 后端
- `https://your-domain.com/api` -> 后端

Socket.io 也要一起反代到后端。

### 3.10 日常管理建议

宝塔上建议用：

- `supervisord`
- 或 `systemd`
- 或宝塔的守护进程功能

来托管 API、worker、Web 三个长进程。

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

- 前端：`http://localhost:3002`
- 后端：`http://localhost:5001`

### 宝塔服务器直跑

```bash
cd api
uv sync --group dev
uv run flask db upgrade
uv run gunicorn --bind 0.0.0.0:5001 --workers 1 --worker-class geventwebsocket.gunicorn.workers.GeventWebSocketWorker --worker-connections 10 --timeout 200 app:socketio_app
```

另开终端启动：

```bash
cd api
uv run celery -A celery_entrypoint.celery worker -P gevent -c 1 --max-tasks-per-child 50 --loglevel INFO -Q dataset,dataset_summary,priority_dataset,priority_pipeline,pipeline,mail,ops_trace,app_deletion,plugin,workflow_storage,conversation,workflow,schedule_poller,schedule_executor,triggered_workflow_dispatcher,trigger_refresh_publisher,trigger_refresh_executor,retention,workflow_based_app_execution
```

再启动前端：

```bash
pnpm install
cd web
pnpm build
pnpm start
```

然后把宝塔 Nginx 反代到 `3002` 和 `5001`。

## 6. 注意事项

- 不要把 `localhost` 直接带到线上环境
- 不要忘记设置 `SECRET_KEY`
- 前后端跨域或跨子域时，要同步配置 `COOKIE_DOMAIN`
- 如果要长期维护接口文档，尽量用脚本重新生成，不要手工编辑生成文件
