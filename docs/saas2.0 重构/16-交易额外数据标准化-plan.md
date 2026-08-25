# 交易额外数据标准化执行计划

> 前置阅读：[15-交易额外数据标准化-spec.md](15-交易额外数据标准化-spec.md)（契约与矩阵的唯一事实来源，本计划只排顺序，不重复定义）
> 2026-08-17 架构定稿：组装 = catering-api-front 实例工具类（本地调用，front 服务零改动）；consume 侧 check 按能力维度
> 纪律：用户明确本次**不编译、不跑测试、不新增 JUnit**；验证 = api-front 已编译 install 一次（已做）+ web-test 人工两步调用
>
> 2026-08-19 口径更新：下文“平安退款空实现”仅是 2026-08-17 的历史实施记录；当前最终设计以
> TODO-002 为准——业务系统不提供原渠道字段，Front 按原业务主子流水查询原渠道表。

## 实施记录（2026-08-17）

### 已完成（已提交推送 origin/limeng_front：d5dd39ca 工具类 / 32d4b380 consume check / 96fb145b web-test；2026-08-17 用户确认提交）

1. **Phase 1 api-front 组装工具类（已完成，编译验证通过并 install 至 /tmp/mdl-m2；后续工厂化重构与证件预留未再编译，待授权随模块编译）**
   - 新增 `com/chinaums/front/api/assemble/FrontSpecialDataAssembler.java`（单文件）：
     大对象 + 嵌套 AccountInfo/BankCard/Auth + newPay/newRec/newOriPay/newOriRec/newAuth/newBankCard
     工厂方法 + `assemble()` 实例入口 + CiticSpecialDataAssembler/PingAnSpecialDataAssembler 两个私有内部类；
   - 当时能力映射 12 个（中信 6 + 平安 6，平安退款当时为空实现；当前已由 TODO-002 覆盖），键全走 `*ContractKeys`，
     originalBusinessDate 做 yyyyMMdd 严格校验；全实例方法零 static；
   - 2026-08-17 晚按用户要求重构为**工厂模式**：银行组装逻辑从主类私有内部类拆为同包独立类
     （`BankSpecialDataAssembler` 接口 + `CiticSpecialDataAssembler` + `PingAnSpecialDataAssembler`，
     package-private、非 Spring Bean），主类 `assemble()` → `bankAssembler()` 工厂按
     platformCode→BankCode 创建银行类、银行类内 switch capability，(bank × capability) 两级寻址；
     校验辅助方法降为包内可见供银行类复用。web-test/consume 调用方零影响（重编译即可）；
   - 标准结构 AccountInfo 增加 `certNo`/`certType` **通用预留字段**（2026-08-17 用户确认：
     平安场景可能需要、目前不组装上送；激活 = 对应银行组装器加"有则输出" + 15 号矩阵补行；
     13 号 §4.6 提现 specialData 表已按 Handle 实际必填集修正——中信 3 键、平安 5 键 + certNo 选填）；
   - `AuthTransferBusinessData` 改名**暂缓**（涉及 front 服务 7 处，违反零改动，独立清理项）。

2. **Phase 2 consume 侧组装 check 骨架（已完成，buildRequest 为 TODO 占位）**
   - 新增 `consume/flow/component/base/specialdata/`：基类 `SpecialDataAssembleCheck<S>`（模板：
     getFirstContextBean 取 slot → new 工具 → set capability/platformCode(RequestContext) →
     buildRequest → assemble → writeBack → 失败终止）+ 7 个子类：
     Consume/Refund/Transfer/TransferAuth/TransferAuthCodeResend（consume 树 slot）+
     Withdraw/Deduction（fund 树 slot，Deduction 能力=TRANSFER）；
   - 两个 `TransSlot`（consume 树 + fund 树）各加 `assembledSpecialData`（JSONObject）；
   - **未挂链**：老树银行组件 stub 待适配；挂接随各链 front 新 API 适配进行（挂接点表见 15 号 §7）；
   - **2026-08 master 合并后调整**：划付代码迁移删除整个 fund 包（-17253 行），fund slot 删除、
     slot 统一为 consume 树；withdraw/deduction 两个 check 已重指向 consume TransSlot（已改未提交）；
     chainWithDraw 清空、chainDeduction 仍引用已删组件（存量雷，报用户处理）；
     front 侧合并为纯加法（划付文件处理 46 文件 +3177 行，SaasZxInterService 为注释体），
     交易链/ContractKeys/Handle 零改动，15 号设计前提不变；
   - 基类取 slot 用 `this.getFirstContextBean()`（对齐 ConsumeTrans04/PlatformInfoCheck 现有写法，
     LiteFlow 2.12.1 无 getSlotBean(Class) API——已纠正）。

