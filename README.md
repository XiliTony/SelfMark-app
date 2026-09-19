# SelfMark

SelfMark uses `api/` for the Spring Boot API and `view/` for the Flutter client. Local infrastructure is managed from the repository root with Docker Compose.

SelfMark是一个习惯和反拖延应用程序。v1 后端提供
    1. 基于手机的注册/登录、BCrypt密码哈希、JWT身份验证、Redis支持的令牌吊销
    2. 私有/共享任务
    3. 订阅和日常安排。
它是一个模块化的整体，具有独立的客户端和 API，后续是AI代理和商务功能。

## Repository map

```text
api/                         Spring Boot API, Flyway migrations, tests
api/docs/openapi/             Modular OpenAPI source and generated distribution
api/src/main/resources/db/    Versioned Flyway migrations
view/                         Flutter client (created/maintained separately)
compose.yaml                  Local MySQL, Redis, optional RabbitMQ
```

The API is the only service the client calls. The client never connects directly to MySQL, Redis, or RabbitMQ.

## First-time local setup

1. Copy `.env.example` to `.env`.
2. Copy `api/src/main/resources/application-local.example.yml` to `api/src/main/resources/application-local.yml`.
3. Replace `selfmark.jwt.secret` in `application-local.yml` with a unique random value of at least 32 characters.
4. Start MySQL and Redis with `docker compose up -d`.
5. Start the API from `api/` with `./mvnw spring-boot:run` or run it from IntelliJ IDEA.

RabbitMQ is optional until a feature needs it:

```bash
docker compose --profile rabbitmq up -d
```

## Daily commands

```bash
docker compose up -d
docker compose ps
docker compose logs -f mysql redis
docker compose down
```

`docker compose down` keeps the named volumes. `docker compose down -v` permanently deletes local MySQL, Redis, and RabbitMQ volume data and should only be used intentionally.
保留数据就选择备份
