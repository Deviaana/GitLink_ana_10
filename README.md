# moonl10n

纯 MoonBit 实现、基于 Unicode CLDR 数据的本地化格式化内核。

`moonl10n` 把 `(locale, value, options)` 转换为符合区域习惯的字符串，不依赖
JavaScript 宿主的 `Intl`。项目面向 WASM-GC、JS 与 Native 后端，格式化规则由库内
数据决定，不依赖运行时环境提供国际化能力。

> **版本与符合性基线：CLDR 48 / UTS #35 revision 48。**
>
> 项目声明的是封闭范围内的“CLDR 48 子集符合性”，不是 UTS #35 全量实现或 CLDR
> 官方全量一致性认证。完整终点、支持字段和排除项见
> [`docs/conformance.md`](docs/conformance.md)。

| 区域 | 数字 | 货币 | 日期 | 相对时间 |
| --- | --- | --- | --- | --- |
| `en` | 1,234,567.891 | $1,234.50 | Oct 18, 2026 | 3 days ago |
| `zh` | 1,234,567.891 | US$1,234.50 | 2026年10月18日 | 3天前 |
| `de` | 1.234.567,891 | 1.234,50 $ | 18.10.2026 | vor 3 Tagen |
| `ja` | 1,234,567.891 | $1,234.50 | 2026/10/18 | 3 日前 |
| `fr` | 1 234 567,891 | 1 234,50 $US | 18 oct. 2026 | il y a 3 jours |

## 为什么需要 moonl10n

MoonBit 现有的 i18n 工作主要解决消息目录（MF2）问题，数字、日期、货币和复数的
最终渲染仍然经常交给宿主 `Intl`。这种方式在浏览器里可以使用，但编译到 Native、
WASM-GC 或嵌入式环境后，宿主兜底不再存在，应用会突然失去格式化能力。

`moonl10n` 补上的正是这一层：

- 纯函数 API，不进行 IO，不依赖 FFI。
- 以 Unicode CLDR 数据作为唯一事实来源。
- 同一套规则在 WASM-GC、JS 和 Native 后端保持一致。
- 可被图表、文档排版、UI 组件、日志系统、账单和后台服务复用。

MoonBit 已有 `moonlocale` 等跨后端 locale 库，基础格式化能力存在重叠。
`moonl10n` 不把“跨后端”本身当作差异，而是把 CLDR 数据契约、可复现生成、
结构化结果和可机器验证的一致性作为核心：即使其他库也能输出本地化字符串，
`moonl10n` 仍能回答“结果是否与固定 CLDR 基线一致、数据从哪来、出错时如何显式
失败”。完整对比与证据见
[`docs/moonlocale-comparison.md`](docs/moonlocale-comparison.md)。

## 当前能力

项目当前处于早期 alpha 阶段，核心链路已经实现并通过测试。

| 能力 | 状态 | 说明 |
| --- | --- | --- |
| Locale 解析 | 已实现 | BCP 47 子集、严格校验、variants/extensions、likely subtags、Accept-Language 协商 |
| 十进制数字 | 已实现 | CLDR 模式、分组、`0/#` 固定位、`@` 有效位、`1-9` 增量舍入、科学计数法 |
| 货币格式化 | 已实现 | symbol/code/name/narrow 显示、accounting 模式、ISO 4217 小数位 |
| 百分比 | 已实现 | CLDR 百分比模式与本地化百分号 |
| 复数规则 | 已实现 | 基数与序数规则、CLDR 规则语法解析与求值 |
| 日期与时间 | 已实现 | CLDR 风格、显式模式、日期区间、保留字面空格 |
| 相对时间 | 已实现 | 过去/未来/当前，支持复数变化 |
| 紧凑记数 | 已实现 | `1.2K`、`1.2万`、`1,2 Mio.` 等短格式 |
| 符合性声明 | 已固定 | CLDR 48 / UTS #35 revision 48；6 个区域、`latn`、Gregorian |
| Intl 差分测试 | 已实现 | 6 个区域、178 条静态差分用例 |
| 工程化 | 已实现 | 三后端 CI、覆盖率、可执行示例、标签发布流程 |
| 内置区域 | `en`、`zh`、`de`、`ja`、`fr`、`ar` | 当前使用 `latn` 数字系统和 Gregorian 日历 |
| 时区 | 暂未实现 | `z` 字段支持跳过、保留或报错策略 |
| 非公历日历 | 暂未实现 | 当前使用 Gregorian 日历 |

