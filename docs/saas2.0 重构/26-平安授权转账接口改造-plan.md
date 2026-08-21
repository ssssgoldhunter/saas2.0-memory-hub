# 平安授权转账接口改造 plan（25 号 spec 执行计划）

> 状态：pending（2026-08-21 建立待实施；任务领取顺序 T1→T6，一次改造不混入其他能力）
>
> 依据：25 号 spec（契约）、24 号方案（背景）、22/23 号（lsym 基线）
>
> 红线：不新增测试类、不运行测试、未授权不编译、不 commit/push；只动平安授权两能力
> 及 payMemberCode 更名波及面；不动中信（保持未登记 F200002）。

## 改造波及文件总表

| 模块 | 文件 | 改动 |
|---|---|---|
| api-front | `model/enums/AuthType.java` | **新增**（SMS/APP） |
| api-front | `constant/front/PingAnTransferAuthContractKeys.java` | 对外键更名/新增：PAY_MEMBER_CODE/REC_MEMBER_CODE/AUTH_ORDER_NO/AUTH_CODE/AUTH_TYPE；保留协议键 RESERVE_MESSAGE_ORDER_NO/RESERVE_MESSAGE_CHECK_CODE |
| api-front | `constant/front/PingAnTransferAuthCodeContractKeys.java` | 新增 AUTH_ORDER_NO/AUTH_TYPE；保留 RESPONSE_SMS_INDEX/RESPONSE_RECEIVE_MOBILE（银行响应键） |
| api-front | `constant/front/PingAnTransferContractKeys.java` | PAY_MEMBER_ID/REC_MEMBER_ID → PAY_MEMBER_CODE/REC_MEMBER_CODE（transfer/consume 同步） |
| api-front | `model/response/FrontTransferAuthCodeResult.java` | **删除**（出参公用 FrontTransResult） |
| api-front | `FrontTransApi.java` | resendTransferAuthCode 签名 `R<FrontTransferAuthCodeResult>` → `R<FrontTransResult>` + @Operation 注释同步 |
| api-front | `assemble/FrontSpecialDataAssembler.java` | auth 标准结构加 authType 字段；transferAuth/transferAuthCodeResend 输入输出键同步 |
| api-front | `assemble/PingAnSpecialDataAssembler.java` | transferAuth() 输出 authType/authOrderNo/authCode；transferAuthCodeResend() 输入校验 authType（非 SMS 拒绝） |
| catering-front | `handle/BankTransHandle.java` | resendTransferAuthCode default 方法返回类型 FrontTransResult |
| catering-front | `channel/pingan/PingAnTransHandle.java` | transferAuth：specialData 读 AUTH_* 键 → reserve 协议键映射 + authType 校验；resendTransferAuthCode：返回 FrontTransResult、specialData 写 authType/authOrderNo（smsIdx 解密值）/receiveMobile；transfer/consume/resend 的 PAY_MEMBER_ID 引用点全部更名；**checkDuplicateTransaction 加 capability 过滤 + 验证码发送豁免查重（25 号 §3A）** |
| catering-front | `application/FrontTransApplicationService.java` | resendTransferAuthCode 泛型同步 |
| catering-front | `controller/FrontTransController.java` | 返回类型同步 |
| web-test | `controller/FrontTestController.java` | resendTransferAuthCode 泛型同步 |
| web-test | `static/js/app.js` | 授权码 Tab 返回展示字段（authOrderNo/authType）适配（若有硬编码 smsIdx 展示） |

## 任务清单

### Phase 1 — api-front 契约层（T1）

- [ ] T1 新增 `AuthType` 枚举（SMS/APP，字段级注释）
- [ ] T2 `PingAnTransferContractKeys`：PAY_MEMBER_ID/REC_MEMBER_ID 更名
      PAY_MEMBER_CODE/REC_MEMBER_CODE（保留旧常量删除，全仓引用同步更名，不留兼容别名）
- [ ] T3 `PingAnTransferAuthContractKeys`：新增对外键 AUTH_ORDER_NO/AUTH_CODE/AUTH_TYPE、
      会员键更名；协议键改注释标明"仅 Handle 内部 reserve 映射使用"
- [ ] T4 `PingAnTransferAuthCodeContractKeys`：新增 AUTH_ORDER_NO/AUTH_TYPE（含
      "smsIdx 解密后以 authOrderNo 对外"注释）
- [ ] T5 组装器：`FrontSpecialDataAssembler` auth 结构加 authType（必填校验 SMS）；
      `PingAnSpecialDataAssembler.transferAuth()` 输出语义键；
      `transferAuthCodeResend()` 输入校验 authType、输出 payMemberCode 等语义键
- [ ] T6 `FrontTransApi` 签名 + 删除 `FrontTransferAuthCodeResult`

### Phase 1A — 查重策略修正（T1A，并入 Handle 层一并实施）

