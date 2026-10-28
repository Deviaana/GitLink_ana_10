# moonl10n 与 moonlocale 的对比及差异化说明

> 结论先行：moonlocale 与 moonl10n 在“跨后端输出本地化字符串”这一基础层确实存在
> 重叠，moonl10n 不把“支持 WASM-GC / JS / Native”本身当作唯一差异。moonl10n 的
> 独立价值在于：把 CLDR 数据版本、格式化语义、结构化结果、失败行为和一致性证据
> 一起做成可审计的契约，面向金额、日期、图表、账单等不能容忍地区差异错误的场景。

## 1. 对比口径

- 对比对象：评审意见中提到的 `zlhahaha/moonlocale` 所代表的跨后端 locale /
  格式化能力。
- 对比范围：只比较“locale 敏感的数值、货币、日期时间和复数选择”这一层；不评价
  消息翻译、语言包管理、UI 集成等更上层的本地化能力。
- 事实边界：moonlocale 仍在演进。本文不逐条假设其缺少某项 API，也不把“对方没有”
  当作差异依据；下表使用“重叠 / 增量”描述能力层次。moonlocale 的具体能力以其最新
  仓库文档为准。
- 对比结论：即使 moonlocale 覆盖基础格式化，moonl10n 仍以第 3 节列出的增量构成
  独立价值；这些增量都可以在本仓库中直接核验。

## 2. 重叠面：不回避基础能力重叠

以下能力不应被包装成 moonl10n 的独占优势：

- 两者都面向 MoonBit 的多后端场景，都能在非浏览器环境中输出本地化字符串。
- 两者都可能提供数字、日期或货币等常见格式化入口。
- 两者都把跨后端可用性作为目标之一。

因此，仅凭“有跨后端格式化”无法判断两个项目是否重复。真正需要比较的是：格式化
结果是否可验证、数据是否可追溯、错误是否可发现，以及 API 是否适合被其他库组合。

## 3. 差异化矩阵

| 能力层次 | 与 moonlocale 的关系 | moonl10n 的具体做法 | 仓库内证据 |
| --- | --- | --- | --- |
| 问题定位 | 基础格式化层重叠 | 收窄为“CLDR 48 子集格式化内核”，不承担通用翻译框架职责 | `docs/conformance.md` 第 3 节 |
| 数据契约 | 不以对方缺失为前提 | 固定 CLDR 48 / UTS #35 revision 48、6 个内置区域、`latn`、Gregorian；版本变化必须同步数据、测试和文档 | `tools/cldr-baseline.json`、`docs/conformance.md` 第 2、4 节 |
| 数据交付 | 独立实现 | 抓取、裁剪、去重后生成 MoonBit 常量并提交到仓库；运行时不读 JSON、不做文件 IO、不依赖 FFI | `data/generated.mbt`、`tools/fetch-cldr.mjs`、`tools/gen-cldr.mjs` |
| 一致性证据 | 独立增量 | 178 条由 Node 24.13.0 / ICU 77.1 生成的静态差分断言；总计 255 项测试；WASM-GC、JS、Native 三后端 CI | `conformance/intl_conformance_wbtest.mbt`、`.github/workflows/ci.yml` |
| 结构化结果 | 独立增量 | `NumberFormatResult` 同时返回渲染文本和实际使用的整数/小数位，复数选择可直接复用这些位数，避免“显示 1.00 却按 1 选复数” | `number/format.mbt`、`plural/eval.mbt`、`relative/format.mbt` |
| 格式语义 | 深度增量 | 负数子模式、accounting、ISO 4217 小数位、货币间距与窄符号、紧凑记数复数覆盖、日期区间 fallback、引号字面量、`¤` 占位符 | `number/format.mbt`、`datetime/format.mbt`、`plural/eval.mbt` |
| 失败语义 | 独立增量 | 严格解析用 `try_parse`，支持的 locale 回退有明确顺序；不支持的日期字段可用 `Skip` / `Preserve` / `Reject` 显式处理，不会伪造时区结果 | `core/locale.mbt`、`datetime/format.mbt` |
| 可审计性 | 独立增量 | 明确声明支持面和排除项，不用“完整 CLDR”描述当前版本；版本升级有固定步骤和机器校验 | `docs/conformance.md` 第 3.5、4 节、`tools/check-conformance.mjs` |

## 4. 关键差异

### 4.1 跨后端只能证明“一致”，不能证明“正确”

同一套错误规则在三个后端上运行，也会得到“跨后端一致”的错误结果。moonl10n 因此
不只做三后端测试，还把 ICU 77.1 的输出固化为 178 条静态差分断言：

- 断言由 Node 24.13.0 / ICU 77.1 生成，生成后提交到仓库，CI 运行时不需要 Node.js
  参与格式化。
- 断言覆盖 6 个区域，包含十进制与负数、百分号、货币符号/代码/名称/窄符号、
  accounting、日期、时间、相对日/小时、科学计数法、紧凑记数、基数复数和可见
  小数位。
- `tools/check-conformance.mjs` 还会校验文档、生成数据和测试头信息与
  `tools/cldr-baseline.json` 一致，防止“只改一句文档就宣称升级 CLDR”。

这部分工作的价值不在 API 数量，而在于它把“格式化正确”变成了可重复执行的验收
条件。对于金额、账期、图表坐标轴等场景，这比多一个格式化函数更重要。

### 4.2 结构化结果让数字格式化与复数选择不再脱节

