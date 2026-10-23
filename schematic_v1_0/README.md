# 鱼缸自动补水控制板 V1.0 原理图整理

日期：2026-10-13。依据项目内 `aquarium_ato_physical_pin_v0_9.pdf` 重建，原 PDF 保留。

2026-10-23 PCB 更新：`generate_lceda_pcb.cjs` 综合 `GenerateAquariumFullLayout.pas`、`GeneratePCBPlacement.pas`、`RouteAndPourAquarium.pas` 和 `FixSilkscreenOverlaps.pas` 生成 `Aquarium_ATO_V1_0_LCEDA.PcbDoc`。四份脚本的布局、布线计划和位号数据已交叉校验一致。器件布局按比例扩展至 120 mm × 72 mm；本次细节优化后生成 304 段双层铜线、38 个过孔和 3 个铺铜区，254 段信号线中 247 段为 0.40 mm、7 段为 0.23 mm。预检确认 71 条计划连接均连通，异网铜冲突为 0；嘉立创 EDA 的实际铺铜与最终 DRC 尚待执行。该板已加入 Altium 工程；详见 `PCB_LAYOUT.md`。

2026-10-13 符号修正：L1 的线圈改为四段 Altium 原生圆弧，修复旧版小数坐标折线在 AD 中显示为竖线的问题；参数、引脚位置和电气连接不变。已打开旧文件时，请关闭该页后重新打开磁盘上的修正版。

## 打开文件

- `Aquarium_ATO_V1_0.PrjPcb`：Altium 工程入口，包含三张可编辑的 `.SchDoc`、原理图库和 PCB 封装库。
- `Aquarium_ATO_PhysicalPin_V1_1.SchLib`：按真实封装引脚号建立的工程原理图库。
- `Aquarium_ATO_Footprints_V1_1.PcbLib`：已在 Altium Designer 19 中生成并保存的工程 PCB 封装库，共 18 个封装。
- `Aquarium_ATO_V1_0_LCEDA.PcbDoc`：新脚本生成的双层 PCB，已加入 Altium 工程并用于导入立创 EDA；含自动布线、过孔和待在 EDA 中重铺的铺铜区。
- `Aquarium_ATO_V1_0_LCEDA_FullProject_Import.zip`：完整 Altium 工程导入包，包含工程入口、三张原理图、原理图库、PCB 封装库、新脚本生成的 PCB，以及工程内全部 `.pas`/`.PrjScr` 自动化脚本；运行 `package_lceda_import.ps1` 可重新生成。脚本作为工程资料一并归档，不属于 EDA 必须导入的电路设计文档。
- `library_sources/EDA_LCSC_Footprint_Source.PcbDoc`：用户提供的立创封装母版，保留用于封装追溯。
- `PCB_LAYOUT.md`、`PCB_PLACEMENT.csv`：PCB 布局依据及最终坐标表。
- `FOOTPRINT_AUDIT.md`：封装来源、立创商城编号、焊盘编号和待实物确认项。
- `PINOUT_AUDIT.md`：订购型号、实体封装和焊盘号核对记录；库符号按此表生成。
- `PROJECT_AUDIT.md`：工程、原理图、器件库、封装库和清理结果汇总。
- `library_sources/`：已采用的 7 份嘉立创EDA/EasyEDA 官方模型原始 JSON 与来源摘要。
- `Aquarium_ATO_V1_0.pdf`：三页 A3 矢量阅读版。
- `01_Power_Pump.SchDoc`：输入保护、3.3 V 降压、水泵驱动。
- `02_Controller_IO.SchDoc`：主控、复位、SWD、WiFi、按键、指示灯。
- `03_Sensors.SchDoc`：74HC4052、偏置电阻、三个传感器接口。
- 同名 SVG：可缩放的矢量图；`review.html` 可在浏览器查看。
- `pin-net.csv`：177 个实体引脚/焊盘与网络的对应表；`BOM.csv`：64 个器件的清单。