- [ ] T1A `checkDuplicateTransaction` 增加 capability 过滤参数（按本能力记录查重）；
      `resendTransferAuthCode` 的 INIT 走免查重直插路径（豁免 DEDUP_LOCKS）；
      transfer/consume/transferAuth/withdraw 调用点传各自 capability

### Phase 2 — catering-front Handle 层（T2）

- [ ] T7 `PingAnTransHandle.transferAuth`：specialData 读取键改 AUTH_ORDER_NO/AUTH_CODE/
      AUTH_TYPE + 会员键更名；reserve 写入用协议键常量；authType 非 SMS 抛 INVALID_REQUEST
- [ ] T8 `PingAnTransHandle.resendTransferAuthCode`：返回类型 FrontTransResult（补
      frontStatus=SUCCESS/FAILED）；specialData 写 AUTH_TYPE/AUTH_ORDER_NO（smsIdx 解密值）/
      receiveMobile；错误原文中转逻辑保持
- [ ] T9 `BankTransHandle` default 方法、`FrontTransApplicationService`、
      `FrontTransController` 泛型同步；transfer/consume/resend 全部 PAY_MEMBER_ID 引用点更名
- [ ] T10 渠道表映射核对（**结论 2026-08-21：front 侧零 DDL**）：授权两能力落
      front_pingan_transfer_transaction（capability 区分，WIKI §6 既有裁决，现有实现
      已验证）；authOrderNo 不落渠道列（specialData 返回 + front_ssn/bank_query_id
      已足够关联）

### Phase 3 — web-test（T3）

- [ ] T11 `FrontTestController` 泛型同步；app.js 授权码 Tab 展示 authOrderNo/authType
      （确认无 smsIdx 硬编码）

### Phase 4 — 文档同步（T4）

- [ ] T12 07 号契约：两接口字段全面更新（语义键、AuthType、FrontTransResult、
      receiveMobile 口径 §4.1 默认值）
- [ ] T13 15 号 spec：auth 标准结构加 authType；(bank × capability) 矩阵的
      transferAuth/transferAuthCodeResend 输出键更新；16 号 plan 补实施记录
- [ ] T14 20 号手册：§7/§8 请求返回示例更新（语义键 + authType + FrontTransResult）；
      transfer/consume 的 specialData 会员键更名同步
- [ ] T15 24 号标记已实施、25 号 spec 状态 confirmed→implemented、WIKI 必读清单补
      25/26 号、`catering-front/README.md` 授权段落同步、14 号 web-test 说明（如涉及）

### Phase 5 — 静态验收（T5）

- [ ] T16 `git diff --check`；grep 残留：对外键不得再出现 payMemberId/recMemberId/
      messageOrderNo/messageCheckCode/smsIdx（协议键常量与 Handle 内部映射除外）；
      FrontTransferAuthCodeResult 无引用
- [ ] T17 编译验证：**需用户当次明确授权**（front 链 5 模块）
- [ ] T18 联调清单执行（25 号 §5 + 24 号 §5 六场景，环境就绪时）

## 附：consume 侧表设计（本次 front 改造不含，consume 对接时实施）

参考 lsym trans_valid_log 的双层存储（历史审计 + 当前生效指令号），SaaS 化设计：

- `consume_trans_auth_code_log`（逐次追加审计表）：tenant_id、biz_order_no、
  biz_sub_order_no、biz_transaction_id、front_ssn、auth_type（SMS/APP，对应 AuthType）、
  auth_order_no（= front 返回 specialData.authOrderNo）、receive_mobile（SMS 类型）、
  front_query_id、审计四字段；索引 (tenant_id, biz_order_no, biz_sub_order_no) 和
  (front_ssn)。
- 业务子单表加 `current_auth_order_no` 一列（覆盖式更新）：授权转账从此列取
  auth.authOrderNo 上送，等价 lsym transfer_sub.trans_valid_order_no。
- front 渠道表不动（零 DDL）。

与 lsym 差异：定位四件套收敛为 biz 主/子单号；双通道 0/1 标记列收敛为 auth_type 枚举。

## 实施顺序与依赖

```text
T1→T6（契约层，纯 api-front）
  → T7→T10（Handle 层依赖新键常量）
    → T11（web-test 依赖 API 签名）
      → T12→T15（文档）
        → T16（静态）→ T17/T18（授权后）
```

## 风险与回退

| 风险 | 缓解 |
|---|---|
| payMemberCode 更名波及 transfer/consume 对外契约 | 消费方（consume）尚未接入无实际调用；web-test 走组装器自动适配；20 号手册同步 |
| receiveMobile 解密口径（25 号 §4.1） | 默认保持解密；联调失败按银行实际返回修正，单点改动 |
| FrontTransferAuthCodeResult 删除后遗漏引用 | T16 grep 全仓无引用收口 |