### 存量障碍（非本次范围，已报用户，待另行修复）

- consume 全模块编译不可用：`com.chinaums.report.{api,request,response}.catering` 包缺失、
  `BaseMerchantFacadeApi`（com.chinaums.base.api）缺失、
  `catering-api-front/.../BasTransWithDrawRes.java` 被置空（fund TransSlot 引用）；
  consume/fund 双 TransSlot 结构为存量代码问题（用户 2026-08-17 知悉，次日安排人纠正）；
- 新增 check 文件的编译验证随存量修复后补做（定点 javac 曾暴露并已修复 getSlotBean 一处真实缺陷）。

## 交易状态查询三件套（2026-08-17 用户裁决后实施，未提交）

1. api-front：新增 `FrontInternalTransStatus`（S/P/F 常量）；`TransStatusResult.frontStatus`
   改 String 三态（null=未知）；组装工具两银行类加 TRANS_STATUS_QUERY 分支（矩阵 §4.3）；
2. front：Citic/PingAn QueryHandle 的 mapTransStatus 改内部三态，银行状态码全部提为带注释常量
   （中信 00~05、平安 0/1/2/5/6），04/05→S、空/未知→null（用户确认）；PingAnQueryHandle
   .queryTransactionStatus 正式实现（02/03 规则、frontSsn 必填、mchntMbrId←specialData、
   acctNo←账户配置 SM2，lsym 生产依据，联调待验）；
3. web-test：交易状态查询 Tab 接组装端点（两步），新增 frontSsn 输入（平安必填），
   acctNo 输入降级为回退手填。

## 交易状态查询二次修订（2026-08-17 晚，用户裁决，未提交）

- **银行请求合并**：新增跨银行统一报文 `channel/protocol/QueryTransStatusRequest`，中信/平安
  状态查询 Handle 均改用之（invokeQuery 参数放宽为 Object——内部仅 toJSONString）；
  删除 CiticQueryTransStatusRequest，PingAnQueryRequest 移除状态查询专用字段；
- **提现卡号渠道表回查（用户指出）**：平安提现状态查询（03）专用 cardNoEnc 从
  `FrontPinganWithdrawTransaction` 按 (tenantId, frontSsn) 回查发起时银行卡号后 SM2 上送，
  不经调用方；组装工具平安查询格回到 1 要素（mchntMbrId）；
- RECHARGE 仅平安（04）接入，中信 default 拒绝；
- **统一请求五点修正（用户评审，定稿）**：QueryTransStatusRequest 改为银行无关——只含定位
  基础参数（capability/transDate/主子订单号/frontSsn，不带 original 前缀——用户要求）+ 组装 specialData（from(context) 工厂）；
  信封字段全部移出请求，各 Handle 以常量+账户配置+序列生成器直接构建 wire JSONObject
  （键走 FrontBankRequestConstants，新增 3 个常量）；bizFunc/chnlNo 配置死在 Handle，
  transSsn/laasSsn 为 Handle 生成能力，tenantId/mchntId 走账户配置。

## 交易状态查询收盘状态（2026-08-18；代码已提交推送：b41d885e/da4e833c/3260241a/a58c33d8；编译已于 2026-08-19 验证通过，当时失败仅为本地仓库旧 jar，install 后四模块绿）

- 统一请求最终形态：`QueryTransStatusRequest(context)` 实例构造，字段 capability/transDate/
  bizOrderNo/bizSubOrderNo/frontSsn/specialData（无 original 前缀、无 static）；
- 对外契约同步去前缀（TransStatusQueryData + FrontQueryApi + 两 Handle 报错 + web-test + 05/10/13）；
- PingAnQueryRequest 加 TODO[QUERY-UNIFY] 过渡标记（查询统一路线，迁完删除）；
- 修复 buildTransStatusWire 泛型通配符编译错误（context 参数改为具体类型）；
- `bankEAccountId→cardNoEnc` 疑问结案（用户裁决）：系 lsym 99 验证码路径填法，交易状态查询用不到，
  现状（提现查渠道表 bankCardNo）维持；
