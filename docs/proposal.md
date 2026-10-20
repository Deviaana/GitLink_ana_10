# moonl10n 项目申报书

## 1. 基本信息
- 项目名称：moonl10n：面向 MoonBit 生态的本地化格式化内核
- 参赛者：刘乐琪
- 联系方式：15827309010
- GitHub 仓库链接：https://github.com/Deviaana/GitLink_ana_10.git
- GitLink 仓库链接：https://gitlink.org.cn/ana77/moonl10n.git
- 项目方向：MoonBit 基础软件与开发工具 / 国际化与本地化基础设施 / CLDR 格式化内核
- 是否为原创项目：是
- 是否为移植项目：否

## 2. 项目简介
moonl10n 是使用 MoonBit 编写的本地化格式化库，接收 locale、数值和选项，按 Unicode CLDR 规则输出数字、货币、百分比、日期时间、相对时间、复数和紧凑记数，不依赖宿主 `Intl` 或 FFI，可在 WASM-GC、JS、Native 后端保持一致结果。

## 3. 预期使用场景
1. **数据图表**：图表库传入 12345 和 2026-10-18，英文显示 `12K`、`Oct 18, 2026`，中文显示 `1.2万`、`2026年10月18日`，供坐标轴、图例和提示框使用。
2. **跨境账单**：Native 服务生成多语言账单，货币输出 `$1,234.50` 或 `1.234,50 €`，日期区间表示账期，相对时间显示“3 天前”，无需 Node.js 或宿主 `Intl`。
3. **多语言界面**：应用按 `zh-HK, en;q=0.8` 协商语言，复数选择 `1 file / 3 files`，相对时间显示消息时间；同一代码在 WASM、Native 和后端测试中结果一致。

## 4. 实现范围与核心功能
- Locale 解析、严格校验、likely subtags、语言协商与回退。
- CLDR 数据抓取、裁剪、去重和 MoonBit 常量生成。
- 十进制、货币、百分比、科学计数法和紧凑记数。
- 日期时间、区间、相对时间及不支持字段策略。
- 基数/序数复数规则解析、求值和缓存。
- 数字与日期共用 tokenizer，支持引号字面量和 `¤` 货币占位符。
- 三后端测试、Intl 差分用例、覆盖率、示例和发布流程；现有 255 项测试，其中 178 条为 Intl 差分用例。

## 5. 原创项目、移植项目与参考项目说明
本项目为原创项目，不是移植项目。设计时参考 Unicode CLDR、ECMA-402 `Intl` 和 ICU4X 架构（https://github.com/unicode-org/icu4x，Unicode License），未复制实现代码。CLDR 数据遵循 Unicode License，本项目代码使用 Apache-2.0。

## 6. CLDR/UTS #35 版本与完整符合性终点（补审说明）

### 6.1 版本基线

本项目固定使用 **Unicode CLDR 48** 数据，对应 **UTS #35 revision 48（LDML 48）**。该版本不是仅写在文档中的说明，而是由仓库中的机器可读基线统一约束：

- `tools/cldr-baseline.json` 固定 `cldrVersion = 48`、`uts35Revision = 48`、`cldrJsonRef = 48.0.0`（404 时回退 `release-48`，下载后仍校验 `_cldrVersion = 48`）。
- `data/generated.mbt` 由 `tools/gen-cldr.mjs` 从 CLDR 48 JSON 生成，文件头和 `cldr_version()` 均记录 48。
- `tools/fetch-cldr.mjs` 使用固定 ref 抓取；下载后会校验 supplemental `plurals.json`、`ordinals.json`、`currencyData.json` 的 `_cldrVersion` 必须为 48。
- `conformance/intl_conformance_wbtest.mbt` 文件头记录差分 oracle 为 Node 24.13.0 / ICU 77.1；ICU 只用于行为回归，不等同于 CLDR 48 规范文本。

### 6.2 完整符合性终点

0.1.x 的符合性声明是**封闭的 CLDR 48 子集**，终点由以下五部分组成：

1. **区域终点**：只承诺 `en`、`zh`、`de`、`ja`、`fr`、`ar` 六个内置区域；其他 locale 回退到内置数据或英语，不声明其 CLDR 数据已实现。
2. **数字终点**：`latn` 数字系统；十进制、货币、百分比、科学计数法和 short 紧凑记数；支持分组、最小/最大小数位、正负子模式、ISO 4217 货币小数位、accounting 模式及货币符号/代码/名称/窄符号。
3. **日期终点**：Gregorian 日历；日期/时间风格、显式 `y M d H h m s a E` 字段、引号字面量和日期区间 fallback；不支持字段可通过 `Reject` 策略返回 `UnsupportedField`，不会把静默跳过当作完整 CLDR 输出。
4. **相对时间与复数终点**：年、月、周、天、小时、分钟、秒；CLDR 基数与序数复数规则，覆盖 `n i v w f t c e` 操作数。
5. **验证终点**：255 项测试全部通过，其中 178 条为 Intl 差分断言；在 `wasm-gc`、`js`、`native` 三后端运行；`node tools/check-conformance.mjs` 校验版本、文档和生成数据一致。

因此，“按 CLDR 规则”的最终语义范围就是上述五点，不延伸到未列出的 API、区域、数字系统、日历或字段。

### 6.3 明确排除项

以下能力**不在** 0.1.x 的完整符合性终点内：时区渲染与 IANA tzdata、非 Gregorian 日历、非 `latn` 数字系统、单位格式化、消息格式化、人员姓名、排序/转写、日期区间 skeleton、CLDR 官方全量一致性测试套件，以及未在 `pkg.generated.mbti` 中出现的 API。

### 6.4 复核入口

- 完整声明与字段矩阵：`docs/conformance.md`
- 机器可读版本基线：`tools/cldr-baseline.json`
- 版本一致性检查：`node tools/check-conformance.mjs`
- 差分测试：`conformance/intl_conformance_wbtest.mbt`
- CI：`.github/workflows/ci.yml`
