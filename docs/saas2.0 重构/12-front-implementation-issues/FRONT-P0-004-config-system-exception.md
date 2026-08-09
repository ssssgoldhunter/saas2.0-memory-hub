# FRONT-P0-004 配置加载系统异常被伪装成配置不存在

- 状态：CLOSED
- 优先级：P0
- 影响：配置中心不可用、调用异常或代码解析异常会被当成租户未配置，LiteFlow 业务失败路径掩盖真实系统故障。

## 证据

- `RemoteTenantBankConfigProvider.load` 捕获所有 `RuntimeException`。
- 捕获后统一抛出 `FrontException(TENANT_BANK_CONFIG_NOT_FOUND)`。
- Feign、网络、反序列化及未知代码异常因此无法继续抛给系统异常处理链。

## 验收标准

1. 只有配置接口明确返回配置不存在、配置内容为空或必填配置字段缺失时，返回 `TENANT_BANK_CONFIG_NOT_FOUND`。
2. 银行编码未配置继续返回 `BANK_NOT_SUPPORTED`。
3. 配置中心通信、Feign、反序列化和未知运行时异常继续抛出，不转换成业务异常。
4. 系统异常记录完整服务端堆栈，但不得打印配置值、密钥或完整 URL。
5. 不恢复 configVersion、配置快照或本地版本控制。

## 2026-08-09 修复内容

修改文件：`RemoteTenantBankConfigProvider.java`

将原 `catch (RuntimeException exception)` 改为直接 `throw exception`（不再包装为 `TENANT_BANK_CONFIG_NOT_FOUND`）：

- Feign 超时、网络断开、反序列化等系统异常继续抛出，由 `BankHandleContextPrepareNode`（只捕 `FrontException`）放行 → `FrontFlowExecutor` 再抛 → `FrontExceptionHandler.handleUnexpectedException` 收口为 `INTERNAL_ERROR` + 完整堆栈 ✅
- 配置不存在/为空/必填字段缺失：`resolveConfigKey` 等方法抛出 `FrontException`（`TENANT_BANK_CONFIG_NOT_FOUND` / `BANK_NOT_SUPPORTED`），在 `catch (FrontException)` 分支原样继续抛出，由 `BankHandleContextPrepareNode` 捕获 → `failAndEnd` ✅
- 日志改为 `"租户银行配置加载系统异常"` 以区分原业务配置不存在的警告 ✅
