# catering-common 公共框架技术文档

> 扫描日期：2026-08-06
> 扫描范围：`catering-common` 下全部 32 个子模块
> 用途：后续开发参考，快速了解公共框架提供了哪些能力

---

## 速查表（给业务开发/AI 的重点）

| 想做的事 | 用什么 |
|---|---|
| 统一返回 | `R.ok(data)` / `R.fail(msg)` |
| 抛业务异常 | `throw new ServiceException("xxx")` 或 `throw new FrontException(FrontErrorCode.XXX)` |
| 获取当前登录用户 | `LoginHelper.getLoginUser()` / `getUserId()` / `getTenantId()` |
| 获取/切换租户 | `TenantHelper.getTenantId()` / `ignore(...)` / `dynamic(id,...)` |
| 获取请求上下文 | `RequestContext.getTenantId()` / `getPlatformCode()` / `getDataSourceId()` |
| 实体基类 | 继承 `BaseEntity`（自动审计字段 createBy/createTime/updateBy/updateTime） |
| 请求基类 | 继承 `BaseRequest`（含 tenantId/clientId/platformCode/dataSourceId/operator/orgCode/firstCode/merchantId） |
| 分页查询入参 | 继承 `BasePageQuery`（含分页 + 请求上下文字段）或 `PageQuery`（含排序） |
| 分页结果 | `TableDataInfo.build(page)` |
| Mapper | 继承 `BaseMapperPlus<T, V>`（自动 VO 转换、批量操作） |
| 对象转换 | `MapstructUtils.convert(source, Target.class)` |
| 缓存 | `RedisUtils.setCacheObject/getCacheObject` 或 `@Cacheable` |
| JSON | `JsonUtils.toJsonString/parseObject` |
| 操作日志 | Controller 加 `@Log(title, businessType)` |
| 防重提交 | 方法加 `@RepeatSubmit` |
| 限流 | 方法加 `@RateLimiter` |
| 字段加密 | 实体加 `@EncryptField` |
| 字段脱敏 | VO 加 `@Sensitive` |
| 字段翻译 | VO 加 `@Translation` |
| 数据权限 | Mapper/方法加 `@DataPermission` |
| Excel | `ExcelUtil.exportExcel/importExcel` |
| 文件上传 | `OssFactory.instance().upload(...)` |
| Sa-Token 鉴权 | `@SaCheckPermission` / `@SaCheckRole` |
| 分布式事务 | `@GlobalTransactional` |
| Spring Bean | `SpringUtils.getBean(X.class)` |

---

## 模块清单（32 个）

### 基础核心

#### catering-common-core
**功能**：框架基础核心，统一响应体、异常体系、请求上下文、工具类、常量、自动装配。

| 类名 | 包 | 职责 |
|---|---|---|
| `R<T>` | `domain` | 统一响应体（code/msg/data，SUCCESS=200/FAIL=500） |
| `BaseRequest` | `catering.base.request` | 请求基类（tenantId/clientId/platformCode/dataSourceId/operator/orgCode/firstCode/merchantId） |
| `BasePageQuery` | `catering.base.request` | 分页查询基类（继承 BasePage，含请求上下文字段） |
| `BasePage` | `catering.base.request` | 分页基类（pageNum/pageSize） |
| `RequestContext` | `context` | ThreadLocal 请求上下文（tenantId/clientId/platformCode/dataSourceId） |
| `RequestConstants` | `constant` | header 常量（X-Tenant-Id/X-Client-Id/Authorization/platformCode/dataSourceId） |
| `FrontErrorCode` | `error` | Front 业务错误码枚举（F100001~F900001） |
| `FrontException` | `exception` | Front 业务异常 |
| `ServiceException` | `exception` | 通用业务异常 |
| `MapstructUtils` | `utils` | MapStruct-Plus 对象转换工具 |
| `SpringUtils` | `utils` | Spring 上下文工具（getBean） |
| `StringUtils` | `utils` | 字符串工具（继承 commons-lang3） |
| `StreamUtils` | `utils` | 集合/Stream 工具 |
| `ServletUtils` | `utils` | Servlet 工具 |
| `DateUtils` | `utils` | 日期工具 |
| `DesensitizedUtils` | `utils` | 脱敏工具 |
| `SqlUtil` | `utils.sql` | SQL 防注入 |
| `AddressUtils` | `utils.ip` | IP 地址定位 |
| `ApplicationConfig` | `config` | @EnableAspectJAutoProxy + @EnableAsync |
| `ThreadPoolConfig` | `config` | 定时线程池（虚拟线程支持） |
| `ValidatorConfig` | `config` | Hibernate Validator fail-fast |
| **`constant/front/`** | `constant.front` | **银行协议和渠道字段常量**（以当前目录实际类为准，公用） |

---

#### catering-common-mybatis
**功能**：MyBatis-Plus 数据访问层封装。

| 类名 | 包 | 职责 |
|---|---|---|
| `BaseEntity` | `core.domain` | 实体基类（createBy/createTime/updateBy/updateTime + params） |
| `PageQuery` | `core.page` | 分页查询入参（pageNum/pageSize/orderByColumn/isAsc） |
| `TableDataInfo<T>` | `core.page` | 分页结果封装（total/rows/code/msg） |
| `BaseMapperPlus<T,V>` | `core.mapper` | 增强 Mapper（selectVoXxx + insertBatch/updateBatch） |
| `IService<T>` / `ServiceImpl<T>` | `core.service` | 业务 Service 基类 |
| `MybatisPlusConfiguration` | `config` | 自动装配（多租户→数据权限→分页→乐观锁） |
| `InjectionMetaObjectHandler` | `handler` | 自动填充审计字段 |
| `@DataPermission` | `annotation` | 数据权限注解 |
| `PlusDataPermissionInterceptor` | `interceptor` | 数据权限拦截器 |

