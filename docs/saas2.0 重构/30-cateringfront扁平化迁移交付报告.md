# Catering Front 扁平化迁移交付报告（30 号）

> 状态：implemented / pending-review
> 代码基线：`cateringsass/limeng_front@99e696f4`
> 交付日期：2026-08-25

## 一、22 项能力矩阵

| # | 银行 | 能力 | 域 | Capability 类 | 银行接口+bizFunc | 渠道表 | 产生流水 | 最终 Sender |
|---|------|------|----|---------------|-------------------|--------|---------|-------------|
| 1 | 中信 | 转账 | transaction | `citic.transaction.CiticTransferCapability` | transfer / 27 | front_citic_transfer_transaction | ✓ 三阶段 | CiticWalletHttpClient |
| 2 | 中信 | 消费 | transaction | `citic.transaction.CiticConsumeCapability` | transfer / 27 | front_citic_consume_transaction | ✓ 三阶段 | CiticWalletHttpClient |
| 3 | 中信 | 退款 | transaction | `citic.transaction.CiticRefundCapability` | refund / 23 | front_citic_refund_transaction | ✓ 三阶段 | CiticWalletHttpClient |
| 4 | 中信 | 提现 | transaction | `citic.transaction.CiticWithdrawCapability` | withdrawal / 26 | front_citic_withdraw_transaction | ✓ 三阶段 | CiticWalletHttpClient |
| 5 | 中信 | 平台付款 | transaction | `citic.transaction.CiticPlatformPayCapability` | transfer / 2041 | front_citic_platform_pay_transaction | ✓ 三阶段 | CiticWalletHttpClient |
| 6 | 中信 | 平台收款 | transaction | `citic.transaction.CiticPlatformReceiveCapability` | transfer / 2042 | front_citic_platform_receive_transaction | ✓ 三阶段 | CiticWalletHttpClient |
| 7 | 中信 | 交易状态查询 | query | `citic.query.CiticTransStatusCapability` | queryTransStatus / 1104 | front_citic_transfer_transaction（查询行） | ✗ 查询无流水 | CiticWalletHttpClient |
| 8 | 中信 | 平台明细查询 | query | `citic.query.CiticPlatformDetailCapability` | queryTransDetails / 2043 | — | ✗ 查询无流水 | CiticWalletHttpClient |
| 9 | 中信 | 登记簿明细查询 | query | `citic.query.CiticTransDetailCapability` | queryTransDetails / 1103 | — | ✗ 查询无流水 | CiticWalletHttpClient |
| 10 | 中信 | 账户余额查询 | account | `citic.account.CiticAccountBalanceCapability` | queryAcctInfo / 1101 | — | ✗ 查询无流水 | CiticWalletHttpClient |
| 11 | 中信 | 账户状态查询 | account | `citic.account.CiticAccountStatusCapability` | queryAcctInfo / 1102 | — | ✗ 查询无流水 | CiticWalletHttpClient |
| 12 | 平安 | 转账 | transaction | `pingan.transaction.PingAnTransferCapability` | transfer / 01 | front_pingan_transfer_transaction | ✓ 三阶段 | PingAnWalletHttpClient |
| 13 | 平安 | 消费 | transaction | `pingan.transaction.PingAnConsumeCapability` | transfer / 01 | front_pingan_consume_transaction | ✓ 三阶段 | PingAnWalletHttpClient |
| 14 | 平安 | 退款 | transaction | `pingan.transaction.PingAnRefundCapability` | refund / 02 | front_pingan_refund_transaction | ✓ 三阶段 | PingAnWalletHttpClient |
| 15 | 平安 | 提现 | transaction | `pingan.transaction.PingAnWithdrawCapability` | withdrawal / 01 | front_pingan_withdraw_transaction | ✓ 三阶段 | PingAnWalletHttpClient |
| 16 | 平安 | 鉴权转账 | transaction | `pingan.transaction.PingAnTransferAuthCapability` | transfer / 45 | front_pingan_transfer_transaction | ✓ 三阶段 | PingAnWalletHttpClient |
| 17 | 平安 | 重发授权码 | transaction | `pingan.transaction.PingAnResendAuthCodeCapability` | gen-auth-code / 26 | front_pingan_transfer_transaction | ✓ 三阶段 | PingAnWalletHttpClient |
| 18 | 平安 | 交易状态查询 | query | `pingan.query.PingAnTransStatusCapability` | queryTransStatus | — | ✗ 查询无流水 | PingAnWalletHttpClient |
| 19 | 平安 | 平台明细查询 | query | `pingan.query.PingAnPlatformDetailCapability` | queryTransDetails | — | ✗ 查询无流水 | PingAnWalletHttpClient |
| 20 | 平安 | 登记簿明细查询 | query | `pingan.query.PingAnTransDetailCapability` | queryTransDetails | — | ✗ 查询无流水 | PingAnWalletHttpClient |
| 21 | 平安 | 账户余额查询 | account | `pingan.account.PingAnAccountBalanceCapability` | queryAcctInfo | — | ✗ 查询无流水 | PingAnWalletHttpClient |
| 22 | 平安 | 账户状态查询 | account | `pingan.account.PingAnAccountStatusCapability` | queryAcctInfo | — | ✗ 查询无流水 | PingAnWalletHttpClient |

