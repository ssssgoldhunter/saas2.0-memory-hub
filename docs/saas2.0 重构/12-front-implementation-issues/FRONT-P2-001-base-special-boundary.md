# FRONT-P2-001 baseData 与 specialData 字段边界未落实

- 状态：OPEN
- 优先级：P2
- 影响：API DTO 与已确认的“baseData 只放内部业务公共字段”约束冲突。

## 已确认遗留

- `PlatformTransferBusinessData.userAccountId/userAccountName` 被银行请求直接使用。
- `AccountStatusQueryData.accountId`。
- `AccountBalanceQueryData.accountId/functionalAccountType`。
- `TransactionDetailQueryData.accountId`；10 号契约已规定中信登记簿账户使用 `specialData.acctNo`。

## 验收标准

1. 账户、会员、姓名、卡号及银行专用筛选条件全部迁入当前能力 specialData。
2. baseData 只保留内部业务关联、金额、门店、分页等跨银行字段。
3. Handle 只通过常量读取 specialData，不使用自定义别名。
4. API DTO、common-core 常量、Handle 和 06～10 字段契约同步修改。
