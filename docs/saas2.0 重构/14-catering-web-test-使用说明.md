# catering-web-test 接口测试工具

> 本文记录 catering-web-test 模块的用途、启动方式、使用说明和当前状态。
> 后续修改该工具时，应同步更新本文。

## 1. 概述

`catering-web-test` 是 `catering-front` 的接口测试工具模块，位于：

```
cateringsass/catering-modules/catering-web-test/
```

**定位**：一个轻量的可运行 Spring Boot 服务（非 JUnit 测试库），通过浏览器 UI 模拟外部业务系统调用 `catering-front` 的所有 API。

**核心技术栈**：Spring Boot 3.5 + FeignClient → `catering-front` + Bootstrap 5 前端 SPA。

## 2. 启动方式

```bash
cd cateringsass
mvn spring-boot:run -pl catering-modules/catering-web-test
```

启动后访问：`http://localhost:9207`

依赖：
- Nacos（服务发现，用于 Feign 调用 `catering-front`）
- `catering-front` 服务需已启动

## 3. 功能覆盖

覆盖 `catering-front` 全部 13 个 API 方法（5 查询 + 8 交易）：

| 类别 | Tab | API 路径 | 备注 |
|---|---|---|---|
| 查询 | 账户状态查询 | `POST /query/account-status` | specialData 为空 |
| 查询 | 账户余额查询 | `POST /query/account-balance` | |
| 查询 | 交易状态查询 | `POST /query/transaction-status` | |
| 查询 | 平台交易明细 | `POST /query/platform-transaction-details` | 分页 |
| 查询 | 登记簿明细 | `POST /query/transaction-details` | 分页 |
| 交易 | 转账 | `POST /transaction/transfer` | 需安全确认 |
| 交易 | 消费 | `POST /transaction/consume` | 需安全确认 |
| 交易 | 鉴权转账(平安) | `POST /transaction/transfer-auth` | 需安全确认 |
| 交易 | 授权码发送(平安) | `POST /transaction/resend-transfer-auth-code` | |
| 交易 | 退款 | `POST /transaction/refund` | 需安全确认 |
| 交易 | 提现 | `POST /transaction/withdraw` | 需安全确认 |
| 交易 | 平台付款(中信) | `POST /transaction/platform-pay` | 需安全确认 |
| 交易 | 平台收款(中信) | `POST /transaction/platform-receive` | 需安全确认 |

## 4. UI 使用说明

### 4.1 核心交互流程

1. 每个 Tab 顶部选择**租户** → 联动加载该租户的可用账户列表
2. 选择**账户** → 自动填入该 Tab 的 specialData 字段（账号、名称、银行卡号等）
3. 按业务需要填写/修改其他字段
4. 交易类需勾选**安全开关** + 弹窗二次确认后提交

### 4.2 租户与账户选择

- 每个 Tab **独立选择租户**，互不影响
- 双账户 Tab（转账、消费、鉴权转账、退款、平台付款、平台收款）需分别选择付款方和收款方
- 单账户 Tab（提现、授权码发送及所有查询 Tab）只选一个账户

### 4.3 账户联动特殊字段

各交易类型的 specialData 联动规则如下：

| Tab | specialData key | 来源 | 方向 |
|---|---|---|---|
| transfer / consume | `outAcctNo` | accountNo | 付款方 |
| transfer / consume | `inAcctNo` | accountNo | 收款方 |
| transfer / consume(中信) | `USER_D_NM` | name | 付款方 |
| transfer / consume(中信) | `USER_C_NM` | name | 收款方 |
| refund(中信) | `ORI_USER_D_ID` | accountNo | 付款方(用户确认) |
| refund(中信) | `ORI_USER_D_NM` | name | 付款方 |
| refund(中信) | `ORI_USER_C_ID` | accountNo | 收款方(用户确认) |
| refund(中信) | `ORI_USER_C_NM` | name | 收款方 |
| withdraw(中信) | `acctNo` | accountNo | 账户选择 |
| withdraw(中信) | `outAcctId` | accountNo | 账户选择 |
| withdraw(中信) | `cardNoEnc` | bankCardNo | 账户选择 |
| withdraw(中信) | `nameEnc` / `WITH_ACCNAME` | name | 账户选择 |
| platformPay / platformReceive(中信) | `outAcctNo` / `inAcctNo` | accountNo | 按方向 |
| platformPay / platformReceive(中信) | `outAcctNm` / `inAcctNm` | name | 按方向 |
| platformPay / platformReceive(中信) | `dealType` / `fundTp` | 租户级配置 **只读** | 自动填入 |

