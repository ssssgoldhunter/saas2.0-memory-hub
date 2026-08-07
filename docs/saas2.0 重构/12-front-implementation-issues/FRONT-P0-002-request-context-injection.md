# FRONT-P0-002 请求头四字段无法可靠注入 FrontRequest.baseData

- 状态：OPEN
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