Altium 文件采用受支持的 ASCII SchDoc 格式，元件、引脚、导线、网络标签和连接点均为原生可编辑对象。已在本机 Altium Designer 19.0.4 实际打开工程并识别三张图。打开后可通过另存为转换为 Altium 二进制 SchDoc。

工程采用无顶层 Sheet Symbol 的多页连接方式：Net Identifier Scope 保持 Automatic（此结构自动使用 Global），或明确设为 Global。同名网络标签跨页相连；请勿改为仅端口全局的 Flat，否则本工程的跨页信号标签不会互连。

## 本次整理内容

| 部位 | 实际连接 |
| --- | --- |
| 4052 使能 | R11=10k 接在 +3V3 与 U2.6/MUX_E 之间，置于使能脚旁 |
| 4052 通道选择 | R12、R13=100k 分别从 MUX_S0、MUX_S1 接地 |
| 传感器串口接收 | R14=10k 从 +3V3 接 SENS_RX |
| 传感器端 RX | R15/R16/R17=10k 从 +3V3 接各接口 RX，位于串联电阻的接口侧 |
| WiFi 串口 | R18 上拉 MCU RX；R25 上拉模块 RX；R2/R3 串接 TX/RX |
| 水泵默认状态 | R5=100k 从 R4 后的 MOS 栅极直接接源极/地 |
| 复位 | R8 上拉 NRST；C15、SW3 从 NRST 分别接地 |
| 自动/手动按键 | R6/R7 上拉，C13/C14 与按键分别接在信号与地之间 |
| 主控电源 | C7/C8 明确并接在 U3 电源网络与地之间 |
| 4052 电源 | C12 并接 +3V3 与 GND，U2.7/VEE 与 U2.8/GND 接地 |
| 接口电源 | C9/C10/C11 分别接对应传感器电源；C16/C17/C18 接 J7 电源 |
| 降压电路 | C4 接 BST-SW；C1/C2/C3 接输入与地；C5/C6 接输出与地；FB 取电感后输出 |

保留 V0.9 的器件编号、阻容数值和接口针序。U1/U2/U3 按实体封装顶视图排列引脚：TSOT26 左 1→3/右 6→4，TSSOP20 左 1→10/右 20→11，SO16 左 1→8/右 16→9。复用脚名称显示本工程选用的 GPIO/外设功能，固件仍需按芯片手册配置复用功能。C2/C5/C6 的 X7R 要求在图下注释中注明。

三张 SchDoc 的每个元件均已绑定 `Aquarium_ATO_Footprints_V1_1.PcbLib` 中的封装。U1、U2、U3、Q1、Q2、F1、D2 的焊盘尺寸和编号依据所列立创/EasyEDA 官方模型重建；通用阻容、连接器、按键、电解电容和电感使用项目标准封装。进入 PCB 布局前，应为这些机械件确定采购型号并按实物尺寸复核。

2026-10-14 封装焊盘位置复核：TSOT-23-6、TSSOP-20、SOIC-16 已修正为元件面顶视图的逆时针编号，1 脚位于左上；SOT-23/SOT-223 按各自原厂顶视图保留左下 1 脚。逐封装结果见 `FOOTPRINT_PIN_POSITION_AUDIT.md`。

连接点用实心圆点表示；无圆点的导线交叉不连接。未用引脚 U3.8、U3.15、U3.17、U2.4、U2.11 放置 No ERC 标记。接口上的 RX/TX 按外接模块/传感器视角命名。

## 验证范围

- 独立解析输出 `.SchDoc` 中的引脚方向、导线、连接点和网络标签，重新计算电气连接。
- 64 个器件、177 个实体引脚/焊盘、41 个网络；172 个使用引脚连通，5 个引脚明确未用。
- 检查未连接引脚、异名网络短接、同名网络断开，以及关键上拉/下拉/去耦/电源引脚对应关系；结果见 `validation.json`。
- 在 Altium 运行库脚本并回读库组件，确认 `Aquarium_ATO_Footprints_V1_1.PcbLib` 含 18 个命名封装；结果见 `footprint-runtime-audit.txt`。
- 已查看三页 PDF 渲染结果，并修正文字和导线的重叠。
- 工程文件、三张原理图、两个库和 BOM 的交叉核对结果见 `PROJECT_AUDIT.md`。

