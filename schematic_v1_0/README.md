# 鱼缸自动补水控制板 V1.0 原理图整理

日期：2026-10-13。依据项目内 `aquarium_ato_physical_pin_v0_9.pdf` 重建，原 PDF 保留。

2026-10-15 PCB 更新：使用用户在立创 EDA 匹配的商城封装重新创建 `Aquarium_ATO_V1_0.PcbDoc`。板框为 110 mm × 70 mm，左上角设置为用户坐标 `(0,0)`；64 个器件已按整板信号流完成布局，178 个焊盘和 41 个网络保留，尚未布线。详见 `PCB_LAYOUT.md`。

2026-10-13 符号修正：L1 的线圈改为四段 Altium 原生圆弧，修复旧版小数坐标折线在 AD 中显示为竖线的问题；参数、引脚位置和电气连接不变。已打开旧文件时，请关闭该页后重新打开磁盘上的修正版。

## 打开文件

- `Aquarium_ATO_V1_0.PrjPcb`：Altium 工程入口，包含三张可编辑的 `.SchDoc`、原理图库和 PCB 封装库。
- `Aquarium_ATO_PhysicalPin_V1_1.SchLib`：按真实封装引脚号建立的工程原理图库。
- `Aquarium_ATO_Footprints_V1_1.PcbLib`：已在 Altium Designer 19 中生成并保存的工程 PCB 封装库，共 18 个封装。
- `Aquarium_ATO_V1_0.PcbDoc`：使用立创 EDA 商城封装重新创建的正式 PCB，已完成板框和器件布局。
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

当前已完成原理图规范化、器件库、封装核对、PCB 板框和器件布局，尚未布线、铺铜或完成 PCB DRC。原 F1=0.5A 参数保留，水泵启动电流和供电能力需要在器件选型阶段核实。独立连接检查不等同于 Altium 的完整 ERC 或硬件验证。

## 核对依据

- [STM32G030x6/x8 数据手册](https://www.st.com/resource/en/datasheet/stm32g030f6.pdf)：TSSOP20 引脚定义。
- [Nexperia 74HC4052 数据手册](https://assets.nexperia.com/documents/data-sheet/74HC_HCT4052.pdf)：引脚、使能及通道选择表。
- [Diodes AP63203 数据手册](https://www.diodes.com/datasheet/download/AP63200-AP63201-AP63203-AP63205.pdf)：引脚和固定输出连接。
- [Altium 工程连接范围说明](https://www.altium.com/documentation/altium-designer/accessing-defining-managing-project-options)：Automatic/Global 多页网络连接。

精确型号的 EDA 数据来源于 **嘉立创EDA/EasyEDA 官方库**，使用时请保留来源说明：[嘉立创EDA](https://lceda.cn/) / [EasyEDA](https://easyeda.com/)。商城编号和对应链接见 `FOOTPRINT_AUDIT.md`。

`build.cjs` 是绘图源文件，`validate.cjs` 是独立回读检查器，可用 Node.js 运行。重新生成前请先保存人工修改：生成器会覆盖本目录中它生成的 SchDoc、SVG、JSON、CSV 和 HTML 文件，不会合并 AD 内的手工编辑。
