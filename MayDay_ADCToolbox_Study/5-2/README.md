# 5-2：频谱分析与动态性能指标

## 今日目标

- 系统掌握 FFT 频谱分析流程。
- 理解 ENOB、SNDR、SNR、SFDR、THD 的计算意义。
- 认识 coherent sampling、window、OSR 对频谱结果的影响。
- 能用 ADCToolbox 对不同输入条件做动态性能比较。

## 推荐时间安排

| 时间 | 内容 |
| --- | --- |
| 09:30-10:30 | 阅读 `plotspec.m`、`findbin.m`、`findfreq.m` |
| 10:45-12:00 | 学习 aliasing、Nyquist zone、FFT bin 的关系 |
| 14:00-15:30 | 跑不同噪声/谐波条件下的频谱分析 |
| 15:45-17:30 | 对比 window、FFT length、OSR 的影响 |
| 20:00-21:00 | 整理动态性能指标速查表 |

## 今日重点函数

- `plotspec`：频谱指标主函数。
- `findfreq`：输入频率估计。
- `findbin`：目标频率到 FFT bin 的映射。
- `alias`：采样混叠频率计算。
- `perfosr`：性能随 OSR 变化的扫描。
- `ifilter`：基于 FFT 的理想滤波。

## 建议阅读的源码

```text
matlab/src/plotspec.m
matlab/src/findfreq.m
matlab/src/findbin.m
matlab/src/alias.m
matlab/src/perfosr.m
matlab/src/ifilter.m
```

## Python 示例参考

```text
python/src/adctoolbox/examples/02_spectrum/exp_s00_fft_fundamentals.py
python/src/adctoolbox/examples/02_spectrum/exp_s01_analyze_spectrum_simplest.py
python/src/adctoolbox/examples/02_spectrum/exp_s04_sweep_dynamic_range.py
python/src/adctoolbox/examples/02_spectrum/exp_s06_sweeping_fft_and_osr.py
python/src/adctoolbox/examples/02_spectrum/exp_s08_windowing_deep_dive.py
```

## 练习 1：噪声对 SNR/ENOB 的影响

```matlab
N = 4096;
n = (0:N-1)';
fin = 37 / N;

noiseList = [0.001, 0.003, 0.01, 0.03];

for k = 1:numel(noiseList)
    sig = sin(2*pi*fin*n) + noiseList(k)*randn(N,1);
    figure;
    plotspec(sig, 'Fs', 100e6);
    title(sprintf('Noise = %.4f', noiseList(k)));
end
```

## 练习 2：谐波失真对 SNDR/SFDR 的影响

```matlab
N = 4096;
n = (0:N-1)';
fin = 37 / N;

sig1 = sin(2*pi*fin*n);
sig2 = sig1 + 0.01*sin(2*pi*2*fin*n);
sig3 = sig1 + 0.01*sin(2*pi*2*fin*n) + 0.005*sin(2*pi*3*fin*n);

figure; plotspec(sig1, 'Fs', 100e6); title('Ideal');
figure; plotspec(sig2, 'Fs', 100e6); title('HD2');
figure; plotspec(sig3, 'Fs', 100e6); title('HD2 + HD3');
```

## 今日产出

建议整理：

```text
5-2_ADC动态性能指标速查表.md
```

至少包含：

- SNR 和 SNDR 的区别。
- SFDR 如何反映最大 spur。
- THD 与谐波阶数的关系。
- ENOB 和 SNDR 的换算关系。
- coherent sampling 为什么重要。
- window 在什么场景下有用。
