# PCB 封装库核对记录

日期：2026-10-14

库文件：`Aquarium_ATO_Footprints_V1_1.PcbLib`

本库已在 Altium Designer 19.0.4 中实际生成、保存并通过运行时枚举检查，共 18 个封装。三张 SchDoc 中的 64 个元件实例均已写入封装名称和该 PcbLib 文件名。

2026-10-14 再次按**元件面顶视图**核对焊盘位置后，已修正 TSOT-23-6、TSSOP-20、SOIC-16 原先镜像的编号排列和 1 脚标记。修正后，多排 IC 均从左上角 1 脚开始，沿封装逆时针编号；SOT-23、SOT-223 等离散器件则保持其原厂顶视图规定的位置。详细顺序见 `FOOTPRINT_PIN_POSITION_AUDIT.md`。

修正后的最终 PcbLib 已重新打开，并通过 Altium PCB API 逐个读取实际 Pad 对象坐标；原始回读结果保存在 `footprint-pad-position-audit.txt`，自动判定结果保存在 `footprint-pin-position-validation.txt`。

精确型号的源数据来自 **嘉立创EDA/EasyEDA 官方库**。来源网站：[嘉立创EDA](https://lceda.cn/) / [EasyEDA](https://easyeda.com/)。下表列出下载时使用的立创商城编号；库内图形重新建立为 Altium 原生焊盘和丝印对象，没有把网页图片当作封装依据。

| 原理图器件 | 型号 | 立创编号 | PcbLib 封装 | 焊盘号 | 状态 |
| --- | --- | --- | --- | --- | --- |
| U1 | AP63203WU-7 | [C780769](https://www.lcsc.com/product-detail/DC-DC-Converters_Diodes-Incorporated-AP63203WU-7_C780769.html) | TSOT-23-6_P0.95 | 1–6 | 官方 EDA 尺寸/编号 |
| U3 | STM32G030F6P6TR | [C529330](https://www.lcsc.com/product-detail/Microcontroller-Units-MCUs-MPUs-SOCs_STMicroelectronics-STM32G030F6P6TR_C529330.html) | TSSOP-20_P0.65 | 1–20 | 官方 EDA 尺寸/编号 |
| U2 | 74HC4052D,652 | [C547001](https://www.lcsc.com/product-detail/analog-switches-multiplexers_nexperia-74hc4052d-652_C547001.html) | SOIC-16_P1.27 | 1–16 | 官方 EDA 尺寸/编号 |
| Q1 | DMP6023LE-13 | [C154901](https://www.lcsc.com/product-detail/MOSFET_Diodes-Incorporated_DMP6023LE-13_Diodes-Incorporated-DMP6023LE-13_C154901.html) | SOT-223-4 | 1–4 | 官方 EDA 尺寸/编号 |
| Q2 | AO3400A | [C20917](https://www.lcsc.com/product-detail/MOSFETs_Alpha-Omega-Semicon_C20917.html) | SOT-23-3 | 1–3 | 官方 EDA 尺寸/编号 |
| F1 | RL60-050 | [C21025](https://www.lcsc.com/product-detail/Resettable-Fuses_RUILON-Shenzhen-Ruilongyuan-Elec_C21025.html) | PPTC_RADIAL_P5.10_D8.0 | 1–2 | 官方本体/跨距；孔径放宽至 0.80 mm |
| D2 | SS16 | [C2481](https://www.lcsc.com/product-detail/Schottky-Diodes_MDD-Microdiode-Semiconductor-SS16_C2481.html) | D_SMA | 1–2 | 官方 EDA 尺寸/编号 |
| D1 | BZT52C10 | 供应商品牌未锁定 | SOD-123 | 1–2 | 标准封装，投板前按采购料确认 |

## 库内封装

`R_0603_1608Metric`、`C_0603_1608Metric`、`C_0805_2012Metric`、`C_1210_3225Metric`、`LED_0603_1608Metric`、`SOD-123`、`D_SMA`、`TSOT-23-6_P0.95`、`SOT-23-3`、`SOT-223-4`、`TSSOP-20_P0.65`、`SOIC-16_P1.27`、`PPTC_RADIAL_P5.10_D8.0`、`CP_RADIAL_D8.0_P3.50`、`IND_SMD_6.0x6.0`、`TB_2P_P5.08`、`HDR_1x4_P2.54`、`SW_TACT_6x6_4P`。

## 投板前需锁定的机械件

- J1/J2：当前为 5.08 mm 两位接线端子，需核对实际端子本体宽度、进线方向和孔径。
- J3–J7：当前为直插 1×4、2.54 mm 排针，需确认直针/弯针及连接器方向。
- SW1–SW3：当前为 6×6 mm 四脚轻触按键，需核对脚距和按钮高度。
- L1：当前为 6×6 mm 屏蔽功率电感焊盘，必须结合最终 3.9 µH、Isat≥4 A 的采购型号核对推荐焊盘。
- C1/C19/C20：当前为 D8.0、脚距 3.50 mm 的径向电解电容，需核对直径、高度和脚距。
- D1：BZT52C10 的供应商品牌未锁定，需确认实际数据手册和极性标识。

运行时枚举结果保存在 `footprint-runtime-audit.txt`。`GenerateFootprints.pas` 是可重复生成脚本；如需重建，应先打开一个空白同名 PcbLib，再从 `GenerateFootprints.PrjScr` 执行入口过程。
