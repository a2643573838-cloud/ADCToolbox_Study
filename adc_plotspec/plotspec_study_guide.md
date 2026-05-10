# plotspec.m 深度教学与示例包

本文档对应当前目录下的 `adc_plotspec`。它不是修改 ADCToolbox 原始文件，而是把 `plotspec.m` 和必要依赖 `alias.m` 复制到当前工程，配套示例数据和一键脚本，方便你边跑边读源码。

## 文件结构

```text
Noise-Shaping-SAR-ADC/
└─ adc_plotspec/
   ├─ plotspec.m
   ├─ alias.m
   ├─ plotspec_study_guide.md
   ├─ run_plotspec_examples.m
   ├─ generate_study_guide.ps1
   └─ data/
      ├─ coherent_10bit_sine.csv
      ├─ leaky_10bit_sine.csv
      ├─ multirun_10bit_sine.csv
      ├─ osr_noise_shaped_like.csv
      └─ metadata.csv
```

## 快速使用

在 MATLAB 中执行：

```matlab
cd('D:\Matlab\adc-modeling\Noise-Shaping-SAR-ADC\adc_plotspec')
run_plotspec_examples
```

只想自己调用一个数据文件：

```matlab
cd('D:\Matlab\adc-modeling\Noise-Shaping-SAR-ADC\adc_plotspec')
addpath(pwd)
Fs = 1e6;
maxCode = 2^10;
sig = readmatrix(fullfile('data', 'coherent_10bit_sine.csv'));
[enob, sndr, sfdr, snr, thd, sigpwr, noi, nsd] = plotspec(sig, Fs, maxCode, 5, 'window', 'hann');
```

如果不想画图，只想得到数值：

```matlab
[enob, sndr, sfdr] = plotspec(sig, Fs, maxCode, 5, 'disp', false);
```

## 输入数据怎么理解

`plotspec(sig, ...)` 的 `sig` 是 ADC 输出序列。它可以是列向量、行向量或矩阵。矩阵输入时，每一行是一轮采样，函数会对多轮频谱做平均。

示例数据采用 10-bit ADC 码值，范围大致是 `0` 到 `1023`。调用时使用 `maxCode = 2^10`，表示满量程范围。`plotspec` 内部会先减均值去 DC，再除以满量程，所以它关心的是交流信号相对满量程的大小。

## 关键指标

| 指标 | 含义 |
| --- | --- |
| `sigpwr` | 主信号功率，单位 dBFS。0 dBFS 对应满量程正弦。 |
| `sndr` | Signal-to-Noise-and-Distortion Ratio，信号对噪声加失真的比值。 |
| `snr` | Signal-to-Noise Ratio，信号对噪声的比值；这里的噪声可由不同 `NFMethod` 估计。 |
| `sfdr` | Spurious-Free Dynamic Range，主信号与最大杂散之间的距离。 |
| `thd` | Total Harmonic Distortion，谐波总功率相对主信号功率。 |
| `enob` | Effective Number of Bits，由 `ENOB = (SNDR - 1.76)/6.02` 得到。 |
| `nsd` | Noise Spectral Density，把噪声归一化到 1 Hz 后的 dBFS/Hz。 |

## 新手必须先懂的频谱概念

FFT 把时域采样序列变成频域 bin。第 `k` 个 bin 对应频率大约是 `k/N*Fs`。如果输入正弦在 FFT 记录中刚好包含整数个周期，能量会集中在一个 bin 附近，这叫相干采样。如果不是整数周期，能量会扩散到很多 bin，这叫频谱泄漏。

窗函数是在 FFT 前给时域数据乘一个权重。矩形窗等于不加窗，适合严格相干采样；Hann 窗能压低旁瓣，适合非相干采样，但主瓣会变宽，所以 `plotspec` 需要把主峰左右若干 bin 一起算作信号功率。

OSR 是过采样比。普通 Nyquist ADC 的信号带宽是 `Fs/2`；OSR 为 16 时，`plotspec` 只把 `0` 到 `Fs/(2*16)` 当作带内区域。噪声整形 ADC 的高频噪声可能很高，但只要带内噪声低，带内 SNR 仍然好。

谐波会发生别名折叠。例如采样率为 100 Hz，70 Hz 的信号采样后会折叠到 30 Hz。ADC 失真谐波也一样：如果 3 阶、5 阶谐波超过 Nyquist，它们仍会折回频谱内。因此 `plotspec.m` 依赖 `alias.m` 找到谐波折叠后的位置。

## `plotspec.m` 的总体算法

1. 解析输入参数，兼容旧参数名和新参数名。
2. 把输入信号整理成“每行一次运行”的矩阵形式。
3. 生成窗函数，对每次运行执行归一化、去 DC、乘窗和 FFT。
4. 若普通平均，累加功率谱；若相干平均，先按基波相位旋转复频谱再累加。
5. 截取单边频谱，并按 OSR 得到带内频谱。
6. 找主峰 bin，用抛物线插值估计更精确的输入频率。
7. 自动或手动决定主信号左右要合并多少个 side bin。
8. 对主信号功率积分，清除主信号后计算 SNDR、SFDR、噪声、THD、SNR、ENOB。
9. 根据 `dispItem` 画频谱、主峰、谐波、最大杂散、带宽线和指标文字。
10. 返回数值指标和图形句柄。

## `alias.m` 为什么是必要依赖

`plotspec.m` 有多处需要找谐波位置：谐波标注、THD 计算、谐波剔除、负 `harmonic` 模式。谐波频率可能超过 Nyquist，因此不能简单用 `i*Fin` 对应的位置。`alias.m` 的作用就是把任意频率或 bin 折叠回 `[0, Fs/2]`。在本示例包中复制 `alias.m` 是为了保证 `plotspec.m` 离开 ADCToolbox 原始路径后仍能独立运行。

快速验证：

```matlab
alias([30 70 130], 100)
```

输出应为 `[30 30 30]`。30 Hz 本来就在第一 Nyquist 带；70 Hz 在 50 到 100 Hz 之间，会镜像到 30 Hz；130 Hz 超过一个采样周期后也折回 30 Hz。

## 示例数据说明

| 文件 | 用途 | 建议调用 |
| --- | --- | --- |
| `coherent_10bit_sine.csv` | 整数 bin 正弦，适合观察理想量化噪声和 ENOB | `plotspec(sig, 1e6, 2^10, 5, 'window', 'rect')` |
| `leaky_10bit_sine.csv` | 非整数 bin 正弦，适合观察泄漏和 Hann 窗作用 | `plotspec(sig, 1e6, 2^10, 5, 'window', 'hann')` |
| `multirun_10bit_sine.csv` | 8 行多次运行数据，适合比较普通平均和相干平均 | `plotspec(sig, 1e6, 2^10, 5, 'averageMode', 'coherent')` |
| `osr_noise_shaped_like.csv` | 带高频整形噪声的过采样示例 | `plotspec(sig, 1e6, 2^10, 5, 'OSR', 16)` |

## 常用参数选择建议

- 相干采样、整数周期正弦：优先试 `window='rect'` 和 `sideBin=0`。
- 非相干采样或真实仿真数据：优先试 `window='hann'` 和 `sideBin='auto'`。
- 噪声整形 ADC：务必设置真实 `OSR`，否则高频整形噪声会被算入带内噪声。
- 只想批量统计指标：设置 `'disp', false`，不要频繁画图。
- 噪底不平坦或有明显 spur：比较 `NFMethod='median'/'mean'/'exclude'`，不要盲信一个数。
- 用函数句柄窗如 `@blackman`：可能需要 Signal Processing Toolbox；本文件内置的 `'hann'` 和 `'rect'` 不需要该工具箱。

## 函数、循环和分支重点拆解

### 输入解析 `inputParser`

`plotspec` 同时支持老参数名和新参数名。比如 `winType` 是旧名，`window` 是新名；`isPlot` 是旧名，`disp` 是新名。源码的策略是：如果新版参数不是默认值，就用新版；否则回退到旧版。这让旧脚本能跑，也鼓励新脚本用更清楚的参数名。

### 外层 `for iter = 1:N_run`

这个循环逐行读取输入矩阵。单行数据就是一次 FFT；多行数据就是多次采样运行。普通平均时，它累加每行的功率谱。相干平均时，它累加相位对齐后的复数谱。区别很重要：功率平均降低随机波动，但不会让信号相干增强；相干平均会让相同相位参考下的信号叠加更强，噪声相对下降。

### 相干平均中的两个内层循环

第一个 `for iter2 = 1:N_fft` 按谐波关系处理基波和谐波 bin，并考虑 Nyquist 区奇偶导致的镜像折叠。第二个 `for iter2 = 1:N_fft` 处理非谐波 bin，使整条频谱都按基波相位连续旋转。这部分是文件中最难的代码：它不是简单地把 FFT 乘一个常数，而是让不同频率 bin 按相对频率比例获得不同相位校正。

### 自动 `sideBin` 检测循环

`sideBin='auto'` 时，函数会合成一个同频率、同窗函数的理想正弦，计算它的理想泄漏主瓣，再与实际噪底比较。循环从主峰向左右搜索，找到理想泄漏低于噪底的位置。这样做的目的，是把“属于主信号泄漏主瓣的能量”算进信号，而不要误算成噪声。

### 噪底估计方法

`NFMethod='median'` 用中位数估计每 bin 噪声，对 spur 稳健。`NFMethod='mean'` 用截尾均值，适合噪声较平坦但有少量异常点。`NFMethod='exclude'` 先把谐波清掉再求和，适合谐波明显但随机噪声需要单独估计的场景。`auto` 取三者中位数，并在差异过大时警告。

### `alias` 谐波折叠

THD 和谐波标注都不能只看 `2*Fin`、`3*Fin` 的原始频率，因为采样后超过 Nyquist 的频率会折回。`alias(round((bin_r-1)*i), N_fft)` 的意思是：把第 `i` 阶谐波的未折叠 bin 编号折叠回 FFT 频谱可见范围。


## `plotspec.m` 逐行解析

下表按复制到示例包中的 `plotspec.m` 真实行号展开。代码列保留原行内容；解释列说明 MATLAB 语法作用和信号处理意义。

