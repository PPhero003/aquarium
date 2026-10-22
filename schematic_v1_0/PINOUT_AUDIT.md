# 器件实体引脚核对记录

本工程的原理图库按订购型号、实体封装顶视图和焊盘号建立。芯片符号中的引脚位置也遵循实体封装顺序，不再按功能重新分组。

- TSSOP20：左侧从上到下为 1→10，右侧从上到下为 20→11。
- SO16：左侧从上到下为 1→8，右侧从上到下为 16→9。
- TSOT26：左侧从上到下为 1→3，右侧从上到下为 6→4。
- SOT23/SOT223：按原厂数据手册的 `Top View` 摆放。

## U3 — STM32G030F6P6 / TSSOP20

采用 ST 数据手册 DS12991 Rev.6 的 TSSOP20 引脚表。工程使用关系如下：

| 实体脚号 | 原厂引脚/本工程功能 |
|---:|---|
| 1 | PB7 / USART1_RX → WIFI_RX |
| 2 | PC14/PB9 → MUX_S0 |
| 3 | PC15 → MUX_S1 |
| 4 | VDD/VDDA → +3V3 |
| 5 | VSS/VSSA → GND |
| 6 | NRST |
| 7 | PA0 → MUX_E |
| 8 | PA1，未使用 |
| 9 | PA2 / USART2_TX → SENS_TX |
| 10 | PA3 / USART2_RX → SENS_RX |
| 11 | PA4 → PUMP_CMD |
| 12 | PA5 → KEY_MANUAL |
| 13 | PA6 → LED_STATUS |
| 14 | PA7 → LED_FAULT |
| 15 | PB0/PB1/PB2/PA8，共用封装脚，未使用 |
| 16 | PA11[PA9] → KEY_AUTO |
| 17 | PA12[PA10]，未使用 |
| 18 | PA13 / SWDIO |
| 19 | PA14-BOOT0 / SWCLK |
| 20 | PB6 / USART1_TX → WIFI_TX |

来源：https://www.st.com/resource/en/datasheet/stm32g030f6.pdf

## U1 — AP63203WU-7 / TSOT26

| 实体脚号 | 引脚 |
|---:|---|
| 1 | FB |
| 2 | EN |
| 3 | VIN |
| 4 | GND |
| 5 | SW |
| 6 | BST |

来源：https://www.diodes.com/datasheet/download/AP63200-AP63201-AP63203-AP63205.pdf

## U2 — 74HC4052D,652 / SO16 (SOT109-1)

| 实体脚号 | 引脚 | 实体脚号 | 引脚 |
|---:|---|---:|---|
| 1 | 2Y0 | 9 | S1 |
| 2 | 2Y2 | 10 | S0 |
| 3 | 2Z | 11 | 1Y3 |
| 4 | 2Y3 | 12 | 1Y0 |
| 5 | 2Y1 | 13 | 1Z |
| 6 | E | 14 | 1Y1 |
| 7 | VEE | 15 | 1Y2 |
| 8 | GND | 16 | VCC |

来源：https://assets.nexperia.com/documents/data-sheet/74HC_HCT4052.pdf

## Q1 — DMP6023LE-13 / SOT223

| 实体焊盘 | 引脚 |
|---:|---|
| 1 | G |
| 2 | D |
| 3 | S |
| 4 / 散热片 | D |

库符号将 2、4 两个 Drain 管脚叠放到同一个电气连接点，避免后续封装映射漏掉功率散热片。

来源：https://www.diodes.com/datasheet/download/DMP6023LE.pdf

## Q2 — AO3400A / SOT23

| 实体脚号 | 引脚 |
|---:|---|
| 1 | G |
| 2 | S |
| 3 | D |

来源：https://www.aosmd.com/res/data_sheets/AO3400A.pdf

## 二极管和保护器件

- D1 BZT52C10 / SOD-123：1=K，2=A。
- D2 SS16 / SMA：1=K，2=A。
- D3、D4 LED：1=K，2=A。
- F1 RL60-050：无极性的两脚 PPTC 自恢复保险丝。

连接器 J1/J2/J3/J4/J5/J6/J7 的脚号是本项目接口定义。制作 PCB 前，应选定具体连接器料号，再确认封装的 Pin 1 标记、插接视角和线序。
