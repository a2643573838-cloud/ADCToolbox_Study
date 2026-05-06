# 5-1：全局认识与基础跑通

## 今日目标

- 理解 ADCToolbox 的整体目录结构。
- 完成 MATLAB 版工具箱路径配置。
- 跑通最小 ADC 分析流程。
- 建立第一版常用函数地图。

## 推荐时间安排

| 时间 | 内容 |
| --- | --- |
| 09:30-10:30 | 阅读根目录 `README.md`，了解功能模块 |
| 10:45-12:00 | 浏览 `matlab/src` 和 `matlab/tests` |
| 14:00-15:30 | 跑通 `adcpanel` 最小例子 |
| 15:45-17:30 | 单独运行 `plotspec`、`sinfit`、`inlsin`、`plotphase` |
| 20:00-21:00 | 写当天笔记和问题清单 |

## 需要关注的目录

```text
matlab/src/          MATLAB 主函数
matlab/tests/        MATLAB 测试与示例
python/src/          Python 版实现
python/docs/source/  Python 算法说明
reference_dataset/   参考数据
reference_output/    参考输出
docs/images/         说明文档图片
```

## MATLAB 初始化

在 MATLAB 中执行：

```matlab
cd D:\Matlab\ADCToolbox\matlab
run('setupLib.m')
```

## 最小分析例子

```matlab
sig = sin(2*pi*0.123*(0:4095)') + 0.01*randn(4096,1);
rep = adcpanel(sig, 'fs', 100e6);
```

继续分别运行：

```matlab
plotspec(sig, 'Fs', 100e6);
freq = findfreq(sig, 100e6);
[fitout, freq, mag, dc, phi] = sinfit(sig);
code = round((sig - min(sig)) / (max(sig) - min(sig)) * 4095);
[inl, dnl, codeAxis] = inlsin(code);
plotphase(sig);
```

## 今日重点函数

- `adcpanel`：一站式 ADC 分析面板。
- `plotspec`：频谱分析，输出 ENOB、SNDR、SNR、SFDR、THD。
- `findfreq`：估计输入主频。
- `sinfit`：四参数正弦拟合。
- `inlsin`：基于正弦直方图估计 INL/DNL。
- `plotphase`：相位/极坐标频谱分析。

## 练习任务

1. 改变 `sig` 的噪声幅度，例如 `0.001`、`0.01`、`0.05`，观察 ENOB 和 SNDR 变化。
2. 改变采样点数，例如 `2048`、`4096`、`8192`，观察频谱分辨率。
3. 截图保存一张 `adcpanel` 结果图。

## 今日产出

建议新建笔记：

```text
5-1_学习笔记.md
```

回答以下问题：

- ADCToolbox 的主流程是什么？
- `adcpanel` 调用了哪些核心分析？
- `SNR`、`SNDR`、`SFDR`、`ENOB` 分别描述什么？
- 今天遇到的 MATLAB 报错或困惑是什么？