很多 i18n API 只返回字符串，调用方若还要选复数，只能重新解析已经格式化后的文本，
容易在 `1` 与 `1.00`、分组符号、负数符号上出错。moonl10n 的
`format_decimal_result` 同时返回文本和实际使用的位数：

```moonbit
let locale = @core.Locale::parse("en")
let options = @number.NumberOptions::default().with_fraction_digits(2, 2)
let result = @number.format_decimal_result(1.0, locale, options=options)

// result.text            == "1.00"
// result.integer_digits  == "1"
// result.fraction_digits == "00"

let rules = @plural.PluralRules::cached("en")
rules.select_with_digits(result.integer_digits, result.fraction_digits)
// "other"：因为可见小数位是 2，而不是把 1.00 当成 1
```

这不是“多一个返回值”，而是把数字格式化、复数规则和相对时间组合成一条不会丢失
语义的链路。`relative/format.mbt` 也直接使用同一套结构化结果，而不是先格式化再
反解析。

### 4.3 数据与边界可追溯，而不是黑盒移植

moonl10n 的 CLDR 数据不是运行时从宿主读取，也不是通过 FFI 调用 ICU：

- `tools/fetch-cldr.mjs` 按固定 ref 抓取 CLDR JSON，并检查 supplemental 数据的
  `_cldrVersion`。
- `tools/gen-cldr.mjs` 裁剪、去重后生成 `data/generated.mbt`，生成器最后执行
  `moon fmt`；生成代码已经提交，使用者不需要 Node.js。
- 生成后的数据约 37 KB，运行时无文件 IO、无网络、无 FFI。
- `docs/conformance.md` 明确列出支持面之外的时区、非 Gregorian 日历、非 `latn`
  数字系统、单位、消息格式等排除项；不支持的日期字段可以通过 `Reject` 被显式
  发现，而不是静默产生错误结果。

因此，即使其他库也能输出相似字符串，moonl10n 仍提供了“数据从哪来、如何生成、
哪些结果被承诺、出错时怎么办”的完整链路。这一层是格式化内核最难被表面功能替代
的部分，也是本项目继续迭代的基础。

### 4.4 这些差异是否足以构成独立项目

可以用三个问题检验：

1. 能否只靠配置或适配层补上？结构化结果、无 IO 的数据交付和 178 条差分断言都需要
   独立的代码与数据管线，不能通过改调用方式获得。
2. 是否影响下游正确性？是。accounting、ISO 4217 小数位、货币间距、复数操作数中的
   可见小数位等错误会直接进入账单、图表和界面。
3. 是否有持续维护价值？是。CLDR 版本升级需要重新抓取、生成、差分和文档同步，
   这是一条长期存在的基础设施工作。

因此，moonl10n 与 moonlocale 的重叠主要在“调用入口”，差异在“数据、验收和 API
契约”。这也是建议保留本项目的原因。

## 5. 与 moonlocale 的关系是互补而非替代

在生态分工上，两者可以形成互补：若应用已经使用 moonlocale 管理语言包、翻译资源
或界面语言切换，可以继续由它负责这一层；moonl10n 则作为其下方的数值与日期格式化
内核：

- 需要金额、日期、百分比、相对时间或复数选择时，调用 moonl10n 的结构化 API；
- 两者在同一应用中同时存在时，还可以用独立实现做差分测试，反而提高 MoonBit
  生态 i18n 结果的可靠性。

本项目不主张“所有 locale 功能都应该由 moonl10n 重做”，也不以 moonlocale 的能力
缺失作为立项理由。差异来自不同的验收标准和问题层次：通用 locale 库侧重“应用如何
接入本地化”，moonl10n 解决“本地化数值和日期结果如何被证明正确、如何被其他库
安全组合”。

如果需求只是把少量数字或日期转成本地字符串，使用更小的库可能已经足够；
moonl10n 面向的是需要固定 CLDR 基线、可重复验收和可组合 API 的基础设施场景。
这也是它值得作为独立项目继续维护的原因：它提供的是一层可被其他库依赖的契约，
而不是再包装一个格式化入口。

## 6. 可核验证据

以下命令均可在仓库根目录直接执行：

```bash
moon test
moon test --target js
moon test --target native
node tools/gen-intl-fixtures.mjs --check
node tools/check-conformance.mjs
```

当前基线：

- `moon test`：255 项测试全部通过，其中 178 项为 Intl 差分断言。
- 数据基线：CLDR 48 / UTS #35 revision 48，6 个区域、`latn`、Gregorian。
- 后端矩阵：`wasm-gc`、`js`、`native`，见 `.github/workflows/ci.yml`。
- 数据交付：生成代码已提交，运行时零 IO、零 FFI；数据约 37 KB。

## 7. 可直接用于申诉 / 补充材料的表述

> 评审意见提到 moonlocale 已支持跨后端格式化。我们确认两者在基础输出层存在重叠，
> 因此不再以“跨后端”作为唯一差异点。moonl10n 的定位是 CLDR 子集格式化内核：
> 它以固定版本的 CLDR 数据为契约，提供可复现的数据生成管线、结构化格式化结果、
> 显式失败策略和 178 条 ICU 差分断言，并用 WASM-GC / JS / Native 三后端 CI 验证
> 结果一致。与 moonlocale 相比，moonl10n 不追求覆盖所有本地化功能，而是解决
> “金额、日期、图表和账单等场景的格式化结果如何被验收、追溯和组合”的问题。
> 这些差异均可通过仓库中的 `docs/conformance.md`、`tools/` 和 `conformance/`
> 直接复核，建议保留本项目作为 MoonBit 数值/日期格式化基础设施的独立实现。