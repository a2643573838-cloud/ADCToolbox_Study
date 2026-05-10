# ADCToolbox 函数参考手册

路径：`D:\Matlab\adc-modeling\ADCToolbox\matlab\src`

---

## 目录

1. [频谱分析](#1-频谱分析)
2. [正弦波拟合与频率检测](#2-正弦波拟合与频率检测)
3. [误差分析](#3-误差分析)
4. [线性度分析（INL / DNL）](#4-线性度分析inl--dnl)
5. [权重校准](#5-权重校准)
6. [CDAC 权重计算与可视化](#6-cdac-权重计算与可视化)
7. [噪声整形与过采样分析](#7-噪声整形与过采样分析)
8. [信号分解](#8-信号分解)
9. [位流诊断](#9-位流诊断)
10. [综合分析面板](#10-综合分析面板)
11. [工具函数](#11-工具函数)
12. [快捷函数（shortcut/）](#12-快捷函数shortcut)
13. [遗留函数（legacy/）](#13-遗留函数legacy)

---

## 1. 频谱分析

### `plotspec.m`

ADCToolbox 的核心函数，对 ADC 输出做功率谱估计，同时计算全套动态指标。

```matlab
[enob, sndr, sfdr, snr, thd, sigpwr, noi, nsd, h] = plotspec(sig, Fs, maxCode, ...)
```

**输入**

| 参数 | 类型 | 说明 |
|------|------|------|
| `sig` | 向量或矩阵 (N_run × N_fft) | ADC 模拟输出，每行是一次独立测量 |
| `Fs` | 标量 | 采样率（Hz），默认 1 |
| `maxCode` | 标量 | 满量程幅度（峰峰值），默认 `max-min(sig)` |
| `'window'` | `'hann'`/`'rect'`/函数句柄 | 窗函数，默认 Hann；`'hann'`/`'rect'` 内嵌实现，无需 Toolbox |
| `'OSR'` | 标量 | 过采样率，带宽限制为 `Fs/(2·OSR)` |
| `'sideBin'` | 整数或 `'auto'` | 信号峰两侧累加的频率 bin 数，`'auto'` 自动适配窗函数 |
| `'disp'` | 逻辑 | 是否绘图，默认 `true` |
| `'averageMode'` | `'normal'`/`'coherent'` | 多次测量的平均方式 |
| `'NFMethod'` | `'auto'`/`'median'`/`'mean'`/`'exclude'` | 噪声底估计算法，默认 `'auto'`（三种方法取中位数） |
| `'cutoff'` | 标量（Hz） | 高通截止频率，用于去除 1/f 噪声 |
| `'nTHD'` | 整数 | THD 计算的谐波阶数，默认 5 |

**输出**

| 变量 | 说明 |
|------|------|
| `enob` | 有效位数 = (SNDR − 1.76) / 6.02 |
| `sndr` | 信噪失真比（dB） |
| `sfdr` | 无杂散动态范围（dB） |
| `snr` | 信噪比（dB） |
| `thd` | 总谐波失真（dB） |
| `sigpwr` | 信号功率（dBFS） |
| `noi` | 噪声底（dB，相对 0 dBFS） |
| `nsd` | 噪声谱密度（dBFS/Hz） |
| `h` | 图形句柄 |

**核心算法要点**

- 归一化：`tdata = (tdata - mean) / maxSignal`，窗函数能量归一化为 `win/sqrt(mean(win²))`
- 功率谱：`spec = |FFT|² / N² × 16`（保证 0 dBFS = 满幅正弦）
- sideBin 自动检测：生成同频率理想正弦的理论旁瓣形状，与噪声底比较找到截止点
- 噪声底三法：中位数法（对杂散鲁棒）、截尾均值法、排除谐波法，默认取三者中位数
- 谐波折叠：通过 `alias()` 函数将高次谐波正确折叠到 [0, Fs/2] 带内

**与 `processAdcData` 的主要区别**

| 特性 | `plotspec` | `processAdcData` |
|------|------------|-----------------|
| 窗函数 | Hann（默认） | 矩形（无窗） |
| 信号 bin 范围 | 自适应 sideBin | 固定 span=0（单 bin） |
| dBFS 归一化 | ✓ | ✗ |
| 噪声底估计 | 3 种方法 | 简单相减 |
| 过采样支持 | ✓ | ✗ |
| 多次平均 | ✓（功率/相干） | ✗ |

---

## 2. 正弦波拟合与频率检测

### `sinfit.m`

四参数迭代正弦拟合，提取幅度、频率、相位、直流偏置。

```matlab
[fitout, freq, mag, dc, phi] = sinfit(sig)
[fitout, freq, mag, dc, phi] = sinfit(sig, f0)
[fitout, freq, mag, dc, phi] = sinfit(sig, f0, tol, rate)
```

**输出约定**：`fitout = mag·cos(2π·freq·t + phi) + dc`

**算法**
1. FFT 峰值 + 二次插值做初始频率估计（f0=0 时自动触发）
2. 三参数线性最小二乘（cos/sin/DC 基底）初始化 A, B, DC
3. 迭代：在矩阵中加入 ∂/∂freq 列，用梯度下降法更新频率，收敛条件 `relerr < tol`（默认 1e-12）

**参数**

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `f0` | 0 | 初始归一化频率（0 = 自动 FFT 估计） |
| `tol` | 1e-12 | 收敛容差 |
| `rate` | 0.5 | 频率更新步长 |
| `niter` | 100 | 最大迭代次数 |
| `verbose` | 0 | 是否打印迭代过程 |

---

### `findfreq.m`

`sinfit` 的频率提取封装，直接返回 Hz 单位的主频。

```matlab
freq = findfreq(sig, fs)
```

- `fs` 默认为 1（归一化频率）
- 内部调用 `sinfit`，返回拟合频率而非 FFT 峰值频率

---

### `findbin.m`

给定目标频率，找最近满足**相干采样**条件（`gcd(bin, N) = 1`）的 FFT bin 编号。

```matlab
b = findbin(fs, fin, n)
```

- 相干采样要求：信号在 FFT 窗口内完成整数个周期，且采样相位不重复
- 从 `round(fin/fs*n)` 向上下双向搜索，优先取高 bin（等距时）
- 支持向量化输入 `fin`

**示例**
```matlab
b = findbin(10000, 1000, 1024)  % 返回 103，而非 102（102 与 1024 不互质）
fin_actual = b * fs / n          % 实际相干频率
```

---

## 3. 误差分析

### `errsin.m`

对 ADC 输出做正弦拟合后，分析残差的分布特性，区分幅度噪声和相位噪声。

```matlab
[emean, erms, xx, anoi, pnoi, err, errxx] = errsin(sig, ...)
```

**两种分析模式**

| 模式 | 参数 `'xaxis'` | X 轴含义 | 用途 |
|------|----------------|----------|------|
| 相位模式（默认） | `'phase'` | 信号相位角 [0°, 360°) | 分离幅度噪声与相位噪声 |
| 幅值模式 | `'value'` | 信号幅值 | 分析 INL 形状、非线性误差 |

**幅度/相位噪声分离**（相位模式）

通过最小二乘拟合以下模型：

```
erms²(θ) = anoi²·cos²(θ) + pnoi²·sin²(θ)
```

其中 `anoi` 为幅度噪声 RMS，`pnoi` 为相位噪声 RMS（rad）。

**过采样支持**（`'osr'` > 1）

对残差先加 Hann 窗，经 `ifilter` 低通滤波至带内 [0, Fs/2/OSR]，再逐点除以窗函数恢复噪声幅度（边缘处用 `max(win, 0.01)` 防止过度放大）。

**主要参数**

| 参数 | 默认 | 说明 |
|------|------|------|
| `'bin'` | 100 | 直方图分 bin 数 |
| `'fin'` | 0（自动） | 归一化输入频率 |
| `'osr'` | 1 | 过采样率 |
| `'erange'` | `[]` | 输出 err 的 X 轴筛选范围 |

---

## 4. 线性度分析（INL / DNL）

### `inlsin.m`

用**正弦波直方图法**计算 ADC 的 INL 和 DNL。

```matlab
[inl, dnl, code] = inlsin(data)
[inl, dnl, code] = inlsin(data, excl)
```

**算法**
1. 对输出码做直方图
2. 余弦变换线性化正弦分布：`cdf = -cos(π · cumsum(hist) / N)`
3. DNL = 相邻码宽的差值，归一化为 LSB 单位，去直流
4. INL = DNL 的累积和

**参数**

| 参数 | 默认 | 说明 |
|------|------|------|
| `excl` | 0.01 | 两端各排除比例（避免裁剪噪声影响） |

**注意**：输入必须为整数 ADC 码（非整数自动四舍五入并警告）；缺失码（DNL ≤ −1）在图中以红色标注。

---

## 5. 权重校准

### `wcalsin.m`

核心校准函数：用正弦输入对 ADC 的**每比特权重**和**直流偏置**进行最小二乘估计。支持单数据集和多数据集联合校准。

```matlab
[weight, offset, postcal, ideal, err, freqcal] = wcalsin(bits, ...)
[weight, offset, postcal, ideal, err, freqcal] = wcalsin({bits1, bits2, ...}, 'freq', [f1, f2], ...)
```

**输出**

| 变量 | 说明 |
|------|------|
| `weight` | 各位校准权重（1×M），归一化到正弦幅度 |
| `offset` | 直流偏置（归一化） |
| `postcal` | 校准后信号：`weight * bits'` |
| `ideal` | 最优拟合正弦（含谐波，由 `order` 指定） |
| `err` | 残差误差（排除谐波后） |
| `freqcal` | 精化后的归一化频率 |

**核心算法**

- 粗搜索：用前 5 列位权重加权和调用 `findFin` 估计频率
- 细搜索：在线性方程组中加入 d/d(freq) 列，梯度下降迭代收敛
- 两套假设：cosine 基底 vs sine 基底，选残差较小的
- **秩不足处理**：检测常数列（丢弃）和完全相关列（合并），避免奇异矩阵
- 极性强制：确保 `sum(weight) > 0`

**主要参数**

| 参数 | 默认 | 说明 |
|------|------|------|
| `'freq'` | 0（自动） | 归一化输入频率 |
| `'order'` | 1 | 拟合谐波阶数（1 = 仅基波） |
| `'reltol'` | 1e-12 | 频率迭代收敛容差 |
| `'niter'` | 100 | 最大迭代次数 |
| `'nomWeight'` | 二进制权重 | 处理秩不足时的参考权重 |
| `'verbose'` | 0 | 打印迭代过程 |

---

## 6. CDAC 权重计算与可视化

### `cdacwgt.m`

计算多段电容 DAC（CDAC）的归一化位权重，支持桥接电容和寄生电容。

```matlab
[weight, ctot] = cdacwgt(cd, cb, cp)
```

**输入**（均按 MSB → LSB 排列）

| 参数 | 说明 |
|------|------|
| `cd` | 各位 DAC 电容值 |
| `cb` | 段间桥接电容（无桥接处填 0） |
| `cp` | 各位寄生电容 |

**输出**

- `weight`：归一化位权重（[0,1] 范围，代表各底极板电压对输出的增益）
- `ctot`：MSB 侧看入的总电容

**算法**（从 LSB 向 MSB 逐位计算）
1. 当前位总电容：`Ct = cp + cd + Cl`（Cl 为前级负载电容）
2. 前级权重衰减：`weight = weight × Cl/Ct`
3. 当前位权重：`weight(i) = cd/Ct`
4. 负载更新：无桥 `Cl = Ct`；有桥 `Cl = series(cb, Ct)`

**示例**
```matlab
% 6-bit 分段 CDAC（3+3），验证二进制权重
cd = [4 2 1 4 2 1];
cb = [0 4 0 8/7 0 0];
cp = [0 0 0 0 0 1];
[weight, ctot] = cdacwgt(cd, cb, cp)
% weight ≈ [0.5000 0.2500 0.1250 0.0625 0.0312 0.0156]
```

---

### `plotwgt.m`

可视化位权重，标注每对相邻位的 radix（权重比），估计有效位数。

```matlab
[radix, wgtsca, effres] = plotwgt(weights)
[radix, wgtsca, effres] = plotwgt(weights, disp)
```

**输出**

| 变量 | 说明 |
|------|------|
| `radix` | 相邻位权重比 `weight(i)/weight(i+1)`，1×(B-1) |
| `wgtsca` | 最优归一化因子（使权重舍入误差最小） |
| `effres` | 有效分辨率 = log2(Σ有效权重 / 最小有效权重 + 1) |

**判读指南**

| radix 值 | 含义 |
|----------|------|
| ≈ 2.00 | 标准二进制 SAR |
| < 2.00 | 冗余/亚基数（如 1.5-bit/级） |
| > 2.00 | 异常，可能为校准错误 |
| 不规律跳变 | 电容失配或校准失败 |

图中负权重以红色显示，Y 轴采用对数坐标。

---

## 7. 噪声整形与过采样分析

### `ntfperf.m`

分析噪声传递函数（NTF）在指定信号带内的 SNR 提升量。

```matlab
snr = ntfperf(ntf, fl, fh)
snr = ntfperf(ntf, fl, fh, disp)
```

**输入**

| 参数 | 说明 |
|------|------|
| `ntf` | z 域传递函数对象（`tf`/`zpk`/`ss`） |
| `fl`, `fh` | 信号带的低/高频边界（归一化到 Fs） |

**输出**：相对于无噪声整形/无过采样基准的 SNR 提升（dB）

```
SNR_improvement = -10·log10( ∫_fl^fh |NTF(f)|² df )
```

**示例**
```matlab
% 一阶低通 ΔΣ NTF，OSR=16
ntf = tf([1 -1], [1 0], 1);
snr = ntfperf(ntf, 0, 0.5/16)  % ≈ 31 dB
```

---

### `perfosr.m`

扫描 OSR 值，绘制 SNDR / SFDR / ENOB 随带宽变化的曲线，并计算 SNDR 斜率（dB/decade）。

```matlab
[osr, sndr, sfdr, enob] = perfosr(sig, ...)
```

**算法**
1. 用 `sinfit` 拟合出理想正弦，计算残差
2. 对残差加 Hann 窗后做 FFT，得误差功率谱
3. 从高 OSR 到低 OSR 累积带内功率（增量法，高效）
4. 信号功率固定为正弦拟合幅度，不随 OSR 变化

**主要参数**

| 参数 | 默认 | 说明 |
|------|------|------|
| `'osr'` | `[1, 2, ..., N/2]` | 扫描的 OSR 列表 |
| `'logscale'` | `true` | X 轴是否用对数坐标 |
| `'smooth'` | N/10 | SNDR 斜率计算的平滑窗口宽度 |
| `'harmonic'` | 5 | 在图上标注的谐波阶数 |

图中包含两个子图：①性能曲线（SNDR/SFDR 左轴，ENOB 右轴）；②SNDR 斜率曲线（含 10 dB/decade 白噪声参考线）。

---

## 8. 信号分解

### `tomdec.m`

Thompson 分解：将单音信号分离为**基波**、**谐波失真**和**其他误差**三部分。

```matlab
[sine, err, har, oth, freq] = tomdec(sig)
[sine, err, har, oth, freq] = tomdec(sig, freq, order)
```

**分解关系**
```
sig = sine + err
err = har + oth
```

| 输出变量 | 含义 |
|----------|------|
| `sine` | 基波 + 直流 |
| `err` | 总误差（sig − sine） |
| `har` | 谐波失真（2 阶～order 阶合成） |
| `oth` | 其他误差（随机噪声等，不被谐波模型解释的部分） |

**算法**：用 cos/sin 正交基底（基波 + 各阶谐波）做联立最小二乘，`linsolve` 求解权重。

---

### `plotphase.m`

用极坐标显示 ADC 信号的相位谱，支持 FFT 相干平均和最小二乘（LMS）两种模式。

```matlab
h = plotphase(sig, harmonic, maxSignal, ...)
```

**两种模式对比**

| 特性 | `'LMS'`（默认） | `'FFT'` |
|------|-----------------|---------|
| 谐波提取 | 最小二乘拟合（类 tomdec） | FFT 相干平均 |
| 极坐标显示 | 各谐波点 + 噪声圆 | 全频谱点分布 |
| 噪声参考 | 残差 RMS 画圆，超出圆的谐波为有效失真 | 无统一噪声圆 |
| 过采样支持 | ✓（OSR > 1 时滤波带内残差） | 部分（OSR 限制频谱范围） |

极坐标约定：半径 = 幅度（dB，0 dBFS 在最外圈），角度 = 相位，以基波为参考。

---

## 9. 位流诊断

### `bitchk.m`

检查 ADC 位流的溢出状况：对每个位位置计算"子码残差"分布，判断是否存在上溢或下溢。

```matlab
[range_min, range_max, ovf_percent_zero, ovf_percent_one] = bitchk(bits, wgt, chkpos, ...)
```

**核心概念**

- **子码残差**：从第 i 位到 LSB 的加权码值，归一化到 [0, 1]
- 残差 ≥ 1 → 上溢；残差 ≤ 0 → 下溢
- 图中蓝点 = 正常，红点 = 上溢，绿点 = 下溢
- 每位顶部/底部显示溢出百分比

**参数**

| 参数 | 默认 | 说明 |
|------|------|------|
| `wgt` | 二进制权重 | 各位权重 |
| `chkpos` | M（MSB） | 从哪一位开始检查溢出 |

---

### `plotres.m`

绘制 ADC 各阶段的**残差散点图**（residual vs residual），揭示阶段间相关性和非线性。

```matlab
plotres(sig, bits, wgt, xy, alpha)
```

- `sig`：理想输入信号（N×1）
- `bits`：ADC 输出位矩阵（N×M，MSB 列优先）
- `xy`：要绘制的位对列表，每行 `[x_bit, y_bit]`；0 表示原始输入信号
- 残差定义：`res_k = sig − bits(:,1:k) * wgt(1:k)'`
- 各子图显示 `res_y` vs `res_x`，理想情况下应为均匀散点

---

## 10. 综合分析面板

### `adcpanel.m`

一键输出 ADC 全套分析结果的综合仪表板，自动检测输入数据类型（模拟值/位矩阵）并调用相应分析流程。

```matlab
rep = adcpanel(dat, ...)
rep = adcpanel(dat, 'dataType', 'bits', 'OSR', 32, 'fs', 100e6)
```

**输入数据类型**

| `dataType` | 输入格式 | 触发的分析 |
|------------|----------|-----------|
| `'values'`（或自动） | N×1 模拟波形 | 频谱、相位谱、误差分析、OSR 扫描 |
| `'bits'` | N×M 位矩阵 | 以上全部 + 权重校准、INL/DNL、位流诊断 |

**主要 Name-Value 参数**

| 参数 | 说明 |
|------|------|
| `'signalType'` | `'sinewave'`（默认）或 `'other'`（仅基础频谱） |
| `'OSR'` | 过采样率 |
| `'fs'` | 采样率（Hz） |
| `'harmonic'` | 谐波阶数 |
| `'window'` | 窗函数类型 |

返回结构体 `rep` 包含所有计算结果（enob、sndr、sfdr、inl、dnl、weight 等）。

---

## 11. 工具函数

### `alias.m`

计算采样后信号的折叠频率（支持任意奈奎斯特区）。

```matlab
fal = alias(fin, fs)
```

**规则**

| 奈奎斯特区（0-indexed） | 类型 | 折叠规则 |
|------------------------|------|----------|
| 偶数区（0, 2, 4, …） | 正常混叠 | `fal = mod(fin, fs)` |
| 奇数区（1, 3, 5, …） | 镜像混叠 | `fal = fs − mod(fin, fs)` |

输出范围：[0, fs/2]。支持向量化输入。

---

### `ifilter.m`

理想砖墙滤波器（基于 FFT），保留指定频带内的频率分量。

```matlab
sigout = ifilter(sigin, passband)
```

- `passband`：P×2 矩阵，每行 `[fLow, fHigh]`（归一化到 Fs，范围 [0, 0.5]），多行取并集
- 维护 Hermitian 对称性（正负频率同步处理）
- 注意：砖墙特性会引起 Gibbs 振铃效应

**典型用途**：在 `errsin`、`plotphase`、`perfosr` 中提取带内噪声（OSR > 1 时）。

---

## 12. 快捷函数（`shortcut/`）

### `errsinv.m`

`errsin` 的 value 模式快捷封装：默认 `'xaxis', 'value'`，其余参数透传。

```matlab
[emean, erms, xx] = errsinv(sig, ...)
% 等价于：errsin(sig, 'xaxis', 'value', ...)
```

---

### `plotressin.m`

`wcalsin` + `plotres` 的组合封装：自动从正弦波位数据校准权重，再绘制残差图，省去手动调用 `wcalsin` 的步骤。

```matlab
plotressin(bits)
plotressin(bits, xy)
plotressin(bits, 'freq', 0.123, 'order', 3)
```

内部流程：
1. `[weight, offset, ~, ideal] = wcalsin(bits, ...)` 获取校准权重
2. `sig = ideal + offset` 重建参考信号
3. `plotres(sig, bits, weight, xy)` 绘图

---

## 13. 遗留函数（`legacy/`）

以下函数为早期实现，已被当前主函数取代，保留用于向后兼容。

| 旧函数 | 对应新函数 | 说明 |
|--------|-----------|------|
| `specPlot.m` | `plotspec.m` | 功率谱绘制 |
| `specPlotPhase.m` | `plotphase.m` | 相位谱绘制 |
| `INLsine.m` | `inlsin.m` | 正弦直方图 INL/DNL |
| `sineFit.m` | `sinfit.m` | 正弦拟合 |
| `findBin.m` | `findbin.m` | 相干 bin 搜索 |
| `findFin.m` | `findfreq.m` | 频率检测 |
| `cap2weight.m` | `cdacwgt.m` | CDAC 权重计算 |
| `weightScaling.m` | `plotwgt.m` 中的 `wgtsca` | 权重归一化 |
| `tomDecomp.m` | `tomdec.m` | Thompson 分解 |
| `FGCalSine.m` | `wcalsin.m` | 权重校准 |
| `NTFAnalyzer.m` | `ntfperf.m` | NTF 性能分析 |
| `overflowChk.m` | `bitchk.m` | 溢出检查 |
| `errHistSine.m` | `errsin.m` | 正弦误差直方图 |
| `bitact.m` | — | 位活动度分析 |
| `bitInBand.m` | — | 带内位分析 |
| `bitsweep.m` | — | 位扫描分析 |

---

## 函数调用关系速览

```
adcpanel
├── plotspec          ← 频谱 + 动态指标（核心）
│   └── alias
├── plotphase
│   ├── sinfit
│   └── ifilter
├── perfosr
│   └── sinfit
├── errsin
│   ├── sinfit
│   └── ifilter
├── inlsin
├── wcalsin
│   └── findfreq → sinfit
└── plotres / bitchk / plotwgt

plotressin  →  wcalsin + plotres
errsinv     →  errsin
cdacwgt     →  (独立)
ntfperf     →  (独立，依赖 Control System Toolbox)
tomdec      →  findfreq → sinfit
```

---

## 外部依赖说明

| 功能 | 是否需要外部 Toolbox |
|------|---------------------|
| `'hann'` / `'rect'` 窗 | **不需要**（内嵌实现） |
| `@blackman` 等函数句柄窗 | 需要 Signal Processing Toolbox |
| `ntfperf` | 需要 Control System Toolbox（`bode`） |
| 其余所有函数 | 不需要额外 Toolbox |
