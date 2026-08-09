# FRONT-P1-002 specialData 缺少按银行业务方法的必填校验

- 状态：CLOSED
- 优先级：P1
- 影响：必填字段缺失时可能在 SM2 加密或报文组装阶段产生 NPE，并被当成系统异常。

## 证据

- 两家交易 Handle 大量直接调用 `context.specialData().getString(key)`。
- 中信仅平台收付款等少量路径使用 `requireSpecialData`。
- 平安交易路径没有在具体业务方法入口完成必填校验。

## 修改原则

- 每个“银行 + 具体 Handle 方法”建立明确的必填 key 集合和可选白名单。
- 校验由具体业务方法执行，不通过统一 capability 校验表或公共校验节点分派。
- 校验发生在落 INIT 记录和调用银行之前。
- 缺失或格式错误统一抛 `FrontException(INVALID_REQUEST)`，由 LiteFlow 业务失败路径收口。
- 不整体透传或 `putAll` specialData。

## 验收标准

1. 8 个交易入口按实际支持银行完成必填校验。
2. 非白名单字段不得进入银行报文。
3. 敏感字段不进入异常消息和日志。
4. 校验 key 与 common-core 常量、字段契约完全一致。

## 当前修复证据（2026-08-09 静态审查）

- 校验已放在“银行 + 具体 Handle 方法”内部，并在 INSERT INIT 和钱包调用前执行。
- Handle 通过 `requireSpecialData` 校验该接口实际需要的 key，不依赖 capability 全局校验表。
- 银行报文由代码逐字段装配，没有 `putAll(specialData)`。
- “白名单”只表示仅显式映射的字段可以进入银行报文，不要求建立公共白名单或拒绝所有额外请求 key。
- 用户已确认关闭；本轮未重新执行编译或测试。
