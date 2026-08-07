# FRONT-P1-002 specialData 缺少按银行能力的必填校验

- 状态：OPEN
- 优先级：P1
- 影响：必填字段缺失时可能在 SM2 加密或报文组装阶段产生 NPE，并被当成系统异常。

## 证据

- 两家交易 Handle 大量直接调用 `context.specialData().getString(key)`。
- 中信仅平台收付款等少量路径使用 `requireSpecialData`。
- 平安交易路径没有统一的能力级必填校验。

## 修改原则

- 每个“银行 + capability”建立明确的必填 key 集合和可选白名单。
- 校验发生在落 INIT 记录和调用银行之前。
- 缺失或格式错误统一抛 `FrontException(INVALID_REQUEST)`，由 LiteFlow 业务失败路径收口。
- 不整体透传或 `putAll` specialData。

## 验收标准

1. 8 个交易入口按实际支持银行完成必填校验。
2. 非白名单字段不得进入银行报文。
3. 敏感字段不进入异常消息和日志。
4. 校验 key 与 common-core 常量、字段契约完全一致。
