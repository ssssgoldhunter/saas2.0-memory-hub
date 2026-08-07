# FRONT-P0-003 LiteFlow 业务异常和具体返回类型未闭环

- 状态：OPEN
- 优先级：P0
- 影响：预期业务失败可能变成系统异常；授权码和分页失败路径可能出现类型转换异常或错误响应结构。

## 证据

- `FrontTransactionDispatchNode`、`FrontQueryDispatchNode` 未捕获 Handle 抛出的 `FrontException`。
- `FrontFlowExecutor` 在 Slot 业务失败时返回普通 `FrontBaseResult`。
- 授权码重发直接强转 `FrontTransferAuthCodeResult`。
- 两个分页查询直接强转 `FrontPageResult<TransactionDetailItem>`。
- 分页异常若进入全局异常处理器，会返回 `R<FrontBaseResult>`，违反 `TableDataInfo<T>` 协议。

## 修改范围

- 两个 Dispatch Node。
- `FrontFlowExecutor`。
- 两个 Application Service。
- 分页业务异常收口方案。

## 验收标准

1. LiteFlow 节点捕获预期 `FrontException`，写 Slot 后 `setIsEnd(true)`。
2. 系统异常继续抛出。
3. 执行器不制造与接口声明类型不一致的占位对象。
4. 单笔失败返回 `R.fail` 且 data 是声明的具体结果类型。
5. 分页失败始终返回 `TableDataInfo`，`code=500`、空 rows、安全 msg。
