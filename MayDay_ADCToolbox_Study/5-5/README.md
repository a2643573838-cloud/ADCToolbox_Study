# 5-5：完整小项目与复盘

## 今日目标

- 用 ADCToolbox 完成一次完整 ADC 表征流程。
- 汇总 5 天学习内容，形成个人速查文档。
- 建立后续继续深入源码和算法的路线。

## 推荐时间安排

| 时间 | 内容 |
| --- | --- |
| 09:30-10:30 | 选择小项目主题，准备实验脚本 |
| 10:45-12:00 | 生成不同非理想因素的数据 |
| 14:00-16:00 | 批量运行分析，保存结果和图 |
| 16:15-17:30 | 整理性能对比表 |
| 20:00-21:30 | 完成五一学习总结 |

## 推荐小项目

比较 5 种 ADC 非理想因素对性能指标和误差形态的影响：

1. thermal noise
2. quantization noise
3. jitter-like phase error
4. static HD2/HD3 nonlinearity
5. dynamic settling / memory-like error

## 参考实验脚本框架

```matlab
N = 8192;
n = (0:N-1)';
fs = 100e6;
fin = 83 / N;
x = sin(2*pi*fin*n);

cases = struct();
cases(1).name = 'Ideal';
cases(1).sig = x;

cases(2).name = 'Thermal Noise';
cases(2).sig = x + 0.01*randn(N,1);

cases(3).name = 'Static HD2 HD3';
cases(3).sig = x + 0.02*x.^2 - 0.01*x.^3;

cases(4).name = 'Phase Related Error';
cases(4).sig = sin(2*pi*fin*n + 0.005*sin(2*pi*7*fin*n));

cases(5).name = 'Memory Like Error';
cases(5).sig = x + 0.02*[0; diff(x)];

for k = 1:numel(cases)
    figure('Name', cases(k).name);
    rep = adcpanel(cases(k).sig, 'fs', fs);
    results(k).name = cases(k).name;
    results(k).rep = rep;
end
```

## 性能对比表模板

| Case | SNR | SNDR | SFDR | ENOB | Max INL | 主要误差特征 |
| --- | --- | --- | --- | --- | --- | --- |
| Ideal |  |  |  |  |  |  |
| Thermal Noise |  |  |  |  |  |  |
| Static HD2/HD3 |  |  |  |  |  |  |
| Phase Related Error |  |  |  |  |  |  |
| Memory Like Error |  |  |  |  |  |  |

## 最终复盘文档

建议整理 3 份文档：

```text
ADCToolbox学习笔记.md
ADC动态性能指标速查表.md
ADCToolbox常用函数地图.md
```

## 常用函数地图

```text
一站式分析：adcpanel
频谱分析：plotspec, plotphase, perfosr
频率/采样辅助：findfreq, findbin, alias
正弦拟合：sinfit
误差分解：tomdec, errsin
线性度：inlsin
数字校准：wcalsin, cdacwgt, plotwgt, plotres
bit 检查：bitchk
```

## 后续深入路线

1. 先把 `matlab/src` 的核心函数读一遍，重点看输入输出和调用链。
2. 再对照 `python/src/adctoolbox` 看 Python 版如何模块化实现。
3. 对频谱分析、误差分析、校准算法分别写一份自己的推导笔记。
4. 用自己的 ADC 仿真或实测数据替换示例信号，形成真实分析报告。

## 今日完成标准

- 至少保存 5 张不同非理想因素的分析图。
- 完成一张性能指标对比表。
- 能口头解释每个 case 的主要误差来源。
- 整理出下一阶段最想深入的 3 个问题。