### 4.4 平台收付款资金配置（中信）

`dealType` 和 `fundTp` 是**租户级配置**，非账户级。选择付款方/收款方（视方向而定）时自动填入，**只读不可修改**。

对应 `zx_bank_config` 中的 `self_dealType` / `self_fund_type`。

## 5. 测试数据

### 5.1 测试租户配置

数据源：`src/main/resources/application.yml` 的 `catering-web-test.tenants` 段。

**租户 1：LSYM 测试环境**

| 字段 | 值 |
|---|---|
| tenantId | 80001 |
| platformCode | zxegj（中信） |
| selfDealType | 03 |
| selfFundType | 015001 |
| defaultRole | 011002 |
| defaultFundType | 001002 |

账户：
| name | accountNo | storeId |
|---|---|---|
| 四川省杨大爷文化传播有限公司 | J04069400000302 | L01010055 |
| 抽佣组织 | J04069400000297 | 1238912213 |

**租户 2：MDL 测试环境**

| 字段 | 值 |
|---|---|
| tenantId | 80002 |
| platformCode | zxegj（中信） |
| selfDealType | 03 |
| selfFundType | 015001 |
| defaultRole | 015002 |
| defaultFundType | 015002 |

账户：
| name | accountNo | storeId |
|---|---|---|
| 成都哈哈哈科技有限公司 | J04101700000271 | 90197 |
| 宋小 | J04101700000302 | mdlceshi20260701 |

### 5.2 AccountConfig 字段对照

| Java 字段 | YAML key | 说明 |
|---|---|---|
| `name` | `name` | 企业/个人名称 |
| `accountNo` | `account-no` | 中信账户编号（同时也是 outAcctId） |
| `storeId` | `store-id` | 门店ID |
| `storeNo` | `store-no` | 门店编号 |
| `storeName` | `store-name` | 门店名称 |
| `bankCardNo` | `bank-card-no` | 银行卡号（提现用） |

### 5.3 TenantConfig 字段对照

| Java 字段 | YAML key | 说明 | 来源 |
|---|---|---|---|
| `tenantId` | `tenant-id` | 租户ID | 配置系统 |
| `selfDealType` | `self-deal-type` | 自营交易类型(中信) | zx_bank_config |
| `selfFundType` | `self-fund-type` | 自营资金类型(中信) | zx_bank_config |
| `defaultRole` | `default-role` | 默认角色(中信) | zx_bank_config |
| `defaultFundType` | `default-fund-type` | 默认资金类型(中信) | zx_bank_config |

## 6. 架构说明

### 6.1 请求体结构

所有请求统一为两段式：

```json
{
  "baseData": {
    "tenantId": "...",
    "storeId": "...",
    "platformCode": "zxegj",
    "bizSystemCode": "test",
    "bizTransactionType": "TRANSFER",
    "bizTransactionId": "uuid",
    "bizRequestNo": "uuid",
    "bizOrderNo": "...",
    "bizSubOrderNo": "...",
    "amount": 100,
    "fee": 0,
    "currency": "CNY"
  },
  "specialData": {
    "outAcctNo": "...",
    "inAcctNo": "..."
  }
}
```

### 6.2 数据流

```
浏览器 UI (index.html + app.js)
  │ POST 到各 API 路径
  ▼
FrontTestController (@RequestMapping /api/test/front)
  │ FeignClient 代理
  ▼
catering-front (实际业务服务)
  │ 处理并响应
  ▼
浏览器展示 JSON 结果
```

## 7. 后台实现

- `FrontTestController.java`：通过 Feign 注入 `FrontQueryApi` 和 `FrontTransactionApi`，透传请求
- `TenantTestProperties.java`：`@ConfigurationProperties` 绑定 YAML 测试数据
- `CateringWebTestApplication.java`：入口，`@EnableFeignClients` 扫描 `catering-api-front`