## 快速开始

```moonbit
let locale = @core.Locale::parse("de")

@number.format_decimal(1234567.891, locale)           // 1.234.567,891
@number.format_currency(1234.5, "EUR", locale)        // 1.234,50 €
@number.format_percent(0.125, locale)                 // 13 %
@number.format_compact(1234567.0, locale)             // 1,2 Mio.
@number.format_scientific(1234567.0, locale)          // 1,235E6
@number.format_with_pattern(12.5, locale, "0.0 'kg'") // 12,5 kg

let date = @datetime.DateTime::new(2026, 10, 18, hour=17, minute=42)
@datetime.format_date(date, locale)                   // 18.10.2026
@datetime.format_time(date, locale)                   // 17:42
@datetime.format_pattern(date, locale, "EEEE, d. MMMM y")

let end = @datetime.DateTime::new(2026, 10, 20)
@datetime.format_date_range(date, end, locale)
// 18.10.2026 - 20.10.2026

@datetime.format_pattern_with_policy(
  date, locale, "yyyy-MM-dd z", @datetime.Reject,
)
// Err(UnsupportedField('z'))

let rules = @plural.PluralRules::cached("ar")
rules.select(3.0)                                     // few

@relative.format_relative(-3.0, @relative.Day, locale) // vor 3 Tagen
```

显式模式会保留字面空格，包括首尾空格。默认情况下，不支持的字段会被跳过；
`format_pattern_with_policy` 和 `format_time_with_policy` 提供 `Skip`、
`Preserve`、`Reject` 三种策略。

## Locale 解析与协商

`try_parse` 执行严格校验，`parse` 保持尽力解析的兼容行为：

```moonbit
@core.Locale::try_parse("de-abc")                       // None
@core.Locale::parse("de-abc").to_tag()                  // de
@core.Locale::parse("sl-rozaj-biske-1994").to_tag()     // sl-rozaj-biske-1994
@core.Locale::parse("zh-HK").maximize().to_tag()        // zh-Hant-HK

let available = [
  @core.Locale::parse("en"),
  @core.Locale::parse("zh-Hans"),
  @core.Locale::parse("zh-Hant"),
]
@core.Locale::negotiate("zh-HK, en;q=0.8", available)   // Some(zh-Hant)
```

严格解析器覆盖语言、书写系统、地区、variants、extensions 和 private-use
区段。Extlang 与 grandfathered 标签会被拒绝，而不是被猜测成其他区域。内置的
likely-subtag 表覆盖项目内置区域及常见语言。

## 数字选项

```moonbit
let en = @core.Locale::parse("en")
let money = @number.NumberOptions::with_fraction_digits(2, 2)
@number.format_decimal(1.0, locale, options=money)     // 1,00

let plain = @number.NumberOptions::default().without_grouping()
@number.format_decimal(1234567.0, locale, options=plain)

@number.format_with_pattern(1.0, en, "@@@")             // 1.00（3 位有效位）
@number.format_with_pattern(0.12345, en, "@@##")        // 0.1235（2-4 位有效位）
@number.format_with_pattern(1.22, en, "0.05")           // 1.20（按 0.05 舍入）
@number.format_with_pattern(1.23, en, "0.05")           // 1.25
@number.format_with_pattern(1234.56, en, "#,##0.05")    // 1,234.55
@number.format_with_pattern(1.15, en, "0.25")           // 1.25（两个增量位组成 0.25）
@number.format_with_pattern(0.125, en, "0%")            // 13%
@number.format_with_pattern(0.125, en, "0‰")            // 125‰
@number.format_with_pattern(1.2, en, "*_#,##0.00")      // ____1.20
```

