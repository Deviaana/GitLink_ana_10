# moonl10n 的 CLDR / UTS #35 符合性声明与终点

文档状态：2026-10-20
适用版本：moonl10n 0.1.x
机器可读基线：[`tools/cldr-baseline.json`](../tools/cldr-baseline.json)

## 1. 结论先行

moonl10n **不宣称完整实现 UTS #35，也不宣称通过 CLDR 官方全量一致性测试套件**。
本项目声明的是 **CLDR 48 子集符合性**：在本文第 3 节定义的封闭范围内，格式化结果由
CLDR 48 数据决定，并与第 3.4 节列出的验证终点一致；超出该范围的能力不属于
0.1.x 的符合性承诺。

因此，申报材料中的“按 CLDR 规则”应理解为“按 CLDR 48 数据实现本文列出的
数字、货币、日期时间、相对时间和复数子集”，不表示对 UTS #35 全部章节、全部区域、
全部日历/数字系统或 CLDR 官方全量测试套件的符合。

## 2. 规范与数据基线

| 项目 | 固定值 | 仓库证据 |
| --- | --- | --- |
| CLDR 数据版本 | **CLDR 48** | `tools/cldr-baseline.json`；三个 supplemental JSON 的 `_cldrVersion` 均为 `48` |
| UTS #35 版本 | **UTS #35 revision 48（LDML 48）** | <https://www.unicode.org/reports/tr35/tr35-48.html> |
| CLDR JSON 来源 | `unicode-org/cldr-json`，首选 `48.0.0`，404 时回退 `release-48` | `tools/fetch-cldr.mjs`；最终仍须校验 `_cldrVersion = 48` |
| 数字系统 | `latn` | `data/generated.mbt` 的 `cldr_numbering_system()` |
| 日历 | `gregory` | `data/generated.mbt` 的 `cldr_calendar()` |
| 内置区域 | `en`、`zh`、`de`、`ja`、`fr`、`ar` | `tools/cldr-baseline.json` |
| 差分测试 oracle | Node 24.13.0 / ICU 77.1 | `conformance/intl_conformance_wbtest.mbt` 文件头 |

ICU 77.1 是**差分测试 oracle**，不是 CLDR 48 规范文本本身。它用于固定当前支持面上的
行为回归；如果后续 ICU 行为与 CLDR 48 数据不一致，应先更新
`conformance/intl_conformance_wbtest.mbt` 并在本文记录差异，而不能静默改变版本声明。

## 3. 完整符合性终点

0.1.x 的符合性终点是一个封闭元组：

```text
(CLDR 48 数据, 6 个区域, latn, Gregorian, 公开 API, 明确列出的字段, 178 条 Intl 差分断言)
```

### 3.1 API 终点

只对以下包中 `pkg.generated.mbti` 暴露的公开 API 负责：

- `core`：Locale 解析、严格校验、likely subtags 子集、Accept-Language 协商和回退。
- `number`：十进制、货币、百分比、科学计数法、紧凑记数（short）和显式数字模式。
- `datetime`：Gregorian 日期、时间、日期区间 fallback、显式日期模式和字段策略。
- `relative`：年、月、周、天、小时、分钟、秒的相对时间。
- `plural`：基数与序数规则、操作数求值和缓存。
- `decimal`、`pattern`：上述 API 的内部基础包，不单独承诺超出其测试覆盖的行为。

未在上述包 `pkg.generated.mbti` 中出现的 API，不属于符合性声明的一部分。

### 3.2 区域终点

只承诺 `en`、`zh`、`de`、`ja`、`fr`、`ar` 六个内置区域。其他合法 locale 会沿
`Locale::fallbacks()` 回退；若无法命中内置数据，则回退到英语数据。该英语回退是
兼容行为，**不表示该 locale 的 CLDR 数据已被实现**。

### 3.3 数据与字段终点

