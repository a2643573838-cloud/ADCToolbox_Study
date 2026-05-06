# 5-3：正弦拟合、误差分析与 INL/DNL

## 今日目标

- 理解正弦拟合在 ADC 测试中的作用。
- 掌握 time-domain error 的构造方式。
- 学会用误差随输入值、误差随相位、频谱和 INL/DNL 判断误差来源。
- 建立静态误差和动态误差的区分框架。

## 推荐时间安排

| 时间 | 内容 |
| --- | --- |
| 09:30-10:30 | 阅读 `sinfit.m` 和 `tomdec.m` |
| 10:45-12:00 | 阅读 `errsin.m` 和 `inlsin.m` |
| 14:00-15:30 | 构造静态非线性和动态误差样例 |
| 15:45-17:30 | 对比误差图、INL/DNL 图、频谱图 |
| 20:00-21:00 | 总结误差诊断方法 |

## 今日重点函数

- `sinfit`：四参数正弦拟合。
- `tomdec`：Thompson decomposition，将信号分解为正弦、谐波和误差。
- `errsin`：正弦拟合误差分析。
- `inlsin`：从正弦直方图估计 INL/DNL。
- `plotphase`：相位/极坐标误差分析。

## 建议阅读的源码

```text
matlab/src/sinfit.m
matlab/src/tomdec.m
matlab/src/errsin.m
matlab/src/inlsin.m
matlab/src/plotphase.m
```

## Python 算法文档参考

```text
python/docs/source/algorithms/fit_sine_4param.md
python/docs/source/algorithms/analyze_error_by_value.md
python/docs/source/algorithms/analyze_error_by_phase.md
python/docs/source/algorithms/analyze_inl_from_sine.md
python/docs/source/algorithms/analyze_spectrum_polar.md
```

## 练习 1：比较理想正弦和非线性正弦

```matlab
N = 8192;
n = (0:N-1)';
fin = 83 / N;
x = sin(2*pi*fin*n);

sigIdeal = x;
sigStaticNL = x + 0.02*x.^2 - 0.01*x.^3;

figure; adcpanel(sigIdeal, 'fs', 100e6);
figure; adcpanel(sigStaticNL, 'fs', 100e6);
```

观察：

- HD2/HD3 是否明显上升。
- `errsin` 中误差是否随输入值呈现规律。
- `inlsin` 是否出现明显弯曲。

## 练习 2：比较随机噪声和相位相关误差

```matlab
N = 8192;
n = (0:N-1)';
fin = 83 / N;
x = sin(2*pi*fin*n);

sigNoise = x + 0.01*randn(N,1);
sigPhaseRelated = x + 0.01*cos(2*pi*fin*n).*sin(2*pi*5*fin*n);

figure; adcpanel(sigNoise, 'fs', 100e6);
figure; adcpanel(sigPhaseRelated, 'fs', 100e6);
```

观察：

- 随机噪声在误差图中是否更分散。
- 相位相关误差是否在 phase/error 图里更有结构。

## 误差诊断框架

| 现象 | 可能原因 |
| --- | --- |
| 噪声底整体升高 | 热噪声、量化噪声 |
| HD2/HD3 明显 | 静态非线性 |
| 高输入频率下 SNR 下降 | jitter |
| 误差随输入值有规律 | INL、静态非线性 |
| 误差随相位有规律 | 动态非线性、settling、memory |
| spur 不在谐波位置 | 干扰、时钟耦合、调制 |

## 今日产出

建议整理：

```text
5-3_误差分析方法.md
```

回答以下问题：

- 为什么正弦拟合后再看 residual？
- 静态非线性和动态非线性的图像特征有什么不同？
- INL/DNL 和频谱失真之间有什么联系？
- `plotphase` 相比普通频谱图多提供了什么信息？