数字模式同时覆盖正负子模式、引号字面量、`E` 科学计数法、`¤` 货币标记和 `*`
填充转义。
`@` 的数量是最小有效位，后续 `#` 扩展最大有效位；`1-9` 所在位决定增量舍入单位，
多个 `1-9` 位按位置共同组成完整增量（如 `0.25`），采用 half-away-from-zero。完整验收矩阵与案例见
[`docs/conformance.md`](docs/conformance.md) 第 3.3.1 节。

## 货币显示与会计格式

```moonbit
let en = @core.Locale::parse("en")
let code = @number.CurrencyOptions::with_display(@number.Code)
@number.format_currency(1234.5, "USD", en, currency_options=code)
// USD 1,234.50

let accounting = @number.CurrencyOptions::default().with_accounting()
@number.format_currency(-1234.5, "USD", en, currency_options=accounting)
// ($1,234.50)

@number.format_currency_with_pattern(1234.5, "USD", en, "¤¤#,##0.00")
// USD 1,234.50
```

## 复数与已渲染位数

复数选择可以直接使用最终渲染出来的数字位数。因此 `1` 与 `1.00` 在英语中会选择
不同的复数类别：

```moonbit
let en = @core.Locale::parse("en")
let rendered = @number.format_decimal_result(1.0, en, options=money)
rendered.text                  // 1.00
rendered.integer_digits        // 1
rendered.fraction_digits       // 00

let rules = @plural.PluralRules::cached("en")
rules.select_with_digits(
  rendered.integer_digits,
  rendered.fraction_digits,
)                              // other（v = 2）
```

## 包结构

| 包 | 职责 |
| --- | --- |
| `core` | 严格 Locale 解析、likely subtags、语言协商、回退链 |
| `data` | 生成的 CLDR 数据表（数字、日期、复数、相对时间） |
| `decimal` | 十进制字符串展开、舍入与解析 |
| `pattern` | 数字与日期共用的 CLDR tokenizer，处理引号字面量与模式字段 |
| `number` | 十进制、货币、百分比、科学计数法和紧凑记数 |
| `plural` | CLDR 复数规则 tokenizer、parser 与 evaluator |
| `datetime` | 公历日期时间、星期与 CLDR 日期时间模式 |
| `relative` | 相对时间，组合 number 与 plural 两个包 |
| `examples/readme` | 可执行 README 示例，输出由测试固定并在 CI 中运行 |

## 示例与演示

`cmd/main` 会打印完整的跨区域格式化示例：

```bash
moon run cmd/main
```

`examples/readme` 是 README 代码片段的可执行版本。它会实际调用文档中的 API，
并由配套测试固定输出：

```bash
moon run examples/readme
moon test examples/readme
```

## 数据管线

生成代码已经提交到仓库，因此使用者不需要安装 Node.js。需要刷新数据时执行：

```bash
node tools/fetch-cldr.mjs   # 下载 CLDR 48 JSON 子集（固定 ref 见 baseline）
node tools/gen-cldr.mjs     # 重新生成并格式化 data/generated.mbt
node tools/check-conformance.mjs  # 校验版本、文档和生成数据一致
moon test
```

