# FRONT-P0-002 请求头四字段无法可靠注入 FrontRequest.baseData

- 状态：CLOSED
- 优先级：P0
- 影响：`tenantId/clientId/platformCode/dataSourceId` 可能为空，路由、配置查询和落库无法按约束执行。

## 证据

- `BaseDataRequestBodyAdvice.supports` 只识别外层 `BaseRequest`，但 Front Controller 参数是 `FrontRequest<T>`。
- Advice 仅标注 `@RestControllerAdvice`，`FeignConfiguration` 没有显式注册；Front 应用默认只扫描 `com.chinaums.front`。
- `FeignRequestInterceptor` 在没有 Servlet 请求时直接返回。
- `tenantId/clientId` 没有按“header 优先、RequestContext 兜底”补齐。
- 请求体值与 header 值冲突时当前静默保留请求体值。

## 修改范围

- `catering-common-feign/.../BaseDataRequestBodyAdvice.java`
- `catering-common-feign/.../FeignConfiguration.java`
- `catering-common-feign/.../FeignRequestInterceptor.java`
- 必要时调整公共请求上下文辅助类。

## 验收标准

1. Advice 由自动配置显式注册。
2. 同时支持直接 `BaseRequest` 和 `FrontRequest<T>.baseData`。
3. 四字段发送端逐项执行 header 优先、`RequestContext` 兜底。
4. 非 Web/异步线程存在 `RequestContext` 时仍能转发。
5. header 与请求体冲突时明确失败，不静默覆盖或保留。
6. `afterCompletion` 继续清理 ThreadLocal。

## 当前核验结果（2026-08-09）

静态核验已满足全部验收项：

1. `FeignConfiguration` 已通过 `@Bean baseDataRequestBodyAdvice()` 显式注册 Advice，不依赖 Front 包扫描。
2. `BaseDataRequestBodyAdvice.supports/afterBodyRead` 同时识别直接 `BaseRequest` 和
   `FrontRequest<T>.baseData`，并注入四字段。
3. body 与 `RequestContext` 同名字段冲突时明确抛出异常，不静默覆盖或保留冲突值。
4. `FeignRequestInterceptor.apply()` 不再在无 ServletRequest 时提前返回；四字段逐项按 header 优先、
   `RequestContext` 兜底转发。
5. `RequestContextInterceptor.afterCompletion` 继续清理 ThreadLocal。

## 修复记录（2026-08-09）

1. `FeignConfiguration.java`：新增 `@Bean baseDataRequestBodyAdvice()` 显式注册
   `BaseDataRequestBodyAdvice`，规避 Front 仅扫描 `com.chinaums.front` 包路径的问题。
2. `FeignRequestInterceptor.apply()` 重构：取消 `requestAttributes == null` 时的提前返回，
   将四字段（tenantId/clientId/platformCode/dataSourceId）提取从 ServletRequest 解耦，
   即使无 Web 请求也继续从 `RequestContext` 读取并转发 header。
   Sa-Token/Content-Language 等仅 Web 场景存在的字段仍限制在有 ServletRequest 时传递。
3. 冲突检测和 ThreadLocal 清理逻辑不变。

## 关闭记录（2026-08-09）

- 用户确认 Front 作为服务方时，从 Feign/HTTP 请求 header 接收
  `tenantId/clientId/platformCode/dataSourceId`，经 `RequestContext` 注入 `FrontRequest.baseData`；
- 用户确认 Front 作为请求方调用其他 Feign API 时，必须把上述四字段写入下游请求 header；
- 当前静态代码与该双向边界一致，本问题关闭。