## 导入立创 EDA

在本目录运行 `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\package_lceda_import.ps1` 生成完整导入包，然后在立创 EDA 专业版选择 Altium 工程导入并选取 `Aquarium_ATO_V1_0_LCEDA_FullProject_Import.zip`。包内保留 `.PrjPcb` 原有相对文件名，工程入口引用三张原理图、原理图库、两个封装库和新脚本生成的 PCB；`library_sources/`、BOM、连接/封装审计也随包提供。导入后请在 EDA 中确认跨页网络、器件符号和封装映射；Altium 格式转入 EDA 后仍需检查转换结果，并非已经在 EDA 端验证通过的原生工程。

PCB 生成器优先采用 0.40 mm 信号线，只有无法布通时才回退到 0.23 mm；本版共 254 段信号线，其中 247 段为 0.40 mm、7 段为 0.23 mm。导入前几何预检间距已提高至 0.20 mm；导入后仍须重新铺铜并按目标板厂能力运行实际 DRC。通过脚本预检不等于板厂规则验证或已可投板。原 F1=0.5A 参数保留，水泵启动电流和供电能力仍需在器件选型阶段核实。独立连接检查也不等同于 Altium 的完整 ERC 或硬件验证。

### 在立创 EDA 内重建一块新 PCB

如果已把本工程的器件库和封装库导入立创 EDA 专业版，可在 EDA 的脚本运行界面依次添加并运行：

1. `00_pcb_preflight.js`：只读检查当前工程原理图、器件关联、封装关联和 Protel2 网表；运行前先聚焦任意一张工程原理图。
2. `01_build_aquarium_pcb.js`：再次检查原理图和库关联，在当前工程中新建一个带唯一名称的 PCB，按 `GeneratePCBPlacement.pas` 的坐标放置 64 个器件，并导入原理图网络。运行前同样聚焦工程原理图。

重建脚本不会删除或覆盖现有 `Aquarium_ATO_V1_0_LCEDA.PcbDoc`。新板只包含布局和网表，不包含已验证的布线、铺铜或板框；运行后须检查封装、焊盘网络与飞线，补画板框、完成布线、重铺铜并运行嘉立创 EDA DRC。两个脚本使用 EDA 的内置 `eda` API，不是 Node.js 脚本；如果预检报告器件或封装未关联，先在 EDA 中完成库关联，不要继续运行重建脚本。

## 核对依据

- [STM32G030x6/x8 数据手册](https://www.st.com/resource/en/datasheet/stm32g030f6.pdf)：TSSOP20 引脚定义。
- [Nexperia 74HC4052 数据手册](https://assets.nexperia.com/documents/data-sheet/74HC_HCT4052.pdf)：引脚、使能及通道选择表。
- [Diodes AP63203 数据手册](https://www.diodes.com/datasheet/download/AP63200-AP63201-AP63203-AP63205.pdf)：引脚和固定输出连接。
- [Altium 工程连接范围说明](https://www.altium.com/documentation/altium-designer/accessing-defining-managing-project-options)：Automatic/Global 多页网络连接。

精确型号的 EDA 数据来源于 **嘉立创EDA/EasyEDA 官方库**，使用时请保留来源说明：[嘉立创EDA](https://lceda.cn/) / [EasyEDA](https://easyeda.com/)。商城编号和对应链接见 `FOOTPRINT_AUDIT.md`。

`build.cjs` 是绘图源文件，`validate.cjs` 是独立回读检查器，可用 Node.js 运行。重新生成前请先保存人工修改：生成器会覆盖本目录中它生成的 SchDoc、SVG、JSON、CSV 和 HTML 文件，不会合并 AD 内的手工编辑。