- **遗留**：整批代码未编译未提交（用户已知）；中信退款 TRANS_TYPE=01 待协议核对；
  4 个查询能力迁移统一模式待启动；consume 存量修复进行中。

> 2026-08-19 现状更正：两类明细已完成迁移；账户状态/余额按用户裁决固定保留
> `ADAPTER_NOT_READY` 挡板，不再属于待迁移能力。`PingAnQueryRequest` 仅作为挡板后历史草稿保留，
> 上述 `TODO[QUERY-UNIFY]` 按该裁决关闭。

## 划付死链清除 + 钱包网关公共化（2026-08-18 用户裁决，未提交）

- **删除划付迁移死代码 11 文件**（4 个全注释体 SaasZxInterService/SaasTemplateUtils/
  FileProcessServiceImpl/ZxFileProcessHandle + 5 个空骨架 FileProcessService/Router/
  BasFileProcessHandle/AbstractFileProcessHandle/FrontFileProcessFacadeController +
  api-front 的 FrontFileProcessFacadeApi/SaasZxApi；其中 5 个为用户先手暂存删除，6 个补删）；
  划付/账户接口将来按网关 SOP 重新实现；
- **钱包发送公共化**：新增 `channel/gateway/`（BankWalletGateway/BankWalletSender/
  RoutingBankWalletGateway，重复注册启动失败）；两个 HttpClient implements BankWalletSender
  （bankCode + 从账户配置取连接参数的重载）；四个 Handle 全部切换 `walletGateway.post(bank,…)`，
  模块内零 httpClient 直连；05 号已写入 SOP 与红线。

## 待办 Phase

### Phase 3 web-test 两步调用（2026-08-17 已完成，编译/冒烟待用户授权后补）

1. ✅ `FrontTestController` 新增 `POST /api/test/front/assemble/special-data`：入参反序列化为
   `FrontSpecialDataAssembler`（platformCode 缺省按 tenantId 从租户配置补全，RequestContext 写入），
   本地调 `assemble()` 返回 `R<JSONObject>`；`FrontException` 转 `R.fail(msg)`；日志只记协议键名（脱敏）；
2. ✅ `app.js`/`index.html`（index 结构未动）：交易 Tab 的协议键 schema（getSpecialSchema）整体替换为
   标准结构 schema（getStandardSchema，std-* 输入：pay/rec/oriPay/oriRec 组 + bankCard 卡要素 +
   auth 鉴权组 + originalBusinessDate/contractId）；账户下拉联动填标准字段（accountNo→bankEAccountId、
   name→bankAccountName、bankCardNo→卡号；bankEMemberCode/cardHolderName 手填或租户配置扩展带出）；
   `execTab` 改两步：先 POST 组装端点（失败即终止）→ 组装结果 specialData 原样带入交易请求 →
   确认弹窗（参数行 + 组装结果 + 完整报文）后发送；resendAuth 同样两步但维持无弹窗直发；
   门店 payStoreNo/recStoreNo 改为直接取所选账户（平台收付固定侧取租户第一账户），
   dealType/fundTp 不再经 specialData 上送（租户级配置由 front 侧联动，红线不允许调用方覆盖）；
3. ✅ 查询 Tab 协议键直传维持不变；`buildBody/collectSpecial/fillPlatformFixedSide` 等旧函数清除；
   14 号使用说明 §4.1/§4.2/§4.3/§4.4/§6.2 已同步。

### Phase 4 buildRequest 补实（依赖账户体系按 storeNo 定型）

- 7 个 check 的 buildRequest 从 TODO 占位替换为真实收集：
  pay/rec ← slot.compayInfoMaps、bankCard ← basBankInfoMap、auth ← 授权签发结果+用户输入、
  originalBusinessDate ← 原交易日期；
- 同期进行各链 front 新 API 适配时按 15 号 §7 挂接点表挂 check（ConsumeTrans04 等）。

### Phase 5 文档同步（按 15 号 §9 清单）