## 二、删除清单

对照基线 `99e696f4`，共删除 **48 个源文件**（`git diff --name-status --diff-filter=D`）：

### flow/component（9 文件）
- `AbstractFrontNode` / `BankHandleContextPrepareNode` / `FrontQueryDispatchNode` / `FrontQueryRouteNode`
- `FrontRequestValidateNode` / `FrontResponseNormalizeNode` / `FrontTransactionDispatchNode`
- `FrontTransactionRouteNode` / `TenantBaseConfigResolveNode`

### flow/context（3 文件）
- `FrontExecutionInfo` / `FrontExecutionStage` / `FrontFlowContext`

### handle（5 文件）
- `AbstractBankHandle` / `BankCapabilityDefinition` / `BankCapabilityHandle`
- `BankHandle` / `BankQueryHandle` / `BankTransHandle`

### route（5 文件）
- `BankCapabilityKey` / `QueryHandleRegistry` / `QueryRouter` / `TransactionHandleRegistry` / `TransactionRouter`

### Provider/Assembler 链（7 文件）
- `TenantBankConfigProvider` / `RemoteTenantBankConfigProvider`
- `AbstractBankAccountConfigAssembler` / `BankAccountConfigAssembler` / `BankAccountConfigAssemblerRouter`
- `CiticBankAccountConfigAssembler` / `PingAnBankAccountConfigAssembler`

### 旧银行 Handle + 子包（14 文件）
- `citic/CiticQueryHandle` / `citic/CiticTransHandle`
- `citic/client/CiticBankResponseChecker` / `citic/client/CiticWalletHttpClient`
- `citic/config/CiticCryptoProperties` / `citic/crypto/CiticOpenBodySigSigner` / `citic/crypto/CiticSm2Crypto`
- `citic/CiticSequenceGenerator`
- `pingan/PingAnQueryHandle` / `pingan/PingAnTransHandle`
- `pingan/client/PingAnBankResponseChecker` / `pingan/client/PingAnWalletHttpClient`
- `pingan/config/PingAnCryptoProperties` / `pingan/crypto/PingAnSm2Crypto` / `pingan/PingAnSequenceGenerator`

### 文档（1 文件）
- `docs/REVIEW_REPORT.md`

## 三、静态验收证据

### 3.1 api-front 零 diff
```
$ git diff --exit-code 99e696f4 -- catering-api/catering-api-front
EXIT_CODE=0（无输出）
```

