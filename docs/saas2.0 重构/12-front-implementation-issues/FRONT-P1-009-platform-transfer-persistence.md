# FRONT-P1-009 中信平台收付款落库方向错误

- 状态：CLOSED
- 优先级：P1
- 影响：渠道表记录的付款/收款账户方向与真实资金方向相反。

## 证据

- 平台付款银行请求把用户账户作为 `inAcctNo`，说明用户是收款方；落库却写 `payAccountId`。
- 平台收款银行请求把用户账户作为 `outAcctNo`，说明用户是付款方；落库却写 `recAccountId`。
- 用户名称没有同步保存到对应方向字段。

## 验收标准

1. platformPay：用户账户/名称写 `rec_account_id/rec_name`。
2. platformReceive：用户账户/名称写 `pay_account_id/pay_name`。
3. 银行请求方向、Entity、Mapper XML、DDL 字段字典及注释一致。
4. 用户账户和名称按最新字段边界从 specialData 获取。