数据来源：[unicode-org/cldr-json](https://github.com/unicode-org/cldr-json)。
抓取脚本不会使用移动的 `main` 作为发布基线：默认 ref 记录在
`tools/cldr-baseline.json`，下载后还会检查 supplemental 数据的 `_cldrVersion`。

生成器会对货币数据进行去重：共享的 ISO 代码表和基于英语的符号表只生成一次，
每个区域只保存自己的符号、窄符号覆盖以及按货币代码排列的本地名称。紧凑记数表
为每个数量级保存一个默认模式，并仅在需要时保存复数覆盖。加入科学计数法和紧凑
记数数据后，`data/generated.mbt` 仍从 40,088 字节降至 37,273 字节，缩小 7.0%。
生成器最后会执行 `moon fmt`，保证重新生成的文件符合格式要求。

## 测试

```bash
moon check
moon test
moon test --target js
moon test --target native
moon coverage analyze -- -f summary
node tools/gen-intl-fixtures.mjs --check
```

当前测试覆盖严格 Locale 解析、likely subtags、Accept-Language 协商、区域回退、
分组与小数位规则、负数子模式、`@` 有效位、`1-9` 增量舍入、百分比/千分比缩放、
ISO 4217 小数位、基数与序数复数选择、多区域日期时间风格、数字与日期模式中的引号
字面量、相对时间、科学计数法、紧凑记数以及共享货币表覆盖。

## 持续集成与发布

`.github/workflows/ci.yml` 会在 `wasm-gc`、JavaScript 和 Native 三种后端运行
完整测试与可执行示例。独立的质量任务负责检查格式、校验已提交的一致性测试数据，
并输出 `moon coverage` 覆盖率摘要。

`.github/workflows/publish.yml` 会在推送 `v*` 标签后将模块发布到 MoonCakes。
首次发布前需要配置 `MOONCAKES_USERNAME` 与 `MOONCAKES_TOKEN` 两个仓库 Secrets。

## 符合性测试与边界

`conformance/intl_conformance_wbtest.mbt` 包含 178 条由 Node.js 24.13.0 / ICU
77.1 生成的静态白盒断言。因此 CI 运行时只需要 `moon test`，不需要 Node.js 参与
格式化。当前 `moon test` 共 **260 项测试**，其中 178 项为 Intl 差分用例。
测试覆盖 6 个区域，包括十进制与负数、百分号、货币符号/代码/名称/窄符号、
accounting 模式、日期、时间、相对日/小时、科学计数法、紧凑记数、基数复数和
可见小数位。

这些断言验证的是“声明的支持面”，不等同于 UTS #35 全量符合性。支持面之外的时区、
非 Gregorian 日历、非 `latn` 数字系统、单位、消息格式等能力明确不在 0.1.x 的
符合性终点内；日期模式的未支持字段可通过 `Reject` 策略显式返回错误。

版本和测试头信息的机器校验：

```bash
node tools/check-conformance.mjs
```

重新生成或校验一致性数据：

```bash
node tools/gen-intl-fixtures.mjs
node tools/gen-intl-fixtures.mjs --check
```

生成器会在文件头记录 Node 与 ICU 版本。日期时间比较会把 U+202F（CLDR 窄不换行
空格）和 U+0020（Node ICU 在这些模式中输出的普通空格）视为等价；其余空格，
包括货币间距，均按精确内容比较。

## 已知边界

当前明确不包含时区渲染、非公历日历和非 `latn` 数字系统。时区字段可以通过
`Reject` 策略被显式检测，而不是静默丢弃。这些能力列在后续路线图中。

完整的排除项以 [`docs/conformance.md`](docs/conformance.md) 第 3.5 节为准，包括
单位格式化、消息格式、人员姓名、排序/转写、日期区间 skeleton 和 CLDR 官方全量
测试套件。超出该边界的输出不应被解读为“完整 CLDR 实现”。

## 路线图

1. 单位格式化与紧凑记数长格式。
2. 接入数字、日期和复数的 CLDR 官方一致性测试套件（当前不在 0.1.x 符合性终点内）。
3. 在现有 Node `Intl` 差分测试之外增加 ICU4X 差分测试。
4. IANA 时区数据与非公历日历。
5. 非 `latn` 数字系统（阿拉伯-印度数字、天城文数字等）。
6. WASM Playground 与可通过 npm 分发的 bundle。

## 项目申报书

竞赛申报书与生态调研位于 [`docs/proposal.md`](docs/proposal.md)。与
`zlhahaha/moonlocale` 的逐项对比、差异化说明和申诉可用表述见
[`docs/moonlocale-comparison.md`](docs/moonlocale-comparison.md)。针对数字模式
完整语义与增量舍入的复审对照见 [`docs/resubmission-note.md`](docs/resubmission-note.md)。

## 许可证

Apache-2.0。