### 7.1 业务失败响应的透出（2026-08-14 修复）

Feign 调用 `catering-front` 时，若 front 正常返回但业务失败（HTTP 200 + `R.code != 200`，
如银行拒绝交易），公共 `FeignJsonDecoder` 会按设计把该响应转为 `ServiceException`，
Feign 框架再包装为 `DecodeException` 抛出。

`FrontTestController.callFeign/callFeignTable` 捕获 `FeignException`，沿 cause 链提取
`ServiceException` 的真实消息（如"银行拒绝交易"）返回给浏览器 UI：

- `R` 类型接口：`R.fail(真实消息)`；
- `TableDataInfo` 分页接口：`code=500 + msg=真实消息` 的错误对象。

不捕获时异常会落到公共 `GlobalExceptionHandler` 的 `RuntimeException` 兜底分支，
被吞成 `发生未知异常，请联系管理员`，丢失真实业务失败原因，本修复即为解决该问题。

### 7.2 结构化调用日志（2026-08-14 升级）

web-test 后端调用日志由 `[test] >>>/<<<` 文本样式升级为与 catering-front 交易链路一致的结构化
event JSON（工具类 `com.chinaums.web.test.logging.WebTestLogJsonUtils`），覆盖全部 13 个
测试接口及 `/tenants`。每条日志是合法单行 JSON：

- `test_context_prepared`：RequestContext 装配完成（tenantId/platformCode/dataSourceId）；
- `test_request_sending`：Feign 调用发送前，payload=完整请求体；
- `test_response_received`：调用成功返回，payload=完整响应体，带 `elapsedMs`；
- `test_request_failed`：远程失败，payload=`{exceptionType,message}`，带 `elapsedMs`，保留完整堆栈；
- `test_tenants_loaded`：租户列表加载。

同一次调用三条事件日志共用同一 `traceId`（`test_` 前缀 + UUID），metadata 携带
`tenantId/platformCode/dataSourceId/storeId` 定位字段；字段值按明文输出（与 front 日志口径一致，
2026-08-14 用户确认无掩码）。

### 7.3 账户状态查询缺少 acctNo 的修复（2026-08-14）

`queryAccountStatus`（中信 2058 查询用户状态）协议要求 `specialData.acctNo`（用户编号）必填，
但 web-test 的 acctStatus Tab 此前 `specialData` 恒为空，导致 front 返回
`F100001 specialData.acctNo不能为空`。修复分两层：

1. **前端**：`index.html` acctStatus Tab 新增 `field-acctStatus-acctNo` 输入框（账户选择联动填充）；
   `app.js buildQueryBody` acctStatus 分支改为 `specialData = { acctNo: ... }`；说明文字同步更正。
2. **后端自动补全**：`FrontTestController.setupContext` 在请求 `specialData.acctNo` 缺失时，
   从 `application.yml` 租户配置取**第一个账户**的 `accountNo` 自动补全（用户已选账户时不做覆盖），
   与 `platformCode/dataSourceId` 的补全逻辑一致。

其余查询 Tab（acctBalance/transStatus/transDetail）acctNo 输入与 specialData 填充已齐备，未改动。

## 8. 维护说明

### 8.1 新增测试租户

1. 在 `application.yml` 的 `catering-web-test.tenants` 添加条目
2. 补充账户列表
3. 从 `zx_bank_config`（配置中心）补充租户级别字段

### 8.2 新增测试账户

1. 在已有租户下的 `accounts` 列表添加条目
2. 填写 `name`、`account-no`、`store-id`、`store-no`、`bank-card-no`

### 8.3 新增 API 测试

1. Controller 新增映射方法 + Feign 调用
2. UI 新增 Tab（index.html）
3. JS 补充 `API_PATH`、`getSpecialSchema`、`buildQueryBody`/`buildTransactionBody`、`fillTabSpecialFields` 等

### 8.4 安全机制

- 交易类 Tab 需勾选复选框 → 弹窗确认 → 提交
- 查询类 Tab 无安全限制，直接提交
- 交易类 Tab 每次提交前重新生成 `bizTransactionId`/`bizRequestNo` 防止重复