| 行号 | 代码 | 解释 |
| ---: | --- | --- |
| 1 | `function [enob,sndr,sfdr,snr,thd,sigpwr,noi,nsd,h] = plotspec(sig,varargin)` | 定义主函数、9 个输出指标和输入 `sig,varargin`；`varargin` 让函数接受可变数量的位置参数和 Name-Value 参数。 |
| 2 | `%PLOTSPEC Plot power spectrum and calculate ADC performance metrics` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 3 | `%   This function performs spectral analysis on ADC data and calculates key` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 4 | `%   performance metrics including ENOB, SNDR, SFDR, SNR, and THD. It supports` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 5 | `%   various windowing functions, oversampling ratio (OSR), coherent averaging,` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 6 | `%   and customizable plotting options.` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 7 | `%` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 8 | `%   Syntax:` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 9 | `%     [enob,sndr,sfdr,snr,thd,sigpwr,noi,nsd,h] = PLOTSPEC(sig)` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 10 | `%     [enob,sndr,sfdr,snr,thd,sigpwr,noi,nsd,h] = PLOTSPEC(sig, Fs)` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 11 | `%     [enob,sndr,sfdr,snr,thd,sigpwr,noi,nsd,h] = PLOTSPEC(sig, Fs, maxCode)` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 12 | `%     [enob,sndr,sfdr,snr,thd,sigpwr,noi,nsd,h] = PLOTSPEC(sig, Fs, maxCode, harmonic)` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 13 | `%     [enob,sndr,sfdr,snr,thd,sigpwr,noi,nsd,h] = PLOTSPEC(sig, 'Name', Value)` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 14 | `%` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 15 | `%   Inputs:` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 16 | `%     sig - Signal to be plot, typically the ADC's output data` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 17 | `%       Vector or Matrix (N_run x N_fft)` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 18 | `%       Each row represents a separate measurement run for averaging` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 19 | `%` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 20 | `%   Optional Positional Inputs:` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 21 | `%     Fs - Sampling frequency in Hz. Default: 1` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 22 | `%       Scalar, positive real number` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 23 | `%     maxCode - Full scale range (max-min). Default: max(sig)-min(sig)` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 24 | `%       Scalar, positive real number` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 25 | `%     harmonic - Number of harmonics to analyze. Default: 5` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 26 | `%       Scalar, positive integer` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 27 | `%       Set negative to exclude harmonics from noise calculation` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 28 | `%` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 29 | `%   Name-Value Parameters:` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 30 | `%     'OSR' - Oversampling ratio. Default: 1 (no oversampling)` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 31 | `%       Scalar, positive real number` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 32 | `%       Defines signal bandwidth as Fs/(2*OSR)` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 33 | `%     'window' - Window function. Default: 'hann'` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 34 | `%       String: 'hann' (Hanning window) or 'rect' (Rectangle window)` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 35 | `%       Function handle: e.g., @hann, @blackman, @rectwin (requires Signal Processing Toolbox)` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 36 | `%       Alias: 'winType' (deprecated, use 'window')` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 37 | `%     'maxSignal' - Full scale range (max-min). Default: max(sig)-min(sig)` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 38 | `%       Scalar, positive real number` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 39 | `%       Alias: 'maxCode' (deprecated, use 'maxSignal')` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 40 | `%     'sideBin' - Number of extra bins to include on each side of signal peak. Default: 'auto'` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 41 | `%       Scalar, non-negative integer or string 'auto'` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 42 | `%       Total signal bins = 1 + 2*sideBin (center peak + sideBin on each side)` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 43 | `%       'auto': Automatically detects sideBin by simulating ideal spectral leakage with the` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 44 | `%               same window function and finding where it crosses the noise floor` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 45 | `%               Adapts to window type (hann, rect, blackman, etc.) and noise characteristics` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 46 | `%       Convention: sideBin = 1 for Hanning window if signal is coherent` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 47 | `%     'label' - Enable plot annotations. Default: true` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 48 | `%       Logical (true/false) or numeric (0/1)` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 49 | `%     'assumedSignal' - Override signal power in dB. Default: NaN` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 50 | `%       Scalar, real number or NaN` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 51 | `%     'disp' - Enable plotting. Default: true` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 52 | `%       Logical (true/false) or numeric (0/1)` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 53 | `%       Alias: 'isPlot' (deprecated, use 'disp')` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 54 | `%     'cutoff' - High-pass cutoff frequency for low-frequency noise removal in Hz. Default: 0` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 55 | `%       Scalar, non-negative real number` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 56 | `%       Alias: 'noFlicker' (deprecated, use 'cutoff')` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 57 | `%     'nTHD' - Number of harmonics for THD calculation. Default: 5` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 58 | `%       Scalar, positive integer` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 59 | `%     'averageMode' - Averaging mode. Default: 'normal'` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 60 | `%       String: 'normal' (power averaging), 'coherent' (coherent averaging with phase alignment)` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 61 | `%       Number: 0 (normal), 1 (coherent)` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 62 | `%       Alias: 'coAvg' (deprecated, use 'averageMode')` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 63 | `%     'NFMethod' - Noise floor estimation method. Default: 'auto'` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 64 | `%       String: 'auto' (median of all methods), 'median' (median-based), 'mean' (trimmed mean), 'exclude' (exclude harmonics)` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 65 | `%       Number: 0 (auto), 1 (median-based), 2 (trimmed mean), 3 (exclude harmonics)` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 66 | `%     'dispItem' - Display items selector. Default: 'sfedutrlyhop' (all items)` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 67 | `%       String or char array where each character (case insensitive) enables a display item:` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 68 | `%       's' - Signal power text and signal bin marker` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 69 | `%       'f' - Input frequency and sampling frequency (Fin/Fs)` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 70 | `%       'e' - Effective Number of Bits (ENOB)` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 71 | `%       'd' - Signal-to-Noise and Distortion Ratio (SNDR)` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 72 | `%       'u' - Spurious-Free Dynamic Range (SFDR)` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 73 | `%       't' - Total Harmonic Distortion (THD)` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 74 | `%       'r' - Signal-to-Noise Ratio (SNR)` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 75 | `%       'l' - Noise floor level` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 76 | `%       'y' - Noise Spectral Density (NSD) and horizontal dash line` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 77 | `%       'o' - Oversampling Ratio (OSR) and vertical bandwidth line` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 78 | `%       'h' - Harmonic markers` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 79 | `%       'p' - Maximum spur marker` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 80 | `%` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 81 | `%   Outputs:` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 82 | `%     enob - Effective Number of Bits` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 83 | `%       Scalar, real number` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 84 | `%       Calculated as (sndr-1.76)/6.02` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 85 | `%     sndr - Signal-to-Noise and Distortion Ratio in dB` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 86 | `%       Scalar, real number` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 87 | `%     sfdr - Spurious-Free Dynamic Range in dB` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 88 | `%       Scalar, real number` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 89 | `%     snr - Signal-to-Noise Ratio in dB` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 90 | `%       Scalar, real number` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 91 | `%     thd - Total Harmonic Distortion in dB` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 92 | `%       Scalar, real number` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 93 | `%     sigpwr - Signal power in dBFS` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 94 | `%       Scalar, real number` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 95 | `%     noi - Noise Floor in dB` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 96 | `%       Scalar, real number` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 97 | `%     nsd - Noise Spectral Density in dBFS/Hz` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 98 | `%       Scalar, real number` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 99 | `%     h - Plot handle or empty array if disp=false` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 100 | `%       Graphics handle or []` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 101 | `%` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 102 | `%   Examples:` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 103 | `%     % Basic usage with default parameters (uses built-in Hanning window)` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 104 | `%     [enob,sndr,sfdr] = plotspec(sig);` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 105 | `%` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 106 | `%     % Specify sampling frequency and full scale` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 107 | `%     [enob,sndr,sfdr] = plotspec(sig, 100e6, 2^16);` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 108 | `%` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 109 | `%     % Use oversampling with rectangle window (no toolbox required)` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 110 | `%     [enob,sndr,sfdr] = plotspec(sig, 'OSR', 32, 'window', 'rect');` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 111 | `%` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 112 | `%     % Use other window functions (requires Signal Processing Toolbox)` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 113 | `%     [enob,sndr,sfdr] = plotspec(sig, 'OSR', 32, 'window', @blackman);` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 114 | `%` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 115 | `%     % Use trimmed mean for noise floor estimation` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 116 | `%     [enob,sndr,sfdr] = plotspec(sig, 'NFMethod', 'mean');` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 117 | `%` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 118 | `%     % Multiple runs with coherent averaging` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 119 | `%     sig = ones(10,1)*sin(2*pi*0.1*(0:1023)) + randn(10, 1024)*0.01; % 10 runs of 1024 samples` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 120 | `%     [enob,sndr,sfdr] = plotspec(sig, 'averageMode', 'coherent');` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 121 | `%` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 122 | `%     % Disable plotting and use assumed signal power` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 123 | `%     [enob,sndr,sfdr] = plotspec(sig, 'disp', false, 'assumedSignal', -3);` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 124 | `%` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 125 | `%   Notes:` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 126 | `%     - Signal can be provided as a row vector, column vector, or matrix` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 127 | `%     - For matrix input, each row is treated as a separate measurement` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 128 | `%     - The FFT length is determined by the number of columns (or rows if column vector)` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 129 | `%     - Coherent averaging ('coAvg') aligns phase before averaging to lower noise floor` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 130 | `%     - The noise floor is calculated within the signal band [0, Fs/(2*OSR)]` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 131 | `%     - Setting harmonic &lt; 0 removes harmonics from both the analysis and display` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 132 | `%     - dBFS = 0 referred to a full-scale sinewave signal` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 133 | `%     - Built-in windows ('hann', 'rect') do not require Signal Processing Toolbox` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 134 | `%     - Custom window function handles (e.g., @blackman) require Signal Processing Toolbox` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 135 | `%` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 136 | `%   See also: alias, sinfit, fft, window` | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 137 | <空行> | 函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。 |
| 138 | `% Input parsing and validation` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 139 | `p = inputParser;` | 创建 MATLAB 的输入解析器对象；它负责读取 `varargin` 并检查每个参数是否合法。 |
| 140 | `validScalarPosNum = @(x) isnumeric(x) &amp;&amp; isscalar(x) &amp;&amp; (x &gt; 0);` | 定义匿名校验函数：要求输入是数值、标量且大于 0，适用于采样率、OSR、满量程等正数参数。 |
| 141 | `validScalarPosInt = @(x) isnumeric(x) &amp;&amp; isscalar(x) &amp;&amp; (x &gt; 0) &amp;&amp; (mod(x,1) == 0);` | 定义正整数校验函数：用于谐波数量、THD 阶数等必须为整数的参数。 |
| 142 | `validInteger = @(x) isnumeric(x) &amp;&amp; isscalar(x) &amp;&amp; (mod(x,1) == 0);` | 定义整数校验函数：允许正负整数，因此 `harmonic < 0` 可作为特殊模式。 |
| 143 | `validWindow = @(x) (ischar(x) &amp;&amp; ismember(x, {'hann', 'rect'})) \|\| isa(x, 'function_handle');` | 定义窗函数参数的合法形式：字符串 `hann/rect` 或函数句柄，例如 `@blackman`。 |
| 144 | `validNFMethod = @(x) (isnumeric(x) &amp;&amp; ismember(x, [0, 1, 2, 3])) \|\| (ischar(x) &amp;&amp; ismember(x, {'auto', 'median', 'mean', 'exclude'}));` | 定义噪底估计方法的合法取值；既兼容数字编码，也支持可读字符串。 |
| 145 | `validAvgMode = @(x) (isnumeric(x) &amp;&amp; ismember(x, [0, 1])) \|\| (ischar(x) &amp;&amp; ismember(x, {'normal', 'coherent'}));` | 定义平均模式的合法取值；`normal` 表示功率平均，`coherent` 表示相干平均。 |
| 146 | `validLogical = @(x) islogical(x) \|\| (isnumeric(x) &amp;&amp; ismember(x, [0, 1]));` | 定义逻辑参数校验函数；允许 `true/false`，也允许 `0/1`。 |
| 147 | `addOptional(p, 'Fs', 1, validScalarPosNum);` | 注册可选位置参数 `Fs`，默认采样率为 1 Hz；实际 ADC 数据通常要显式传入真实采样率。 |
| 148 | `addOptional(p, 'maxCode', max(max(sig))-min(min(sig)), validScalarPosNum);` | 注册可选位置参数 `maxCode`，默认取输入最大值减最小值；它用于把 ADC 输出归一化到满量程。 |
| 149 | `addOptional(p, 'harmonic', 5, validInteger);` | 注册可选位置参数 `harmonic`，默认分析 5 阶谐波；负数有“从噪声中排除谐波”的特殊含义。 |
| 150 | `addParameter(p, 'OSR', 1, validScalarPosNum);` | 注册一个 Name-Value 参数及其默认值和校验规则；这是函数接口灵活性的来源。 |
| 151 | `% Old parameter names (for backward compatibility)` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 152 | `addParameter(p, 'winType', 'hann', validWindow);` | 注册一个 Name-Value 参数及其默认值和校验规则；这是函数接口灵活性的来源。 |
| 153 | `addParameter(p, 'isPlot', true, validLogical);` | 注册一个 Name-Value 参数及其默认值和校验规则；这是函数接口灵活性的来源。 |
| 154 | `addParameter(p, 'noFlicker', 0, validScalarPosNum);` | 注册一个 Name-Value 参数及其默认值和校验规则；这是函数接口灵活性的来源。 |
| 155 | `addParameter(p, 'coAvg', 0, @(x)ismember(x, [0, 1]));` | 注册一个 Name-Value 参数及其默认值和校验规则；这是函数接口灵活性的来源。 |
| 156 | `% New parameter names (aliases with higher priority)` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 157 | `addParameter(p, 'window', 'hann', validWindow);` | 注册一个 Name-Value 参数及其默认值和校验规则；这是函数接口灵活性的来源。 |
| 158 | `addParameter(p, 'maxSignal', NaN, validScalarPosNum);` | 注册一个 Name-Value 参数及其默认值和校验规则；这是函数接口灵活性的来源。 |
| 159 | `addParameter(p, 'disp', NaN, validLogical);` | 注册一个 Name-Value 参数及其默认值和校验规则；这是函数接口灵活性的来源。 |
| 160 | `addParameter(p, 'cutoff', 0, validScalarPosNum);` | 注册一个 Name-Value 参数及其默认值和校验规则；这是函数接口灵活性的来源。 |
| 161 | `addParameter(p, 'averageMode', 'normal', validAvgMode);` | 注册一个 Name-Value 参数及其默认值和校验规则；这是函数接口灵活性的来源。 |
| 162 | `% Other parameters` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 163 | `addParameter(p, 'sideBin', 'auto', @(x) (isnumeric(x) &amp;&amp; isscalar(x) &amp;&amp; (x &gt;= 0)) \|\| (ischar(x) &amp;&amp; strcmp(x, 'auto')));` | 注册一个 Name-Value 参数及其默认值和校验规则；这是函数接口灵活性的来源。 |
| 164 | `addParameter(p, 'label', true, validLogical);` | 注册一个 Name-Value 参数及其默认值和校验规则；这是函数接口灵活性的来源。 |
| 165 | `addParameter(p, 'assumedSignal', NaN);` | 注册一个 Name-Value 参数及其默认值和校验规则；这是函数接口灵活性的来源。 |
| 166 | `addParameter(p, 'nTHD', 5, validScalarPosInt);` | 注册一个 Name-Value 参数及其默认值和校验规则；这是函数接口灵活性的来源。 |
| 167 | `addParameter(p, 'NFMethod', 'auto', validNFMethod);` | 注册一个 Name-Value 参数及其默认值和校验规则；这是函数接口灵活性的来源。 |
| 168 | `addParameter(p, 'dispItem', 'sfedutrlyhop', @(x) ischar(x) \|\| isstring(x));` | 注册一个 Name-Value 参数及其默认值和校验规则；这是函数接口灵活性的来源。 |
| 169 | `parse(p, varargin{:});` | 实际解析用户传入的 `varargin`；若参数不合法，会在这里报错。 |
| 170 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 171 | `% Extract parsed parameters` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 172 | `Fs = p.Results.Fs;` | 从解析器结果中取出参数，保存为后续算法直接使用的局部变量。 |
| 173 | `harmonic = p.Results.harmonic;` | 从解析器结果中取出参数，保存为后续算法直接使用的局部变量。 |
| 174 | `OSR = p.Results.OSR;` | 从解析器结果中取出参数，保存为后续算法直接使用的局部变量。 |
| 175 | `sideBin = p.Results.sideBin;` | 从解析器结果中取出参数，保存为后续算法直接使用的局部变量。 |
| 176 | `label = logical(p.Results.label);` | 从解析器结果中取出参数，保存为后续算法直接使用的局部变量。 |
| 177 | `assumedSignal = p.Results.assumedSignal;` | 从解析器结果中取出参数，保存为后续算法直接使用的局部变量。 |
| 178 | `nTHD = p.Results.nTHD;` | 从解析器结果中取出参数，保存为后续算法直接使用的局部变量。 |
| 179 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 180 | `% Convert NFMethod from string to numeric if needed` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 181 | `if ischar(p.Results.NFMethod)` | 判断噪底估计方法是否以字符串给出；若是字符串则转换成内部数字编码。 |
| 182 | `    switch p.Results.NFMethod` | 按噪底方法字符串进入分支转换。 |
| 183 | `        case 'auto'` | 匹配一种噪底估计方法字符串，并在下一行赋予对应数字编码。 |
| 184 | `            nfmethod = 0;` | 设置内部噪底估计方法编号：0=auto，1=median，2=mean，3=exclude。 |
| 185 | `        case 'median'` | 匹配一种噪底估计方法字符串，并在下一行赋予对应数字编码。 |
| 186 | `            nfmethod = 1;` | 设置内部噪底估计方法编号：0=auto，1=median，2=mean，3=exclude。 |
| 187 | `        case 'mean'` | 匹配一种噪底估计方法字符串，并在下一行赋予对应数字编码。 |
| 188 | `            nfmethod = 2;` | 设置内部噪底估计方法编号：0=auto，1=median，2=mean，3=exclude。 |
| 189 | `        case 'exclude'` | 匹配一种噪底估计方法字符串，并在下一行赋予对应数字编码。 |
| 190 | `            nfmethod = 3;` | 设置内部噪底估计方法编号：0=auto，1=median，2=mean，3=exclude。 |
| 191 | `    end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 192 | `else` | 条件分支的兜底路径：前面条件都不满足时执行。 |
| 193 | `    nfmethod = p.Results.NFMethod;` | 设置内部噪底估计方法编号：0=auto，1=median，2=mean，3=exclude。 |
| 194 | `end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 195 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 196 | `% Handle aliased parameters (new names override old names)` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 197 | `% averageMode/coAvg` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 198 | `if ~isequal(p.Results.averageMode, 'normal')` | 检查新版 `averageMode` 是否被用户显式设置；新版参数优先于旧版 `coAvg`。 |
| 199 | `    % New name has priority if not default` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 200 | `    if ischar(p.Results.averageMode)` | 判断平均模式是否以字符串给出；字符串需要转换成数字开关。 |
| 201 | `        switch p.Results.averageMode` | 根据平均模式字符串选择普通平均或相干平均。 |
| 202 | `            case 'normal'` | 执行当前代码块中的一步具体计算或绘图操作；建议结合本表前后行和上方算法章节理解其输入、输出和副作用。 |
| 203 | `                coAvg = 0;` | 关闭相干平均，使用普通功率谱平均。 |
| 204 | `            case 'coherent'` | 执行当前代码块中的一步具体计算或绘图操作；建议结合本表前后行和上方算法章节理解其输入、输出和副作用。 |
| 205 | `                coAvg = 1;` | 开启相干平均，后续会先对齐相位再累加 FFT。 |
| 206 | `        end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 207 | `    else` | 条件分支的兜底路径：前面条件都不满足时执行。 |
| 208 | `        coAvg = p.Results.averageMode;` | 确定最终相干平均开关；新版参数默认时会回退到旧参数。 |
| 209 | `    end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 210 | `else` | 条件分支的兜底路径：前面条件都不满足时执行。 |
| 211 | `    % Fall back to old name` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 212 | `    coAvg = p.Results.coAvg;` | 确定最终相干平均开关；新版参数默认时会回退到旧参数。 |
| 213 | `end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 214 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 215 | `% maxSignal/maxCode` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 216 | `if ~isnan(p.Results.maxSignal)` | 判断用户是否设置新版满量程 `maxSignal`；若设置则覆盖位置参数 `maxCode`。 |
| 217 | `    maxSignal = p.Results.maxSignal;  % New name has priority` | 确定用于归一化 ADC 数据的满量程范围。 |
| 218 | `else` | 条件分支的兜底路径：前面条件都不满足时执行。 |
| 219 | `    maxSignal = p.Results.maxCode;  % Fall back to old name` | 确定用于归一化 ADC 数据的满量程范围。 |
| 220 | `end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 221 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 222 | `% window/winType - use windowFunc as internal variable to avoid shadowing built-in` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 223 | `if ~isequal(p.Results.window, 'hann')` | 判断新版窗函数参数是否被显式设置；新版 `window` 优先于旧版 `winType`。 |
| 224 | `    windowFunc = p.Results.window;  % New name has priority if not default` | 确定实际使用的窗函数，避免变量名直接叫 `window` 而遮蔽 MATLAB 内置函数。 |
| 225 | `else` | 条件分支的兜底路径：前面条件都不满足时执行。 |
| 226 | `    windowFunc = p.Results.winType;  % Fall back to old name` | 确定实际使用的窗函数，避免变量名直接叫 `window` 而遮蔽 MATLAB 内置函数。 |
| 227 | `end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 228 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 229 | `% disp/isPlot - convert to logical` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 230 | `if ~(isnumeric(p.Results.disp) &amp;&amp; isnan(p.Results.disp))` | 判断新版绘图开关 `disp` 是否被设置。 |
| 231 | `    dispPlot = logical(p.Results.disp);  % New name has priority, convert to logical` | 把绘图开关转换成逻辑值，决定后面是否调用 `plot/semilogx`。 |
| 232 | `else` | 条件分支的兜底路径：前面条件都不满足时执行。 |
| 233 | `    dispPlot = logical(p.Results.isPlot);  % Fall back to old name, convert to logical` | 把绘图开关转换成逻辑值，决定后面是否调用 `plot/semilogx`。 |
| 234 | `end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 235 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 236 | `% cutoff/noFlicker` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 237 | `if p.Results.cutoff &gt; 0` | 若新版 `cutoff` 大于 0，则使用它作为低频剔除截止频率。 |
| 238 | `    cutoffFreq = p.Results.cutoff;  % New name has priority` | 确定最终使用的低频噪声截止频率。 |
| 239 | `else` | 条件分支的兜底路径：前面条件都不满足时执行。 |
| 240 | `    cutoffFreq = p.Results.noFlicker;  % Fall back to old name` | 确定最终使用的低频噪声截止频率。 |
| 241 | `end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 242 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 243 | `% Parse dispItem flags` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 244 | `dispItem = lower(char(p.Results.dispItem));` | 把显示项目字符串转换成小写字符数组，后续逐字符判断要显示哪些标注。 |
| 245 | `show_s = any(dispItem == 's');` | 生成一个显示开关；对应 `dispItem` 中的某个字符，控制图上某类文本或标记是否出现。 |
| 246 | `show_f = any(dispItem == 'f');` | 生成一个显示开关；对应 `dispItem` 中的某个字符，控制图上某类文本或标记是否出现。 |
| 247 | `show_e = any(dispItem == 'e');` | 生成一个显示开关；对应 `dispItem` 中的某个字符，控制图上某类文本或标记是否出现。 |
| 248 | `show_d = any(dispItem == 'd');` | 生成一个显示开关；对应 `dispItem` 中的某个字符，控制图上某类文本或标记是否出现。 |
| 249 | `show_u = any(dispItem == 'u');` | 生成一个显示开关；对应 `dispItem` 中的某个字符，控制图上某类文本或标记是否出现。 |
| 250 | `show_t = any(dispItem == 't');` | 生成一个显示开关；对应 `dispItem` 中的某个字符，控制图上某类文本或标记是否出现。 |
| 251 | `show_r = any(dispItem == 'r');` | 生成一个显示开关；对应 `dispItem` 中的某个字符，控制图上某类文本或标记是否出现。 |
| 252 | `show_l = any(dispItem == 'l');` | 生成一个显示开关；对应 `dispItem` 中的某个字符，控制图上某类文本或标记是否出现。 |
| 253 | `show_y = any(dispItem == 'y');` | 生成一个显示开关；对应 `dispItem` 中的某个字符，控制图上某类文本或标记是否出现。 |
| 254 | `show_o = any(dispItem == 'o');` | 生成一个显示开关；对应 `dispItem` 中的某个字符，控制图上某类文本或标记是否出现。 |
| 255 | `show_h = any(dispItem == 'h');` | 生成一个显示开关；对应 `dispItem` 中的某个字符，控制图上某类文本或标记是否出现。 |
| 256 | `show_p = any(dispItem == 'p');` | 生成一个显示开关；对应 `dispItem` 中的某个字符，控制图上某类文本或标记是否出现。 |
| 257 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 258 | `% Determine data dimensions and FFT length` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 259 | `% Convert column vector to row vector if needed` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 260 | `[N,M] = size(sig);` | 读取输入信号矩阵尺寸；`N` 是行数，`M` 是列数。 |
| 261 | `N_fft = M;` | 默认把列数作为 FFT 长度；矩阵输入时每一行是一次采样记录。 |
| 262 | `if(M==1 &amp;&amp; N &gt; 1)` | 检测列向量输入；若用户传入列向量，需要转成行向量以统一后续处理。 |
| 263 | `    sig = sig';` | 把列向量转置成行向量。 |
| 264 | `    N_fft = N;` | 列向量转置后，原行数才是真正的 FFT 长度。 |
| 265 | `end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 266 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 267 | `[N_run,~] = size(sig);` | 得到运行次数；单行是一次运行，多行表示多次测量可用于平均。 |
| 268 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 269 | `% Calculate number of positive frequency bins` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 270 | `Nd2 = floor(N_fft/2)+1;` | 计算单边频谱点数；实信号 FFT 只需要 DC 到 Nyquist 的正频率部分。 |
| 271 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 272 | `% Generate frequency axis` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 273 | `freq = (0:(Nd2-1))/N_fft*Fs;` | 生成频率坐标轴，把 FFT bin 编号换算成 Hz。 |
| 274 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 275 | `% Generate window function` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 276 | `if ischar(windowFunc)` | 判断窗函数是否用内置字符串形式指定。 |
| 277 | `    % Use embedded window functions (no toolbox required)` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 278 | `    if strcmp(windowFunc, 'hann')` | 选择内置 Hann 窗；它能降低泄漏旁瓣，但会展宽主瓣。 |
| 279 | `        win = hannwin(N_fft);` | 调用文件末尾的嵌套 Hann 窗函数生成窗向量。 |
| 280 | `    elseif strcmp(windowFunc, 'rect')` | 条件分支：前面的 `if` 不满足时，继续检查本条件。 |
| 281 | `        win = rectwin_emb(N_fft);` | 调用文件末尾的嵌套矩形窗函数生成全 1 窗向量。 |
| 282 | `    else` | 条件分支的兜底路径：前面条件都不满足时执行。 |
| 283 | `        win = rectwin_emb(N_fft);` | 调用文件末尾的嵌套矩形窗函数生成全 1 窗向量。 |
| 284 | `        warning("Unsupported window type '%s', using rectangle window", windowFunc);` | 当字符串窗函数不受支持时发出警告，并退回矩形窗。 |
| 285 | `    end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 286 | `else` | 条件分支的兜底路径：前面条件都不满足时执行。 |
| 287 | `    % Use function handle (requires Signal Processing Toolbox)` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 288 | `    try` | 进入容错调用；如果当前调用方式失败，会进入 `catch` 尝试备用方式。 |
| 289 | `        win = window(windowFunc,N_fft,'periodic')';` | 调用 MATLAB `window` 生成周期窗；这通常依赖 Signal Processing Toolbox。 |
| 290 | `    catch` | 捕获上一段尝试中的错误，避免函数直接中断。 |
| 291 | `        try` | 进入容错调用；如果当前调用方式失败，会进入 `catch` 尝试备用方式。 |
| 292 | `            win = window(windowFunc,N_fft)';` | 若周期窗语法失败，尝试不带 `periodic` 的通用窗函数调用。 |
| 293 | `        catch` | 捕获上一段尝试中的错误，避免函数直接中断。 |
| 294 | `            win = rectwin_emb(N_fft);` | 调用文件末尾的嵌套矩形窗函数生成全 1 窗向量。 |
| 295 | `            warning("Unsupported window function, using rectangle window");` | 函数句柄窗也无法生成时提示用户，并退回矩形窗。 |
| 296 | `        end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 297 | `    end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 298 | `end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 299 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 300 | `% Initialize spectrum accumulator and measurement counter` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 301 | `spec = zeros([1,N_fft]);` | 初始化完整双边频谱累加器；普通平均累加功率，相干平均累加复数 FFT。 |
| 302 | `ME = 0;` | 初始化有效测量次数计数器；全零数据会被跳过。 |
| 303 | `for iter = 1:N_run` | 外层循环逐行处理每次测量；多行输入时每一行独立做 FFT 后再平均。 |
| 304 | `    tdata = sig(iter,:);` | 取出当前一次运行的时域数据。 |
| 305 | `    % Skip empty data` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 306 | `    if(rms(tdata)==0)` | 检查当前数据是否全零；全零记录没有频谱意义。 |
| 307 | `        continue;` | 跳过当前循环剩余步骤，进入下一次迭代。 |
| 308 | `    end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 309 | `    % Normalize to full scale, remove DC, and apply window` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 310 | `    tdata = tdata./maxSignal;` | 把 ADC 码值除以满量程，换成相对满量程单位，为 dBFS 归一化做准备。 |
| 311 | `    tdata = tdata-mean(tdata);` | 去掉直流分量；频谱分析通常关注交流输入信号和噪声失真。 |
| 312 | `    tdata = tdata.*win/sqrt(mean(win.^2));` | 乘窗并按窗 RMS 做能量归一化，避免窗函数改变总体噪声功率标定。 |
| 313 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 314 | `    if(coAvg)` | 根据 `coAvg` 选择相干平均路径或普通功率平均路径。 |
| 315 | `        % Coherent averaging: align phase before averaging` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 316 | `        tspec = fft(tdata);` | 对当前记录做 FFT，得到复数频谱；复数相位用于相干平均。 |
| 317 | `        tspec(1) = 0;  % Remove DC component` | 清除 DC bin，避免直流偏置被误认为主信号。 |
| 318 | `        % Find fundamental signal bin in signal band` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 319 | `        [~, bin] = max(abs(tspec(1:floor(N_fft/2/OSR))));` | 在带内寻找幅度最大的 FFT bin，作为基波信号位置。 |
| 320 | `        % Guard against bin = 1 (DC bin) which would cause division by zero` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 321 | `        if bin == 1` | 防止主信号落在 DC bin；此时无法用基波相位做相干平均。 |
| 322 | `            warning('Signal detected at DC bin, skipping coherent averaging for this run');` | 提示用户当前运行的主峰在 DC，因此跳过这一行数据的相干平均。 |
| 323 | `            continue;` | 跳过当前循环剩余步骤，进入下一次迭代。 |
| 324 | `        end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 325 | `        phi = tspec(bin)/abs(tspec(bin));  % Extract phase of fundamental` | 提取基波单位相位因子；幅度归一化后只保留相位。 |
| 326 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 327 | `        % Phase alignment: rotate spectrum to align fundamental phase` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 328 | `        phasor = conj(phi);` | 构造相位旋转因子，用来把基波旋转到共同参考相位。 |
| 329 | `        marker = zeros(1,N_fft);` | 创建标记数组，记录哪些 bin 已按谐波关系处理过。 |
| 330 | `        % Apply phase shift to harmonics (accounting for aliasing)` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 331 | `        for iter2 = 1:N_fft` | 内层循环遍历谐波序列，把基波、谐波及其折叠位置逐个相位对齐。 |
| 332 | `            J = (bin-1)*iter2;` | 计算第 `iter2` 阶谐波对应的未折叠 bin 编号；`bin-1` 是从 0 开始的 bin。 |
| 333 | `            % Determine if harmonic is in even or odd Nyquist zone` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 334 | `            if(mod(floor(J/N_fft*2),2) == 0)` | 判断谐波位于偶数还是奇数 Nyquist 区；奇偶区决定折叠是否镜像。 |
| 335 | `                % Even zone: normal aliasing` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 336 | `                b = J-floor(J/N_fft)*N_fft+1;` | 偶数 Nyquist 区按普通取模方式折回 FFT bin。 |
| 337 | `                if(marker(b) == 0)` | 只处理尚未对齐过的 bin，避免多个谐波折叠到同一 bin 时重复旋转。 |
| 338 | `                    tspec(b) = tspec(b).*phasor;` | 对偶数区折叠的谐波 bin 应用相位旋转。 |
| 339 | `                    marker(b) = 1;` | 标记这个 bin 已经完成相位处理。 |
| 340 | `                end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 341 | `            else` | 条件分支的兜底路径：前面条件都不满足时执行。 |
| 342 | `                % Odd zone: mirrored aliasing` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 343 | `                b = N_fft-J+floor(J/N_fft)*N_fft+1;` | 奇数 Nyquist 区发生镜像折叠，因此用镜像公式计算 bin。 |
| 344 | `                if(marker(b) == 0)` | 只处理尚未对齐过的 bin，避免多个谐波折叠到同一 bin 时重复旋转。 |
| 345 | `                    tspec(b) = tspec(b).*conj(phasor);` | 对偶数区折叠的谐波 bin 应用相位旋转。 |
| 346 | `                    marker(b) = 1;` | 标记这个 bin 已经完成相位处理。 |
| 347 | `                end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 348 | `            end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 349 | `            phasor = phasor * conj(phi);` | 更新到下一阶谐波所需的相位旋转量。 |
| 350 | `        end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 351 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 352 | `        % Apply phase shift to non-harmonic components` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 353 | `        for iter2 = 1:N_fft` | 第二个内层循环处理非谐波 bin，让整条复频谱按基波相位连续对齐。 |
| 354 | `            if(marker(iter2) == 0)` | 只处理尚未在谐波对齐循环中处理过的非谐波 bin。 |
| 355 | `                tspec(iter2) = tspec(iter2).*(conj(phi).^((iter2-1)/(bin-1)));` | 按相对于基波 bin 的比例指数旋转非谐波分量，维持频谱相位连续性。 |
| 356 | `            end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 357 | `        end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 358 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 359 | `        spec = spec + tspec;  % Coherent sum` | 相干平均路径累加复数频谱；相位对齐后信号相加增强，随机噪声相对下降。 |
| 360 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 361 | `    else` | 条件分支的兜底路径：前面条件都不满足时执行。 |
| 362 | `        % Power averaging: accumulate power spectrum` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 363 | `        spec = spec+abs(fft(tdata)).^2;` | 普通平均路径累加功率谱；不关心相位，只平均每次运行的功率。 |
| 364 | `    end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 365 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 366 | `    ME = ME+1;` | 有效运行次数加 1，用于最终平均归一化。 |
| 367 | `end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 368 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 369 | `% Normalize spectrum based on averaging method` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 370 | `if(coAvg)` | 根据 `coAvg` 选择相干平均路径或普通功率平均路径。 |
| 371 | `    % Coherent averaging: take magnitude squared after sum, scale by number of runs` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 372 | `    spec = abs(spec).^2/(N_fft^2)*16/ME^2;` | 相干平均后先取幅度平方，再按 FFT 长度、满量程正弦标定和运行次数平方归一化。 |
| 373 | `else` | 条件分支的兜底路径：前面条件都不满足时执行。 |
| 374 | `    % Power averaging: scale by number of runs` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 375 | `    spec(1) = 0;  % Remove DC` | 清除 DC bin，避免直流分量进入指标计算。 |
| 376 | `    spec = spec/(N_fft^2)*16/ME;` | 普通功率平均按 FFT 长度、满量程正弦标定和运行次数归一化。 |
| 377 | `end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 378 | `spec = spec(1:Nd2);  % Keep only positive frequencies` | 保留单边正频率谱，后续指标都在 DC 到 Nyquist 范围内计算。 |
| 379 | `spec_inband = spec(1:floor(N_fft/2/OSR));  % Extract signal band` | 提取带内频谱；OSR 大于 1 时只看低频信号带宽。 |
| 380 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 381 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 382 | `% Remove flicker noise (1/f noise) if requested` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 383 | `if cutoffFreq &gt; 0` | 若设置了低频截止，准备清零截止频率以下的谱线。 |
| 384 | `    spec(1:ceil(cutoffFreq/Fs*N_fft)) = 0;` | 把低频 bin 置零，相当于忽略 DC 附近 flicker noise。 |
| 385 | `end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 386 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 387 | `% Find signal bin and refine using parabolic interpolation` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 388 | `[~, bin] = max(spec_inband);` | 在带内功率谱中寻找最大 bin，作为主信号峰值。 |
| 389 | `sig_e = log10(spec(bin));` | 取主峰及左右邻近 bin 的对数功率，用于抛物线插值估计真实峰值位置。 |
| 390 | `sig_l = log10(spec(min(max(bin-1,1),Nd2)));` | 取主峰及左右邻近 bin 的对数功率，用于抛物线插值估计真实峰值位置。 |
| 391 | `sig_r = log10(spec(min(max(bin+1,1),Nd2)));` | 取主峰及左右邻近 bin 的对数功率，用于抛物线插值估计真实峰值位置。 |
| 392 | `% Parabolic interpolation for sub-bin frequency accuracy` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 393 | `bin_r = bin + (sig_r-sig_l)/(2*sig_e-sig_l-sig_r)/2;` | 用三点抛物线插值细化主频位置；`bin_r` 可以是小数 bin。 |
| 394 | `if(isnan(bin_r))` | 若插值公式数值异常，则退回整数 bin。 |
| 395 | `    bin_r = bin;` | 执行当前代码块中的一步具体计算或绘图操作；建议结合本表前后行和上方算法章节理解其输入、输出和副作用。 |
| 396 | `end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 397 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 398 | `% Warn if signal is off-bin, indicating likely spectrum leakage` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 399 | `bin_offset = bin_r - bin;` | 计算插值峰值相对整数 bin 的偏移，用来判断是否存在明显非相干泄漏。 |
| 400 | `if abs(bin_offset) &gt; 0.01` | 若主峰偏离 FFT bin 超过阈值，认为可能有频谱泄漏。 |
| 401 | `    warning('plotspec:spectrumLeakage', ...` | 发出频谱泄漏警告，建议使用合适窗函数或保证相干采样。 |
| 402 | `        'Main tone is off-bin by %.2f%%, indicating likely spectrum leakage. Consider using a good window function or ensuring coherent sampling.', ...` | 执行当前代码块中的一步具体计算或绘图操作；建议结合本表前后行和上方算法章节理解其输入、输出和副作用。 |
| 403 | `            bin_offset * 100);` | 执行当前代码块中的一步具体计算或绘图操作；建议结合本表前后行和上方算法章节理解其输入、输出和副作用。 |
| 404 | `end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 405 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 406 | `% Auto-detect sideBin if set to 'auto'` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 407 | `if ischar(sideBin) &amp;&amp; strcmp(sideBin, 'auto')` | 若 `sideBin` 为 `auto`，进入自动检测主瓣宽度流程。 |
| 408 | `    % Step 1: Generate ideal spectrum at bin_r frequency` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 409 | `    % Create synthetic sinewave with unit amplitude` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 410 | `    t = 0:(N_fft-1);` | 生成理想正弦的采样序号，用于模拟当前窗函数下的理想泄漏形状。 |
| 411 | `    ideal_signal = sin(2*pi*(bin_r-1)/N_fft * t);` | 生成位于估计主频 `bin_r` 的单位幅度理想正弦。 |
| 412 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 413 | `    % Apply same window and normalization as actual data` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 414 | `    ideal_signal = ideal_signal .* win / sqrt(mean(win.^2));` | 对理想正弦使用同样窗函数和能量归一化，使其泄漏主瓣可与实测谱比较。 |
| 415 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 416 | `    % Compute FFT to get ideal spectrum shape` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 417 | `    ideal_spec = abs(fft(ideal_signal)).^2 / (N_fft^2) * 16;` | 计算理想正弦的功率谱，并使用同样满量程标定。 |
| 418 | `    ideal_spec = ideal_spec(1:Nd2);  % Keep positive frequencies only` | 理想谱也只保留单边正频率部分。 |
| 419 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 420 | `    % Scale ideal spectrum to match actual signal magnitude at peak` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 421 | `    % This ensures we compare spectral leakage at the same signal strength` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 422 | `    scale_factor = spec(bin) / ideal_spec(bin);` | 把理想谱缩放到与实测主峰相同高度。 |
| 423 | `    ideal_spec = ideal_spec * scale_factor;` | 应用缩放，使后续能直接比较理想泄漏和实测噪底。 |
| 424 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 425 | `    % Step 2: Estimate noise floor using median (robust to signal peak outliers)` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 426 | `    n_inband = floor(N_fft/2/OSR);` | 计算带内 bin 数，用于噪声、噪底和搜索范围。 |
| 427 | `    noise_floor_per_bin = median(spec(1:n_inband));` | 用带内中位数估计每个 bin 的典型噪底；中位数对尖峰更稳健。 |
| 428 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 429 | `    % Step 3: Find crossing points where ideal spectrum meets noise floor` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 430 | `    sideBin = 0;` | 从解析器结果中取出参数，保存为后续算法直接使用的局部变量。 |
| 431 | `    max_sidebin = min(bin-1, n_inband-bin);` | 限制向左右搜索的最大范围，避免越过 DC、Nyquist 或带宽边界。 |
| 432 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 433 | `    % Search outward from peak until ideal spectrum drops below noise floor` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 434 | `    for sb = 1:max_sidebin` | 从主峰向外逐步搜索，寻找理想主瓣跌到噪底以下的位置。 |
| 435 | `        left_bin = bin - sb;` | 计算当前搜索距离对应的左侧 bin。 |
| 436 | `        right_bin = bin + sb;` | 计算当前搜索距离对应的右侧 bin。 |
| 437 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 438 | `        % Check if both left and right bins are below noise floor in ideal spectrum` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 439 | `        left_below = (left_bin &gt;= 1) &amp;&amp; (ideal_spec(left_bin) &lt;= noise_floor_per_bin);` | 判断理想谱左侧这个 bin 是否已经低于噪底。 |
| 440 | `        right_below = (right_bin &lt;= n_inband) &amp;&amp; (ideal_spec(right_bin) &lt;= noise_floor_per_bin);` | 判断理想谱右侧这个 bin 是否已经低于噪底。 |
| 441 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 442 | `        if left_below &amp;&amp; right_below` | 若左右两边都低于噪底，说明主瓣有效宽度到此为止。 |
| 443 | `            % Both sides below noise floor, use previous sb` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 444 | `            sideBin = sb - 1;` | 从解析器结果中取出参数，保存为后续算法直接使用的局部变量。 |
| 445 | `            break;` | 结束当前循环；此处通常表示已经找到需要的边界或结果。 |
| 446 | `        end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 447 | `    end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 448 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 449 | `    % If never broke out, use maximum` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 450 | `    if sideBin == 0` | 若搜索没有提前结束，则用最大允许范围作为保守主瓣宽度。 |
| 451 | `        sideBin = max_sidebin;` | 从解析器结果中取出参数，保存为后续算法直接使用的局部变量。 |
| 452 | `    end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 453 | `end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 454 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 455 | `% Calculate signal power including side bins` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 456 | `sig = sum(spec(max(bin-sideBin,1):min(bin+sideBin,floor(N_fft/2/OSR))));` | 把主峰及左右 `sideBin` 个 bin 的功率相加，得到主信号功率。 |
| 457 | `pwr = 10*log10(sig);` | 把线性信号功率转换成 dBFS。 |
| 458 | `% Override with assumed signal power if provided` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 459 | `if(~isnan(assumedSignal))` | 若用户指定了信号功率，则覆盖频谱积分得到的值。 |
| 460 | `    sig = 10.^(assumedSignal/10);` | 把用户指定的 dB 信号功率转换回线性功率。 |
| 461 | `    pwr = assumedSignal;` | 直接使用用户指定的 dBFS 信号功率。 |
| 462 | `end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 463 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 464 | `% Remove harmonics from spectrum for display if harmonic &lt; 0` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 465 | `if(harmonic &lt; 0)` | 当 `harmonic` 为负数时，进入“从频谱中清除谐波”的特殊模式。 |
| 466 | `    for i = 2:-harmonic` | 循环处理 2 阶到指定阶数的谐波；负号把 `harmonic` 的绝对值当作阶数。 |
| 467 | `        b = alias(round((bin_r-1)*i),N_fft);` | 调用 `alias.m` 把第 i 阶谐波折叠回单边频谱对应 bin。 |
| 468 | `        spec(max(b+1-sideBin,1):min(b+1+sideBin,Nd2)) = 0;` | 把该谐波及附近主瓣 bin 清零，避免它们影响后续显示或噪声估计。 |
| 469 | `    end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 470 | `end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 471 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 472 | `% Plot spectrum if requested` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 473 | `if(dispPlot)` | 若开启绘图，则进入频谱绘制流程。 |
| 474 | `    % Use linear or log scale depending on OSR` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 475 | `    if (OSR == 1)` | 根据 OSR 判断横轴用线性频率还是对数频率。 |
| 476 | `        h = plot(freq,10*log10(spec+10^(-20)));` | OSR=1 时用线性横轴绘制 dBFS 频谱，并返回线对象句柄。 |
| 477 | `    else` | 条件分支的兜底路径：前面条件都不满足时执行。 |
| 478 | `        h = semilogx(freq,10*log10(spec+10^(-20)));` | OSR>1 时用对数横轴绘制频谱，便于观察低频带内区域。 |
| 479 | `    end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 480 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 481 | `    grid on;` | 打开网格，方便读频率和幅度。 |
| 482 | `    hold on;` | 保持当前图像，后续可叠加信号峰、谐波、噪底线等标注。 |
| 483 | `    % Mark signal bins if label enabled` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 484 | `    if(label &amp;&amp; show_s)` | 若允许标注且选择显示信号项，则突出显示主信号 bin。 |
| 485 | `        if (OSR == 1)` | 根据 OSR 判断横轴用线性频率还是对数频率。 |
| 486 | `            plot(freq(max(bin-sideBin,1):min(bin+sideBin,Nd2)),10*log10(spec(max(bin-sideBin,1):min(bin+sideBin,Nd2))),'r-','linewidth',0.5);` | 在线性横轴图上用红线标出主信号积分范围。 |
| 487 | `            plot(freq(bin),10*log10(spec(bin)),'ro','linewidth',0.5);` | 用红圈标出主峰 bin。 |
| 488 | `        else` | 条件分支的兜底路径：前面条件都不满足时执行。 |
| 489 | `            semilogx(freq(max(bin-sideBin,1):min(bin+sideBin,Nd2)),10*log10(spec(max(bin-sideBin,1):min(bin+sideBin,Nd2))),'r-','linewidth',0.5);` | 在对数横轴图上标出主信号积分范围。 |
| 490 | `        end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 491 | `    end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 492 | `    % Mark harmonics if requested` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 493 | `    if(harmonic &gt; 0 &amp;&amp; show_h)` | 若启用谐波标注，则在图上标出 2 阶到指定阶谐波。 |
| 494 | `        for i = 2:harmonic` | 循环遍历每个要标注或计算的谐波阶数。 |
| 495 | `            b = alias(round((bin_r-1)*i),N_fft);` | 调用 `alias.m` 把第 i 阶谐波折叠回单边频谱对应 bin。 |
| 496 | `            plot(b/N_fft*Fs,10*log10(spec(b+1)+10^(-20)),'rs');` | 在谐波折叠后的频率位置画红色方块。 |
| 497 | `            text(b/N_fft*Fs,10*log10(spec(b+1)+10^(-20))+5,num2str(i),'fontname','Arial','fontsize',12,'horizontalalignment','center');` | 在谐波标记旁写上谐波阶数。 |
| 498 | `        end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 499 | `    end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 500 | `end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 501 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 502 | `% Calculate SNDR and SFDR` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 503 | `% Save signal bin value for SFDR calculation` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 504 | `sigs = spec(bin);` | 保存主峰单个 bin 的功率，用于 SFDR 与最大杂散比较。 |
| 505 | `if(~isnan(assumedSignal))` | 若用户指定了信号功率，则覆盖频谱积分得到的值。 |
| 506 | `    sigs = 10.^(assumedSignal/10);` | 若信号功率被外部指定，则 SFDR 的信号参考也使用该值。 |
| 507 | `end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 508 | `% Remove signal and DC from spectrum for noise/distortion calculation` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 509 | `spec(max(bin-sideBin,1):min(bin+sideBin,Nd2)) = 0;` | 从频谱中清除主信号及其主瓣 bin，剩余部分用于噪声、失真和杂散计算。 |
| 510 | `spec(1:sideBin) = 0;` | 清除 DC 附近若干 bin，避免直流残留进入噪声计算。 |
| 511 | `spec_inband = spec(1:floor(N_fft/2/OSR));` | 提取带内频谱；OSR 大于 1 时只看低频信号带宽。 |
| 512 | `noi = sum(spec_inband);  % Total noise + distortion power` | 初步把带内剩余功率求和，作为噪声加失真功率。 |
| 513 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 514 | `% Find largest spur for SFDR` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 515 | `[spur, sbin] = max(spec_inband);` | 找到带内剩余谱线中最大的杂散峰及其 bin。 |
| 516 | `SNDR = 10*log10(sig/noi);` | 计算 SNDR：主信号功率除以噪声加失真功率，再转换为 dB。 |
| 517 | `SFDR = 10*log10(sigs/spur);` | 计算 SFDR：主信号峰功率与最大杂散功率的比值。 |
| 518 | `ENoB = (SNDR-1.76)/6.02;` | 由 SNDR 换算有效位数，公式来自理想 ADC 量化噪声关系。 |
| 519 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 520 | `% Mark maximum spur on plot` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 521 | `if(dispPlot &amp;&amp; label &amp;&amp; show_p)` | 若启用最大杂散标注，则在图上标出 SFDR 对应的 spur。 |
| 522 | `    plot((sbin-1)/N_fft*Fs,10*log10(spur+10^(-20)),'rd');` | 在最大杂散频率位置画红色菱形。 |
| 523 | `    text((sbin-1)/N_fft*Fs,10*log10(spur+10^(-20))+5,'MaxSpur','fontname','Arial','fontsize',10,'horizontalalignment','center');` | 在最大杂散旁添加 `MaxSpur` 文本。 |
| 524 | `end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 525 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 526 | `% Calculate noise floor using all methods and select per NFMethod` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 527 | `n_inband = floor(N_fft/2/OSR);` | 计算带内 bin 数，用于噪声、噪底和搜索范围。 |
| 528 | `spec_inband = spec(1:n_inband);` | 执行当前代码块中的一步具体计算或绘图操作；建议结合本表前后行和上方算法章节理解其输入、输出和副作用。 |
| 529 | `% Method 1: Median-based estimation (robust to spurs)` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 530 | `if(N_run == 1)` | 根据运行次数选择中位数噪声估计的校正系数。 |
| 531 | `    % Mn = 0.4549364231; % theoretical value of the median of chi-squared distribution, but not working well` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 532 | `    Mn = 0.72;      % this empirical value works well, but why??` | 单次 FFT 时采用经验校正系数，把中位数谱线换算为均值噪声功率。 |
| 533 | `else` | 条件分支的兜底路径：前面条件都不满足时执行。 |
| 534 | `    Mn = (1-2/(9*N_run))^3;     % Wilson鈥揌ilferty approximation of the median of chi-squared distribution` | 多次平均时用 Wilson-Hilferty 近似校正卡方分布中位数。 |
| 535 | `end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 536 | `noi_median = median(spec_inband)/Mn * n_inband;` | 方法 1：用中位数估计每 bin 噪声，再乘以带内 bin 数得到总噪声。 |
| 537 | `% Method 2: Trimmed mean (removes top/bottom 5%)` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 538 | `spec_sort = sort(spec_inband);` | 把带内谱线排序，为截尾均值噪声估计做准备。 |
| 539 | `noi_mean = mean(spec_sort(max(1,floor(n_inband*0.05)):max(1,floor(n_inband*0.95)))) * n_inband;` | 方法 2：去掉低端和高端约 5% 后求平均，降低异常尖峰影响。 |
| 540 | `% Method 3: Exclude harmonics from noise calculation` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 541 | `spec_noise = spec;` | 复制剩余频谱，准备剔除谐波后估计噪声。 |
| 542 | `for i = 2:nTHD` | 循环处理 THD 或谐波剔除需要的 2 到 nTHD 阶谐波。 |
| 543 | `    b = alias(round((bin_r-1)*i),N_fft) +1;` | 调用 `alias.m` 把第 i 阶谐波折叠回单边频谱对应 bin。 |
| 544 | `    spec_noise(b) = 0;` | 把该谐波 bin 清零，使噪声估计不把谐波失真算入随机噪声。 |
| 545 | `end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 546 | `noi_exclude = sum(spec_noise(1:n_inband));` | 方法 3：谐波剔除后直接求带内剩余功率。 |
| 547 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 548 | `if(nfmethod == 0)` | 若选择自动噪底方法，则综合三种估计。 |
| 549 | `    % Auto: median of all methods` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 550 | `    noi = median([noi_median, noi_mean, noi_exclude]);` | 自动模式取三种噪声估计值的中位数，避免单一方法偏差过大。 |
| 551 | `    % Warn if results differ significantly (&gt;25% or ~1dB)` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 552 | `    noi_all = [noi_median, noi_mean, noi_exclude];` | 保存三种噪声估计结果，用于一致性检查。 |
| 553 | `    if max(noi_all) / min(noi_all) &gt; 1.25` | 若三种噪底估计差异超过 25%，说明频谱噪底不规则。 |
| 554 | `        warning('plotspec:irregularNoiseFloor', ...` | 提示用户噪底估计方法分歧较大，建议手动指定 `NFMethod`。 |
| 555 | `            'Noise floor estimation methods differ by %.1f dB. The noise floor may be irregular. Consider manually selecting NFMethod (''median'', ''mean'', or ''exclude'').', ...` | 执行当前代码块中的一步具体计算或绘图操作；建议结合本表前后行和上方算法章节理解其输入、输出和副作用。 |
| 556 | `            10*log10(max(noi_all) / min(noi_all)));` | 执行当前代码块中的一步具体计算或绘图操作；建议结合本表前后行和上方算法章节理解其输入、输出和副作用。 |
| 557 | `    end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 558 | `elseif(nfmethod == 1)` | 条件分支：前面的 `if` 不满足时，继续检查本条件。 |
| 559 | `    noi = noi_median;` | 最终噪声功率采用中位数法结果。 |
| 560 | `elseif(nfmethod == 2)` | 条件分支：前面的 `if` 不满足时，继续检查本条件。 |
| 561 | `    noi = noi_mean;` | 最终噪声功率采用截尾均值结果。 |
| 562 | `else` | 条件分支的兜底路径：前面条件都不满足时执行。 |
| 563 | `    noi = noi_exclude;` | 最终噪声功率采用谐波剔除法结果。 |
| 564 | `end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 565 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 566 | `% Calculate THD by summing harmonic power` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 567 | `thd = 0;` | 初始化 THD 线性功率累加器。 |
| 568 | `for i = 2:nTHD` | 循环处理 THD 或谐波剔除需要的 2 到 nTHD 阶谐波。 |
| 569 | `    b = alias(round((bin_r-1)*i),N_fft) +1;` | 调用 `alias.m` 把第 i 阶谐波折叠回单边频谱对应 bin。 |
| 570 | `    thd = thd + spec(b);` | 累加当前谐波 bin 的功率。 |
| 571 | `end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 572 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 573 | `THD = 10*log10(thd/sigs);` | 计算 THD：谐波总功率与主信号参考功率之比，单位 dB。 |
| 574 | `SNR = 10*log10(sig/noi);` | 计算 SNR：主信号功率与最终噪声功率之比。 |
| 575 | `NF = SNR - pwr;  % Noise floor relative to 0 dBFS` | 计算相对 0 dBFS 的噪底指标；这里变量名 `NF` 实际表示噪声余量/噪底相关量。 |
| 576 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 577 | `% Finalize plot formatting and annotations` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 578 | `if(dispPlot)` | 若开启绘图，则进入频谱绘制流程。 |
| 579 | `    % Set axis limits based on noise floor` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 580 | `    minx = min(max(median(10*log10(spec_inband))-20,-200),-40);` | 根据带内谱线中位数设置 y 轴下限，并限制在合理显示范围。 |
| 581 | `    axis([Fs/N_fft,Fs/2,minx,0]);` | 设置频谱图坐标范围：从一个 FFT bin 到 Nyquist，幅度从噪底附近到 0 dBFS。 |
| 582 | `    if(label)` | 若启用标注，开始添加带宽线、指标文字和噪底线。 |
| 583 | `        % Draw signal bandwidth limit` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 584 | `        if(show_o)` | 执行当前代码块中的一步具体计算或绘图操作；建议结合本表前后行和上方算法章节理解其输入、输出和副作用。 |
| 585 | `            plot([1,1]*Fs/2/OSR,[0,-1000],'--');` | 画出带内带宽边界 `Fs/(2*OSR)` 的竖线。 |
| 586 | `        end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 587 | `        % Determine text position based on scale and signal location` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 588 | `        if(OSR&gt;1)` | 执行当前代码块中的一步具体计算或绘图操作；建议结合本表前后行和上方算法章节理解其输入、输出和副作用。 |
| 589 | `            TX = 10^(log10(Fs)*0.01+log10(Fs/N_fft)*0.99);` | 对数横轴下计算文字 x 坐标，使文本靠近低频侧。 |
| 590 | `        else` | 条件分支的兜底路径：前面条件都不满足时执行。 |
| 591 | `            if((bin-1)/N_fft &lt; 0.2)` | 线性横轴下根据主信号是否靠左来选择文字位置，避免遮挡主峰。 |
| 592 | `                TX = Fs*0.3 + Fs/N_fft*0.7;` | 执行当前代码块中的一步具体计算或绘图操作；建议结合本表前后行和上方算法章节理解其输入、输出和副作用。 |
| 593 | `            else` | 条件分支的兜底路径：前面条件都不满足时执行。 |
| 594 | `                TX = Fs*0.01 + Fs/N_fft;` | 执行当前代码块中的一步具体计算或绘图操作；建议结合本表前后行和上方算法章节理解其输入、输出和副作用。 |
| 595 | `            end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 596 | `        end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 597 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 598 | `        TYD = minx*0.06;  % Text vertical spacing` | 计算指标文字的垂直间距。 |
| 599 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 600 | `        % Format sampling frequency with SI prefixes` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 601 | `        if(Fs &gt;= 10^9)` | 执行当前代码块中的一步具体计算或绘图操作；建议结合本表前后行和上方算法章节理解其输入、输出和副作用。 |
| 602 | `            txt_fs = num2str(Fs/10^9,'%.1fG');` | 把采样率转成带 G/M/K 或普通数字的字符串。 |
| 603 | `        elseif(Fs &gt;= 10^6)` | 条件分支：前面的 `if` 不满足时，继续检查本条件。 |
| 604 | `            txt_fs = num2str(Fs/10^6,'%.1fM');` | 把采样率转成带 G/M/K 或普通数字的字符串。 |
| 605 | `        elseif(Fs &gt;= 10^3)` | 条件分支：前面的 `if` 不满足时，继续检查本条件。 |
| 606 | `            txt_fs = num2str(Fs/10^3,'%.1fK');` | 把采样率转成带 G/M/K 或普通数字的字符串。 |
| 607 | `        elseif(Fs &gt;= 1)` | 条件分支：前面的 `if` 不满足时，继续检查本条件。 |
| 608 | `            txt_fs = num2str(Fs,'%.1f');` | 把采样率转成带 G/M/K 或普通数字的字符串。 |
| 609 | `        else` | 条件分支的兜底路径：前面条件都不满足时执行。 |
| 610 | `            txt_fs = num2str(Fs,'%.3f');` | 把采样率转成带 G/M/K 或普通数字的字符串。 |
| 611 | `        end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 612 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 613 | `        % Format input frequency with SI prefixes` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 614 | `        Fin = (bin_r-1)/N_fft*Fs;` | 根据插值后的主峰 bin 估计输入信号频率。 |
| 615 | `        if(Fin &gt;= 10^9)` | 执行当前代码块中的一步具体计算或绘图操作；建议结合本表前后行和上方算法章节理解其输入、输出和副作用。 |
| 616 | `            txt_fin = num2str(Fin/10^9,'%.1fG');` | 把输入频率转成便于阅读的字符串。 |
| 617 | `        elseif(Fin &gt;= 10^6)` | 条件分支：前面的 `if` 不满足时，继续检查本条件。 |
| 618 | `            txt_fin = num2str(Fin/10^6,'%.1fM');` | 把输入频率转成便于阅读的字符串。 |
| 619 | `        elseif(Fin &gt;= 10^3)` | 条件分支：前面的 `if` 不满足时，继续检查本条件。 |
| 620 | `            txt_fin = num2str(Fin/10^3,'%.1fK');` | 把输入频率转成便于阅读的字符串。 |
| 621 | `        elseif(Fin &gt;= 1)` | 条件分支：前面的 `if` 不满足时，继续检查本条件。 |
| 622 | `            txt_fin = num2str(Fin,'%.1f');` | 把输入频率转成便于阅读的字符串。 |
| 623 | `        else` | 条件分支的兜底路径：前面条件都不满足时执行。 |
| 624 | `            txt_fin = num2str(bin_r/N_fft*Fs,'%.3f');` | 把输入频率转成便于阅读的字符串。 |
| 625 | `        end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 626 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 627 | `        % Display performance metrics` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 628 | `        TYN = 0;` | 初始化图中文字行号计数器。 |
| 629 | `        if(show_f)` | 执行当前代码块中的一步具体计算或绘图操作；建议结合本表前后行和上方算法章节理解其输入、输出和副作用。 |
| 630 | `            TYN = TYN + 1;` | 文字行号加 1，让下一条指标显示在下一行。 |
| 631 | `            text(TX,TYD*TYN,['Fin/Fs = ',txt_fin,' / ',txt_fs,' Hz']);` | 在图上写输入频率和采样频率。 |
| 632 | `        end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 633 | `        if(show_e)` | 执行当前代码块中的一步具体计算或绘图操作；建议结合本表前后行和上方算法章节理解其输入、输出和副作用。 |
| 634 | `            TYN = TYN + 1;` | 文字行号加 1，让下一条指标显示在下一行。 |
| 635 | `            text(TX,TYD*TYN,['ENoB = ',num2str(ENoB,'%.2f')]);` | 在图上写 ENOB。 |
| 636 | `        end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 637 | `        if(show_d)` | 执行当前代码块中的一步具体计算或绘图操作；建议结合本表前后行和上方算法章节理解其输入、输出和副作用。 |
| 638 | `            TYN = TYN + 1;` | 文字行号加 1，让下一条指标显示在下一行。 |
| 639 | `            text(TX,TYD*TYN,['SNDR = ',num2str(SNDR,'%.2f'),' dB']);` | 在图上写 SNDR。 |
| 640 | `        end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 641 | `        if(show_u)` | 执行当前代码块中的一步具体计算或绘图操作；建议结合本表前后行和上方算法章节理解其输入、输出和副作用。 |
| 642 | `            TYN = TYN + 1;` | 文字行号加 1，让下一条指标显示在下一行。 |
| 643 | `            text(TX,TYD*TYN,['SFDR = ',num2str(SFDR,'%.2f'),' dB']);` | 在图上写 SFDR。 |
| 644 | `        end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 645 | `        if(show_t)` | 执行当前代码块中的一步具体计算或绘图操作；建议结合本表前后行和上方算法章节理解其输入、输出和副作用。 |
| 646 | `            TYN = TYN + 1;` | 文字行号加 1，让下一条指标显示在下一行。 |
| 647 | `            text(TX,TYD*TYN,['THD = ',num2str(THD,'%.2f'),' dB']);` | 在图上写 THD。 |
| 648 | `        end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 649 | `        if(show_r)` | 执行当前代码块中的一步具体计算或绘图操作；建议结合本表前后行和上方算法章节理解其输入、输出和副作用。 |
| 650 | `            TYN = TYN + 1;` | 文字行号加 1，让下一条指标显示在下一行。 |
| 651 | `            text(TX,TYD*TYN,['SNR = ',num2str(SNR,'%.2f'),' dB']);` | 在图上写 SNR。 |
| 652 | `        end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 653 | `        if(show_l)` | 执行当前代码块中的一步具体计算或绘图操作；建议结合本表前后行和上方算法章节理解其输入、输出和副作用。 |
| 654 | `            TYN = TYN + 1;` | 文字行号加 1，让下一条指标显示在下一行。 |
| 655 | `            text(TX,TYD*TYN,['Noise Floor = ',num2str(NF,'%.2f'),' dB']);` | 在图上写噪底相关指标。 |
| 656 | `        end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 657 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 658 | `        % Display additional metrics and noise floor line` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 659 | `        if (OSR&gt;1)` | 执行当前代码块中的一步具体计算或绘图操作；建议结合本表前后行和上方算法章节理解其输入、输出和副作用。 |
| 660 | `            if(show_s)` | 执行当前代码块中的一步具体计算或绘图操作；建议结合本表前后行和上方算法章节理解其输入、输出和副作用。 |
| 661 | `                text(bin/N_fft*Fs,min(pwr,TYD/2),['Sig = ',num2str(pwr,'%.2f'),' dB']);` | OSR 图中在主峰附近标出信号功率。 |
| 662 | `            end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 663 | `            if(show_y)` | 执行当前代码块中的一步具体计算或绘图操作；建议结合本表前后行和上方算法章节理解其输入、输出和副作用。 |
| 664 | `                semilogx([Fs/N_fft,Fs/2/OSR],-[1,1]*(NF+10*log10(N_fft/2/OSR)),'r--');` | 对数横轴下画噪声谱密度参考线。 |
| 665 | `                TYN = TYN + 1;` | 文字行号加 1，让下一条指标显示在下一行。 |
| 666 | `                text(TX,TYD*TYN,['NSD = ',num2str(-NF-10*log10(Fs/2/OSR),'%.2f'),' dBFS/Hz']);` | 在图上写 NSD，也就是归一化到 1 Hz 带宽的噪声谱密度。 |
| 667 | `            end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 668 | `            if(show_o)` | 执行当前代码块中的一步具体计算或绘图操作；建议结合本表前后行和上方算法章节理解其输入、输出和副作用。 |
| 669 | `                TYN = TYN + 1;` | 文字行号加 1，让下一条指标显示在下一行。 |
| 670 | `                text(TX,TYD*TYN,['OSR = ',num2str(OSR,'%.2f')]);` | 在图上写 OSR 数值。 |
| 671 | `            end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 672 | `        else` | 条件分支的兜底路径：前面条件都不满足时执行。 |
| 673 | `            % Position signal power label to avoid signal peak` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 674 | `            if(show_s)` | 执行当前代码块中的一步具体计算或绘图操作；建议结合本表前后行和上方算法章节理解其输入、输出和副作用。 |
| 675 | `                if(bin/N_fft&gt;0.4)` | 执行当前代码块中的一步具体计算或绘图操作；建议结合本表前后行和上方算法章节理解其输入、输出和副作用。 |
| 676 | `                    text((bin/N_fft-0.01)*Fs,min(pwr,TYD/2),['Sig = ',num2str(pwr,'%.2f'),' dB'],'horizontalAlignment','right');` | 执行当前代码块中的一步具体计算或绘图操作；建议结合本表前后行和上方算法章节理解其输入、输出和副作用。 |
| 677 | `                else` | 条件分支的兜底路径：前面条件都不满足时执行。 |
| 678 | `                    text((bin/N_fft+0.01)*Fs,min(pwr,TYD/2),['Sig = ',num2str(pwr,'%.2f'),' dB']);` | 执行当前代码块中的一步具体计算或绘图操作；建议结合本表前后行和上方算法章节理解其输入、输出和副作用。 |
| 679 | `                end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 680 | `            end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 681 | `            if(show_y)` | 执行当前代码块中的一步具体计算或绘图操作；建议结合本表前后行和上方算法章节理解其输入、输出和副作用。 |
| 682 | `                plot([0,Fs/2],-[1,1]*(NF+10*log10(N_fft/2/OSR)),'r--');` | 线性横轴下画 NSD 参考水平线。 |
| 683 | `                TYN = TYN + 1;` | 文字行号加 1，让下一条指标显示在下一行。 |
| 684 | `                text(TX,TYD*TYN,['NSD = ',num2str(-NF-10*log10(Fs/2/OSR),'%.2f'),' dBFS/Hz']);` | 在图上写 NSD，也就是归一化到 1 Hz 带宽的噪声谱密度。 |
| 685 | `            end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 686 | `        end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 687 | `    end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 688 | `    % Set axis labels and title` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 689 | `    xlabel('Freq (Hz)');` | 设置 x 轴标签为频率 Hz。 |
| 690 | `    ylabel('dBFS');` | 设置 y 轴标签为 dBFS。 |
| 691 | `    if(N_run &gt; 1)` | 执行当前代码块中的一步具体计算或绘图操作；建议结合本表前后行和上方算法章节理解其输入、输出和副作用。 |
| 692 | `        if(coAvg)` | 根据 `coAvg` 选择相干平均路径或普通功率平均路径。 |
| 693 | `            title(sprintf('Power Spectrum (%dx Coherently Averaged)',N_run));` | 相干平均模式下设置标题，说明运行次数。 |
| 694 | `        else` | 条件分支的兜底路径：前面条件都不满足时执行。 |
| 695 | `            title(sprintf('Power Spectrum (%dx Averaged)',N_run));` | 普通平均模式下设置标题，说明运行次数。 |
| 696 | `        end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 697 | `    else` | 条件分支的兜底路径：前面条件都不满足时执行。 |
| 698 | `        title('Power Spectrum');` | 单次运行时设置普通频谱标题。 |
| 699 | `    end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 700 | `end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 701 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 702 | `% Assign output variables with new names` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 703 | `enob = (SNDR-1.76)/6.02;` | 由 SNDR 换算有效位数，公式来自理想 ADC 量化噪声关系。 |
| 704 | `sndr = SNDR;` | 计算 SNDR：主信号功率除以噪声加失真功率，再转换为 dB。 |
| 705 | `sfdr = SFDR;` | 计算 SFDR：主信号峰功率与最大杂散功率的比值。 |
| 706 | `snr = SNR;` | 把内部计算变量映射到函数输出；注意输出 `noi` 对应这里的 `NF`，`nsd` 为 dBFS/Hz。 |
| 707 | `thd = THD;` | 把内部计算变量映射到函数输出；注意输出 `noi` 对应这里的 `NF`，`nsd` 为 dBFS/Hz。 |
| 708 | `sigpwr = pwr;` | 把内部计算变量映射到函数输出；注意输出 `noi` 对应这里的 `NF`，`nsd` 为 dBFS/Hz。 |
| 709 | `noi = NF;` | 把内部计算变量映射到函数输出；注意输出 `noi` 对应这里的 `NF`，`nsd` 为 dBFS/Hz。 |
| 710 | `nsd = -(NF + 10*log10(Fs/2/OSR));` | 把内部计算变量映射到函数输出；注意输出 `noi` 对应这里的 `NF`，`nsd` 为 dBFS/Hz。 |
| 711 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 712 | `if(~dispPlot)` | 如果没有绘图，则图形句柄输出为空。 |
| 713 | `    h = [];` | 无图模式返回空句柄，调用者可安全忽略第 9 个输出。 |
| 714 | `end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 715 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 716 | `% Nested functions for embedded window generation (no toolbox required)` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 717 | `    function w = rectwin_emb(N)` | 定义嵌套矩形窗函数；嵌套函数只能在 `plotspec` 内部直接调用。 |
| 718 | `        % RECTWIN_EMB Embedded rectangle (boxcar) window function` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 719 | `        %   w = RECTWIN_EMB(N) returns an N-point rectangle window in a row vector` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 720 | `        %   This is a simple embedded implementation that doesn't require` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 721 | `        %   the Signal Processing Toolbox` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 722 | `        w = ones(1, N);` | 矩形窗就是全 1 向量，相当于不加窗。 |
| 723 | `    end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 724 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 725 | `    function w = hannwin(N)` | 定义嵌套 Hann 窗函数；避免依赖 Signal Processing Toolbox 的 `hann`。 |
| 726 | `        % HANNWIN Embedded Hanning window function` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 727 | `        %   w = HANNWIN(N) returns an N-point Hanning (raised cosine) window` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 728 | `        %   in a row vector. This is a simple embedded implementation that` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 729 | `        %   doesn't require the Signal Processing Toolbox` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 730 | `        %` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 731 | `        %   The Hanning window is defined as:` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 732 | `        %   w(n) = 0.5 * (1 - cos(2*pi*n/(N-1))) for n = 0, 1, ..., N-1` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 733 | `        if N == 1` | 处理长度为 1 的边界情况，避免除法或向量公式异常。 |
| 734 | `            w = 1;` | 单点窗的值定义为 1。 |
| 735 | `        else` | 条件分支的兜底路径：前面条件都不满足时执行。 |
| 736 | `            n = 0:(N-1);` | 生成 Hann 窗的离散样本序号。 |
| 737 | `            w = 0.5 * (1 - cos(2*pi*n/N));` | 计算周期 Hann 窗；这里分母用 `N`，适合 FFT 周期窗思想。 |
| 738 | `        end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 739 | `    end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 740 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 741 | `end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |

## `alias.m` 逐行解析

`alias.m` 是本示例包必须携带的依赖。它很短，但对谐波折叠、THD、SFDR 标注都很关键。

| 行号 | 代码 | 解释 |
| ---: | --- | --- |
| 1 | `function fal = alias(fin,fs)` | 定义 `alias(fin,fs)` 函数；输入原始频率和采样频率，输出折叠到第一 Nyquist 带的频率。 |
| 2 | `%ALIAS Calculate aliased frequency after sampling` | 函数帮助文本；解释别名折叠、输入输出、例子和 Nyquist 区规则。 |
| 3 | `%   This function returns the aliased frequency of a signal after sampling,` | 函数帮助文本；解释别名折叠、输入输出、例子和 Nyquist 区规则。 |
| 4 | `%   accounting for different Nyquist zones. The aliasing follows the pattern` | 函数帮助文本；解释别名折叠、输入输出、例子和 Nyquist 区规则。 |
| 5 | `%   where signals in even Nyquist zones (0, 2, 4...) alias normally, while` | 函数帮助文本；解释别名折叠、输入输出、例子和 Nyquist 区规则。 |
| 6 | `%   signals in odd Nyquist zones (1, 3, 5...) alias with spectral inversion.` | 函数帮助文本；解释别名折叠、输入输出、例子和 Nyquist 区规则。 |
| 7 | `%` | 函数帮助文本；解释别名折叠、输入输出、例子和 Nyquist 区规则。 |
| 8 | `%   Syntax:` | 函数帮助文本；解释别名折叠、输入输出、例子和 Nyquist 区规则。 |
| 9 | `%     fal = ALIAS(fin, fs)` | 函数帮助文本；解释别名折叠、输入输出、例子和 Nyquist 区规则。 |
| 10 | `%` | 函数帮助文本；解释别名折叠、输入输出、例子和 Nyquist 区规则。 |
| 11 | `%   Inputs:` | 函数帮助文本；解释别名折叠、输入输出、例子和 Nyquist 区规则。 |
| 12 | `%     fin - Signal frequency before sampling` | 函数帮助文本；解释别名折叠、输入输出、例子和 Nyquist 区规则。 |
| 13 | `%       Scalar or Vector` | 函数帮助文本；解释别名折叠、输入输出、例子和 Nyquist 区规则。 |
| 14 | `%     fs - Sampling frequency. Must be a positive real number.` | 函数帮助文本；解释别名折叠、输入输出、例子和 Nyquist 区规则。 |
| 15 | `%       Scalar` | 函数帮助文本；解释别名折叠、输入输出、例子和 Nyquist 区规则。 |
| 16 | `%` | 函数帮助文本；解释别名折叠、输入输出、例子和 Nyquist 区规则。 |
| 17 | `%   Outputs:` | 函数帮助文本；解释别名折叠、输入输出、例子和 Nyquist 区规则。 |
| 18 | `%     fal - Aliased signal frequency after sampling ` | 函数帮助文本；解释别名折叠、输入输出、例子和 Nyquist 区规则。 |
| 19 | `%       Scalar or Vector (same size as fin)` | 函数帮助文本；解释别名折叠、输入输出、例子和 Nyquist 区规则。 |
| 20 | `%       Range: [0, fs/2]` | 函数帮助文本；解释别名折叠、输入输出、例子和 Nyquist 区规则。 |
| 21 | `%` | 函数帮助文本；解释别名折叠、输入输出、例子和 Nyquist 区规则。 |
| 22 | `%   Examples:` | 函数帮助文本；解释别名折叠、输入输出、例子和 Nyquist 区规则。 |
| 23 | `%     % Signal at 0.7*fs aliases to 0.3*fs in first Nyquist zone (mirrored)` | 函数帮助文本；解释别名折叠、输入输出、例子和 Nyquist 区规则。 |
| 24 | `%     fal = alias(70, 100)  % Returns 30 ` | 函数帮助文本；解释别名折叠、输入输出、例子和 Nyquist 区规则。 |
| 25 | `%` | 函数帮助文本；解释别名折叠、输入输出、例子和 Nyquist 区规则。 |
| 26 | `%     % Signal at 1.3*fs aliases to 0.3*fs in second Nyquist zone (normal)` | 函数帮助文本；解释别名折叠、输入输出、例子和 Nyquist 区规则。 |
| 27 | `%     fal = alias(130, 100)  % Returns 30 ` | 函数帮助文本；解释别名折叠、输入输出、例子和 Nyquist 区规则。 |
| 28 | `%` | 函数帮助文本；解释别名折叠、输入输出、例子和 Nyquist 区规则。 |
| 29 | `%     % Multiple frequencies` | 函数帮助文本；解释别名折叠、输入输出、例子和 Nyquist 区规则。 |
| 30 | `%     fal = alias([30 70 130], 100)  % Returns [30 30 30]` | 函数帮助文本；解释别名折叠、输入输出、例子和 Nyquist 区规则。 |
| 31 | `%` | 函数帮助文本；解释别名折叠、输入输出、例子和 Nyquist 区规则。 |
| 32 | `%   Notes:` | 函数帮助文本；解释别名折叠、输入输出、例子和 Nyquist 区规则。 |
| 33 | `%     - Nyquist zone n is defined as [(n)*fs/2, (n+1)*fs/2]` | 函数帮助文本；解释别名折叠、输入输出、例子和 Nyquist 区规则。 |
| 34 | `%     - Even zones: direct aliasing (fal = mod(fin,fs))` | 函数帮助文本；解释别名折叠、输入输出、例子和 Nyquist 区规则。 |
| 35 | `%     - Odd zones: mirrored aliasing (fal = fs - mod(fin,fs))` | 函数帮助文本；解释别名折叠、输入输出、例子和 Nyquist 区规则。 |
| 36 | `%` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 37 | `%   See also: findFin, findBin` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 38 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 39 | `    % Input validation` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 40 | `    if fs &lt;= 0` | 检查采样频率是否为正；采样频率为 0 或负数没有物理意义。 |
| 41 | `        error('alias:invalidFs', 'Sampling frequency fs must be positive.');` | 采样频率非法时抛出带 ID 的错误，方便调用者捕获。 |
| 42 | `    end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 43 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 44 | `    if(~isreal(fin) \|\| ~isreal(fs))` | 检查输入频率和采样频率是否为实数；复频率不适用于这里的折叠公式。 |
| 45 | `        error('alias:invalidInput', 'Frequencies must be real numbers.');` | 输入存在复数时抛出错误。 |
| 46 | `    end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 47 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 48 | `    % Determine Nyquist zone (0-based indexing)` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 49 | `    % Zone 0: [0, fs/2], Zone 1: [fs/2, fs], Zone 2: [fs, 3*fs/2], etc.` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 50 | `    nyquistZone = floor(fin / fs * 2);` | 计算 0-based Nyquist 区编号；每个区宽度是 `fs/2`。 |
| 51 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 52 | `    % Calculate base frequency offset within the Nyquist zone` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 53 | `    baseOffset = fin - floor(fin / fs) * fs;` | 计算输入频率在一个采样周期 `fs` 内的余量，类似取模。 |
| 54 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 55 | `    % Apply aliasing rule based on even/odd Nyquist zone` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 56 | `    % Even zones (0,2,4,...): normal aliasing` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 57 | `    % Odd zones (1,3,5,...): mirrored aliasing` | 注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。 |
| 58 | `    isEvenZone = mod(nyquistZone, 2) == 0;` | 判断 Nyquist 区编号是否为偶数；偶数区正常折叠，奇数区镜像折叠。 |
| 59 | `    fal = isEvenZone .* baseOffset + ~isEvenZone .* (fs - baseOffset);` | 用向量化表达式同时处理标量和数组：偶数区输出 `baseOffset`，奇数区输出 `fs-baseOffset`。 |
| 60 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |
| 61 | `end` | 结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。 |
| 62 | <空行> | 空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。 |

## 学习路线建议

1. 先运行 `run_plotspec_examples.m`，观察每个图和命令行指标。
2. 用 `coherent_10bit_sine.csv` 比较 `rect` 和 `hann`，理解相干采样与窗函数主瓣。
3. 用 `leaky_10bit_sine.csv` 改变 `sideBin`，观察 SNDR 为什么会变。
4. 用 `multirun_10bit_sine.csv` 比较 `averageMode='normal'` 和 `'coherent'`。
5. 用 `osr_noise_shaped_like.csv` 把 `OSR` 从 1 改到 16，观察带内噪声和 NSD 的变化。
6. 最后回到逐行表，按“输入解析、FFT、主峰、噪声、绘图、输出”六个段落重读源码。

## 常见错误

- 找不到 `alias`：说明 MATLAB 当前路径没有包含本示例包目录。执行 `addpath('D:\Matlab\adc-modeling\Noise-Shaping-SAR-ADC\adc_plotspec')`。
- ENOB 很低：先确认输入是否相干采样、`maxCode` 是否传对、`OSR` 是否设置、是否有强 spur 或泄漏。
- 图上主峰很宽：这通常是窗函数主瓣或非相干泄漏，不一定是 ADC 噪声本身。
- 使用 `@blackman` 报错：说明缺少 Signal Processing Toolbox；改用内置 `'hann'` 或 `'rect'`。
- `disp=false` 后没有图形句柄：这是正常行为，第 9 个输出 `h` 会返回 `[]`。
