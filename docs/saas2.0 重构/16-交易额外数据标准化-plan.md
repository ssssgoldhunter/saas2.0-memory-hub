# 交易额外数据标准化执行计划

> 前置阅读：[15-交易额外数据标准化-spec.md](15-交易额外数据标准化-spec.md)（契约与矩阵的唯一事实来源，本计划只排顺序，不重复定义）
> 2026-08-17 架构定稿：组装 = catering-api-front 实例工具类（本地调用，front 服务零改动）；consume 侧 check 按能力维度
> 纪律：用户明确本次**不编译、不跑测试、不新增 JUnit**；验证 = api-front 已编译 install 一次（已做）+ web-test 人工两步调用

## 实施记录（2026-08-17）

### 已完成

1. **Phase 1 api-front 组装工具类（已完成，编译验证通过并 install 至 /tmp/mdl-m2）**
   - 新增 `com/chinaums/front/api/assemble/FrontSpecialDataAssembler.java`（单文件）：
     大对象 + 嵌套 AccountInfo/BankCard/Auth + newPay/newRec/newOriPay/newOriRec/newAuth/newBankCard
     工厂方法 + `assemble()` 实例入口 + CiticSpecialDataAssembler/PingAnSpecialDataAssembler 两个私有内部类；
   - 能力映射 12 个（中信 6 + 平安 6 含平安退款空实现），键全走 `*ContractKeys`，
     originalBusinessDate 做 yyyyMMdd 严格校验；全实例方法零 static；
   - `AuthTransferBusinessData` 改名**暂缓**（涉及 front 服务 7 处，违反零改动，独立清理项）。

2. **Phase 2 consume 侧组装 check 骨架（已完成，buildRequest 为 TODO 占位）**
   - 新增 `consume/flow/component/base/specialdata/`：基类 `SpecialDataAssembleCheck<S>`（模板：
     getFirstContextBean 取 slot → new 工具 → set capability/platformCode(RequestContext) →
     buildRequest → assemble → writeBack → 失败终止）+ 7 个子类：
     Consume/Refund/Transfer/TransferAuth/TransferAuthCodeResend（consume 树 slot）+
     Withdraw/Deduction（fund 树 slot，Deduction 能力=TRANSFER）；
   - 两个 `TransSlot`（consume 树 + fund 树）各加 `assembledSpecialData`（JSONObject）；
   - **未挂链**：老树银行组件 stub 待适配、fund 树在线走旧 FacadeApi，挂 TODO-抛异常 check 会中断在线链；
     挂接随各链 front 新 API 适配进行（挂接点表见 15 号 §7）；
   - 基类取 slot 用 `this.getFirstContextBean()`（对齐 ConsumeTrans04/PlatformInfoCheck 现有写法，
     LiteFlow 2.12.1 无 getSlotBean(Class) API——已纠正）。

### 存量障碍（非本次范围，已报用户，待另行修复）

- consume 全模块编译不可用：`com.chinaums.report.{api,request,response}.catering` 包缺失、
  `BaseMerchantFacadeApi`（com.chinaums.base.api）缺失、
  `catering-api-front/.../BasTransWithDrawRes.java` 被置空（fund TransSlot 引用）；
  consume/fund 双 TransSlot 结构为存量代码问题（用户 2026-08-17 知悉，次日安排人纠正）；
- 新增 check 文件的编译验证随存量修复后补做（定点 javac 曾暴露并已修复 getSlotBean 一处真实缺陷）。

## 待办 Phase

### Phase 3 web-test 两步调用（未开始）

1. `FrontTestController` 新增 `POST /api/test/front/assemble/special-data`：入参反序列化为
   `FrontSpecialDataAssembler`（BaseRequest 4 参数自动注入），调 `assemble()` 返回 specialData；
2. `static/js/app.js` + `static/index.html`：账户下拉产出标准结构（accountNo→bankEAccountId、
   name→bankAccountName、bankCardNo→pay.bankCard.bankCardNo；平台付款只填 rec、平台收款只填 pay、
   提现填 pay+bankCard、退款填 oriPay/oriRec+originalBusinessDate、鉴权填 auth、平台收付 contractId 选填）；
   交易 Tab 两步：先组装展示 → 注入交易请求 → 发交易；查询 Tab 不变；
3. web-test 编译 + 启动冒烟（需用户当次授权编译）。

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