> Front 遵循工程统一约束：单条接口返回 `R<T>`，分页明细查询直接返回
> `TableDataInfo<T>`，分页结果不再使用 `R` 二次包装。

---

#### catering-common-feign
**功能**：OpenFeign 封装，统一传递上下文。

| 类名 | 包 | 职责 |
|---|---|---|
| `FeignConfiguration` | `config` | 自动装配（@EnableFeignClients + 注册拦截器） |
| `FeignRequestInterceptor` | `interceptor` | **发送端**：转发 tenantId/clientId/platformCode/dataSourceId 等 header |
| `RequestContextInterceptor` | `interceptor` | **接收端**：从 header 提取到 ThreadLocal，请求结束清理 |
| `BaseDataRequestBodyAdvice` | `advice` | 将 RequestContext 中的识别字段写入请求 `baseData`；Front 外层为 `FrontRequest<T>` 时必须显式支持嵌套对象 |
| `FeignExceptionDecoder` | `decoder` | Feign 错误解码 |
| `FeignJsonDecoder` | `decoder` | Feign JSON 解码 |

---

### 安全与权限

#### catering-common-satoken
**功能**：Sa-Token 权限认证。
- `LoginHelper`：获取当前用户/租户/部门
- `SaPermissionImpl`：权限实现
- `PlusSaTokenDao`：Token 存储（Redis + Caffeine）

#### catering-common-security
**功能**：安全过滤层。
- `SecurityConfiguration`：注册 SaInterceptor + SaServletFilter

#### catering-common-encrypt
**功能**：数据库字段加解密 + API 请求体加解密。
- `@EncryptField`：字段加密注解（AES/RSA/SM2/SM4）
- `MybatisEncryptInterceptor`/`MybatisDecryptInterceptor`：自动加解密

#### catering-common-sensitive
**功能**：数据脱敏（Jackson 序列化时按角色/权限脱敏）。
- `@Sensitive`：脱敏注解（18 种策略：PHONE/ID_CARD/BANK_CARD 等）

---

### Web 与数据

#### catering-common-web
**功能**：Web 层封装（Undertow + 全局异常 + XSS + 国际化）。
- `GlobalExceptionHandler`：统一异常处理
- `XssFilter`：XSS 防护

#### catering-common-redis
**功能**：Redis（Redisson）封装。
- `RedisUtils`：日常 Redis 操作
- `CacheUtils`：Spring Cache 操作
- `PlusSpringCacheManager`：Redis + Caffeine 二级缓存
- Lock4j 分布式锁

#### catering-common-tenant
**功能**：多租户（SaaS）支持。
- `TenantHelper`：获取/切换/忽略租户
- `PlusTenantLineHandler`：MyBatis-Plus 租户插件
- `TenantKeyPrefixHandler`：Redis key 租户前缀

#### catering-common-json
**功能**：JSON 统一配置（Jackson）。
- `JsonUtils`：JSON 工具
- `JacksonConfig`：Long→String、LocalDateTime 格式化

#### catering-common-translation
**功能**：通用翻译（字典/部门/用户名/OSS URL）。
- `@Translation`：翻译注解

---

### 业务能力

#### catering-common-log
**功能**：操作日志（AOP + 异步事件）。
- `@Log`：操作日志注解

#### catering-common-idempotent
**功能**：接口幂等/防重复提交。
- `@RepeatSubmit`：防重注解

#### catering-common-ratelimiter
**功能**：接口限流。
- `@RateLimiter`：限流注解

#### catering-common-excel
**功能**：Excel 导入导出（FastExcel）。
- `ExcelUtil`：导入导出工具

#### catering-common-oss
**功能**：对象存储（S3 协议）。
- `OssFactory.instance().upload(...)`：文件上传下载

---

### 基础设施

| 模块 | 功能 |
|---|---|
| `catering-common-nacos` | Nacos 服务发现 + 配置中心 |
| `catering-common-seata` | Seata 分布式事务（@GlobalTransactional） |
| `catering-common-doc` | SpringDoc OpenAPI 接口文档 |
| `catering-common-job` | XXL-Job 定时任务 |
| `catering-common-loadbalancer` | 自定义负载均衡 |
| `catering-common-websocket` | WebSocket 长连接（集群 Redis 广播） |
| `catering-common-sse` | Server-Sent Events 推送 |
| `catering-common-social` | 第三方授权登录（JustAuth） |
| `catering-common-mail` | 邮件发送 |
| `catering-common-skylog` | SkyWalking 链路追踪 |
| `catering-common-prometheus` | Prometheus 监控 |
| `catering-common-bus` | Spring Cloud Bus 消息总线 |
| `catering-common-service-impl` | DictService/PermissionService 实现 |
| `catering-common-bom` | 统一版本管理 BOM |
| `catering-common-alibaba-bom` | Alibaba 生态版本 BOM |

---

## 包名拼写注意

- encrypt 模块的枚举包是 `com.chinaums.common.encrypt.enumd`（非 enums）
- loadbalancer 模块的包是 `com.chinaums.common.loadbalance`（无 r）