| UTS #35 相关部分 | 纳入 0.1.x 终点 | 明确不承诺 |
| --- | --- | --- |
| Core / Locale | BCP 47 子集、语言-书写系统-地区-variants-extensions、严格解析、likely subtags 子集、Accept-Language | 完整 BCP 47、extlang、grandfathered 标签、完整 CLDR locale 继承与所有扩展语义 |
| Numbers | 十进制模式、分组、最小/最大小数位、正负子模式、百分比、货币符号/代码/名称/窄符号、accounting、ISO 4217 小数位、科学计数法、short 紧凑记数 | 单位格式化、long 紧凑记数、number range、rounding increment、sign display、`latn` 之外的数字系统、完整 CLDR 数字语法 |
| Dates | Gregorian 日期/时间风格（short/medium 完整；long/full time 的时区字段按策略处理）、显式 `y M d H h m s a E` 字段、引号字面量、日期区间 fallback、相对时间 | 时区字段、非 Gregorian 日历、era/quarter/week-of-year/day-of-year、flexible day periods、日期区间 skeleton、时区名称与 DST |
| Messages | 无 | ICU MessageFormat / MF2、消息目录和选择语法 |
| Supplemental | 基数/序数复数规则、货币小数位、内置 likely-subtags 子集 | 完整 supplemental 数据、全部区域/语言、排序、转写、人员姓名等 |

日期模式中的不支持字段有三种显式策略：`Skip`（默认跳过）、`Preserve`（原样保留）和
`Reject`（返回 `UnsupportedField`）。**符合性测试使用 `Reject` 验证不支持字段会被
发现，而不是把静默跳过当作完整 CLDR 输出。** 例如 `z` 字段不会被伪造成时区结果。

### 3.4 验证终点

满足以下全部条件，才视为 0.1.x 符合性通过：

- `moon test`：**255 项测试全部通过**（其中 178 项为 Intl 差分断言）。
- `moon test --target js`、`moon test --target native`：同样全部通过。
- `node tools/gen-intl-fixtures.mjs --check`：fixture 文件与 Node 24.13.0 / ICU 77.1 基线一致。
- `node tools/check-conformance.mjs`：文档、生成数据和测试头信息与
  `tools/cldr-baseline.json` 一致。
- CI 在 `wasm-gc`、`js`、`native` 三个后端运行上述检查。

### 3.5 明确排除项

以下能力不属于 0.1.x 的“完整符合性终点”，即使未来 API 有所扩展，也必须先更新本文、
基线文件和测试证据后才能纳入声明：

- 时区渲染与时区数据库（IANA tzdata）。
- 非 Gregorian 日历（Buddhist、Japanese、Islamic、Hebrew 等）。
- `latn` 之外的数字系统（arab、deva、beng、thai 等）。
- 单位格式化、消息格式化、人员姓名、排序、转写。
- CLDR 官方全量 conformance suite。
- 未在 `pkg.generated.mbti` 中出现的 API。

## 4. 版本更新规则

CLDR 版本不能通过修改一句文档来“升级”。任何版本变更必须同时完成：

1. 修改 `tools/cldr-baseline.json` 中的 `cldrVersion`、`uts35Revision` 和 `cldrJsonRef`。
2. 用固定 ref 重新抓取数据：`node tools/fetch-cldr.mjs`。
3. 重新生成：`node tools/gen-cldr.mjs`。
4. 重新生成并核对差分测试：`node tools/gen-intl-fixtures.mjs`。
5. 更新 `docs/conformance.md`、`README.md`、`docs/proposal.md`。
6. 运行全部后端测试和 `node tools/check-conformance.mjs`。

只完成其中一部分时，项目仍声明为 CLDR 48；不会把 `main` 分支的移动数据当作稳定版本。

## 5. 复现命令

```bash
moon test
moon test --target js
moon test --target native
moon test conformance
node tools/gen-intl-fixtures.mjs --check
node tools/check-conformance.mjs
```

## 6. 相关文件

- 数据基线：`tools/cldr-baseline.json`
- 数据抓取：`tools/fetch-cldr.mjs`
- 数据生成：`tools/gen-cldr.mjs`
- 生成数据：`data/generated.mbt`
- Intl 差分断言：`conformance/intl_conformance_wbtest.mbt`
- CI：`.github/workflows/ci.yml`