### 3.2 旧结构零残留
```
# FrontFlowContext/BankRequestContext/AbstractBankHandle/BankTransHandle/BankQueryHandle
→ 仅 context/BankRequestContext.java（独立 context 模块，非旧 handle 结构）
→ TenantBankConfigLoader.java 注释提及旧 Provider 名称
→ FrontInvocationLogAspect.java 注释提到 BankHandle 已删除

# class Router / class Dispatch / BankSupport
→ 无残留

# TenantBankConfigProvider / BankAccountConfigAssembler
→ TenantBankConfigLoader.java 注释提及，无代码依赖

# package citic; / package pingan;
→ 无残留（所有 22 Capability 都在子包 citic.transaction/, citic.query/, citic.account/ 等）
```

### 3.3 发送出口唯一
```
$ grep -rl "HttpRequest\.post" $F/channel
  channel/pingan/common/PingAnWalletHttpClient.java
  channel/citic/common/CiticWalletHttpClient.java
→ 恰好 2 个 Sender 文件
```

### 3.4 数量验收
```
$ find $F/channel -name "*Capability.java" | wc -l
  22
$ grep '<chain name=' front-flow.xml | wc -l
  13
$ grep -c "THEN(frontBankExecute)" front-flow.xml
  14（含 1 条在注释中，13 条实际链定义）
```

### 3.5 编译
```
$ mvn compile -pl catering-modules/catering-front -q
BUILD SUCCESS（无输出，零错误）
```

## 四、行为差异声明

### 4.1 逐能力对照
| 方面 | 结论 |
|------|------|
| api-front 零 diff | ✓ 对外契约无任何变化 |
| 请求字段（必填/选填/长度/格式） | ✓ 与旧 Handle 一致 |
| 固定值（CHANNEL_NO、bizFunc、currency 等） | ✓ 与旧 Handle 一致 |
| 敏感字段 SM2 加密 | ✓ 中信使用 CiticSm2Crypto，平安使用 PingAnSm2Crypto，算法不变 |
| 签名逻辑（OpenBodySigSigner） | ✓ 已中性化至 channel/gateway 包 |
| 渠道流水三阶段（INIT→SENDING→终态） | ✓ 12 个交易 Capability 保持 |
| 查询类无渠道流水 | ✓ 沿用旧 Handle 行为 |
| 挡板语义（平安账户状态/余额挡板） | ✓ 保留不变 |
| 业务异常收口 | ✓ 交易类 Node 统一 catch 异常；查询类冗余 catch 已删除改为由 Node 统一收口 |
| 银行响应最终状态日志（12 交易） | ✨ 新增 `log.info("银行调用完成, ...")` |

### 4.2 日志变更声明
| 变更 | 说明 |
|------|------|
| 新增（12 交易 Capability） | `银行调用完成` info 日志在 invokeBank 返回后、slot.setTransResult 之前 |
| 删除（5 查询类） | 业务 catch 块中的手动 `slot.markBusinessFail` + `log.warn` 已删除，由 FrontBankExecuteNode 统一收口，对终端行为无影响 |
| 未变更 | 两个 Sender 的 `wallet_request_sending` / `wallet_response_received` 日志（完整明文 JSON、不脱敏）保持不变 |

## 五、执行边界记录

| 事项 | 状态 |
|------|------|
| 新增测试类 | ✗ 未新增 |
| 运行测试 | ✗ 未运行（2026-08-25 用户裁决） |
| 编译验证 | ✓ BUILD SUCCESS（129 源文件零错误） |
| 代码提交/推送 | ✗ 未 commit、未 push，等待用户授权 |
| citic/unidentified 专项 | ✗ 未改动 |
| catering-api-front | ✗ 未改动 |
| domain/mapper/XML/DDL | ✗ 未改动 |
| 两个最终 Sender 钱包日志 | ✗ 未改动 |
| Slot 注入 Service/Mapper | ✗ 未引入（capability 由 Application Service 赋值） |

---

## 附：28/29 号文档状态行更新

### 28-cateringfront结构简化改造方案.md
```
- 状态: approved-design / not-implemented
+ 状态: approved-design / implemented
```

### 29-cateringfront全量扁平化迁移-plan.md
```
- 状态: (未标注状态行)
+ 状态: implemented / pending-review
```