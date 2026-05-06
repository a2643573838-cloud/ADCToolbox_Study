# 5-4：数字输出、bit weight 与校准

## 今日目标

- 理解 ADC 数字输出从 bit matrix 到数值输出的过程。
- 掌握 bit activity、overflow check、weight calibration 的基本用途。
- 理解 SAR / Pipeline ADC 中 bit weight 和 redundancy 的意义。
- 跑通数字校准相关示例。

## 推荐时间安排

| 时间 | 内容 |
| --- | --- |
| 09:30-10:30 | 阅读 `wcalsin.m`、`cdacwgt.m` |
| 10:45-12:00 | 阅读 `plotwgt.m`、`plotres.m`、`bitchk.m` |
| 14:00-15:30 | 构造 bit matrix，运行 `adcpanel(bits)` |
| 15:45-17:30 | 学习 Python 数字校准示例 |
| 20:00-21:00 | 画出数字校准流程图 |

## 今日重点函数

- `bitchk`：检查 bit 输出是否有溢出或异常分布。
- `wcalsin`：用正弦输入估计 bit weight。
- `cdacwgt`：计算多段 CDAC 权重。
- `plotwgt`：绘制 bit weight 和 radix。
- `plotres`：绘制部分和残差散点图。
- `plotressin`：结合 `wcalsin` 和 `plotres` 的快捷封装。

## 建议阅读的源码

```text
matlab/src/bitchk.m
matlab/src/wcalsin.m
matlab/src/cdacwgt.m
matlab/src/plotwgt.m
matlab/src/plotres.m
matlab/src/shortcut/plotressin.m
```

## Python 示例参考

```text
python/src/adctoolbox/examples/05_debug_digital/exp_d01_cal_weight_sine_lite.py
python/src/adctoolbox/examples/05_debug_digital/exp_d02_cal_weight_sine.py
python/src/adctoolbox/examples/05_debug_digital/exp_d03_redundancy_comparison.py
python/src/adctoolbox/examples/05_debug_digital/exp_d11_bit_activity.py
python/src/adctoolbox/examples/05_debug_digital/exp_d12_sweep_bit_enob.py
python/src/adctoolbox/examples/05_debug_digital/exp_d13_weight_scaling.py
python/src/adctoolbox/examples/05_debug_digital/exp_d14_overflow_check.py
```

## 练习 1：从正弦波构造简单 bit matrix

```matlab
N = 4096;
n = (0:N-1)';
sig = sin(2*pi*37/N*n);

nbits = 12;
code = round((sig/2 + 0.5) * (2^nbits - 1));
bits = dec2bin(code, nbits) - '0';

rep = adcpanel(bits, 'fs', 100e6);
```

观察：

- `adcpanel` 如何识别 bit 数据。
- 是否能看到 bit weight 和 residual 图。
- 校准前后的频谱是否有差异。

## 练习 2：观察 bit activity

```matlab
bitchk(bits);
```

观察：

- MSB 和 LSB 的翻转频率是否不同。
- 是否有长期不翻转或异常翻转的 bit。

## 数字校准主流程

```text
bit matrix
    ↓
overflow / bit activity check
    ↓
weight calibration
    ↓
weighted digital output
    ↓
spectrum / INL / residual error analysis
```

## 今日产出

建议整理：

```text
5-4_数字校准流程.md
```

回答以下问题：

- ADC 数字校准为什么可以被看作 bit weight 估计？
- SAR ADC 的 CDAC mismatch 会如何反映到 bit weight？
- redundancy 对校准和容错有什么帮助？
- `plotres` 的 residual scatter 能帮助发现什么问题？