13（工具类登记）、05（组装工具类章节 + 双层口径）、06/07/08（头部加注指向 15 号）、
14（web-test 两步说明）、WIKI-START（如需微调）。15/16 号本体已于 2026-08-17 更新到位。

### Phase 6 终验（15 号 §11 全量自检 + 执行报告）

## 回滚策略

api-front 工具类纯新增可整体 revert；consume 侧为纯新增包 + 2 个 slot 字段，revert 不影响存量行为；
front 服务零改动，不存在行为切换点。web-test 改造独立 revert。

## 收盘记录（2026-08-19，明细契约重构与平安启用，17/18 号 spec/plan 执行完毕）

- 执行路径：执行 AI 完成 T1 主体（新 DTO/枚举/QueryData 拆分/TableDataInfo+FrontPageResult 处置/
  三层签名）后由主对话接手收尾：中信拆强转桥+remark 来源修正+GOAC/OANM 常量化、平安 6073/6050/6048
  三模板实现（PingAnDetailQueryContractKeys 新建）、移除明细两挡板、web-test 下拉收窄、文档联动；
- 已确认：6073 `frontSeqNo = 原提现应答 queryId = front_pingan_withdraw_transaction.bank_query_id`，
  按 `tenantId + bank_query_id` 回查；`bank_user_ssn` 独立保存银行返回的用户流水，不参与6073回查。
  平安单笔状态查询使用原请求 `front_ssn → oriTransSsn`，两条链路不得互换；
- 遗留（后续增强）：25 userName（6048）查表补全；中信 totalNum=TOTAL_PAGE×页大小估算联调后可改置空。

## 收盘记录（2026-08-21，平安授权转账接口改造，25/26/27 号 spec/plan 执行）

- 25 号 spec（语义键 + AuthType + 出参公用化 + §3A 查重）与 26 号 plan（T1-T16）已实施完毕，
  代码仓 `limeng_front` 未提交（待用户 review 确认）；本文档随 15 号 spec 同步更新；
- 组装器变更：`FrontSpecialDataAssembler.Auth` 增加 `authType`（AuthType 枚举，SMS 本期/APP 预留，
  组装必填校验 SMS，非 SMS 拒绝 INVALID_REQUEST）；`PingAnSpecialDataAssembler.transferAuth()`
  输出 9 个对外语义键（payMemberCode/recMemberCode/payAccountNo/recAccountNo/payName/recName/
  authType/authOrderNo/authCode）；`transferAuthCodeResend()` 输出 3 个语义键（payMemberCode/
  payAccountNo/recAccountNo），authType 仅组装入参校验、不进 wire；transfer/consume 会员键
  `outAcctId/inAcctId → payMemberCode/recMemberCode`（不含兼容别名）；
- 矩阵同步：15 号 §4.2 平安 TRANSFER/CONSUME/TRANSFER_AUTH/TRANSFER_AUTH_CODE_RESEND 四格已更新
  （语义键 + Handle 内部协议键映射注记）；07 号契约已按 25 号重写；
- web-test 组装两步调用已适配：transferAuth/resendAuth Tab 增加 authType 输入（默认 SMS），
  组装入参 `auth.authType` 自动带出；resendAuth 响应展示 authOrderNo/authType（无 smsIdx 硬编码）。

## 28 号结构简化尝试（2026-08-25，已放弃）

> 状态：historical / rejected。下列结论只记录为何放弃，不代表当前代码完成状态，也不得作为续写基线。

- 未提交尝试虽然覆盖全量能力，但结构仍不符合当前定稿，不能继续使用；
- 该尝试仍存在 `BankSupport` God class、能力代码内部多层 helper、银行包拍平后脱离
  `com.chinaums.front` 根包等问题，没有达到“参考 consume/旧 Front 顺序式阅读”的目标；
- 当时的编译和测试报告早于最后一轮包移动，不能证明最终工作区状态，本记录不再声明编译或测试通过；
- 当前通用能力实现数应按真实注册和源码核对，禁止继续引用“23 个能力类”这一错误计数；
- 新目标设计及唯一实施范围见
  [28-cateringfront结构简化改造方案](28-cateringfront结构简化改造方案.md)。下一位 AI 必须从已提交代码基线重新开始，
  按 28/29 号从已提交 HEAD 重新全量迁移；清理未提交代码属于破坏性操作，需用户另行确认。
