$ErrorActionPreference = 'Stop'

$pack = $PSScriptRoot
$out = Join-Path $pack 'plotspec_study_guide.md'
$plotspec = Join-Path $pack 'plotspec.m'
$alias = Join-Path $pack 'alias.m'

function Escape-MdCell([string]$s) {
    if ($null -eq $s) { return '' }
    $s = $s.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;')
    $s = $s.Replace('|','\|')
    $s = $s.Replace('`','``')
    if ($s.Length -eq 0) { return '<空行>' }
    return "``$s``"
}

function Explain-Common([string]$t) {
    if ($t.Length -eq 0) { return '空行，用来把不同逻辑段分开；MATLAB 执行时会忽略。' }
    if ($t.StartsWith('%')) { return '注释行，解释紧邻代码块的意图；不会被 MATLAB 执行。' }
    if ($t -eq 'end') { return '结束当前 `if`、`for`、`switch` 或 `function` 代码块；具体结束对象由缩进和上下文决定。' }
    if ($t -eq 'else') { return '条件分支的兜底路径：前面条件都不满足时执行。' }
    if ($t.StartsWith('elseif')) { return '条件分支：前面的 `if` 不满足时，继续检查本条件。' }
    if ($t -eq 'try') { return '进入容错调用；如果当前调用方式失败，会进入 `catch` 尝试备用方式。' }
    if ($t -eq 'catch') { return '捕获上一段尝试中的错误，避免函数直接中断。' }
    if ($t -eq 'break;') { return '结束当前循环；此处通常表示已经找到需要的边界或结果。' }
    if ($t -eq 'continue;') { return '跳过当前循环剩余步骤，进入下一次迭代。' }
    return $null
}

function Explain-PlotSpecLine([int]$n, [string]$line) {
    $t = $line.Trim()
    $common = Explain-Common $t
    if ($n -eq 1) { return '定义主函数、9 个输出指标和输入 `sig,varargin`；`varargin` 让函数接受可变数量的位置参数和 Name-Value 参数。' }
    if ($n -ge 2 -and $n -le 137) { return '函数帮助文本的一部分；说明用途、输入输出、参数、示例和注意事项，用户在 MATLAB 中执行 `help plotspec` 会看到这些内容。' }
    if ($null -ne $common) { return $common }

    if ($t -eq 'p = inputParser;') { return '创建 MATLAB 的输入解析器对象；它负责读取 `varargin` 并检查每个参数是否合法。' }
    if ($t -like 'validScalarPosNum*') { return '定义匿名校验函数：要求输入是数值、标量且大于 0，适用于采样率、OSR、满量程等正数参数。' }
    if ($t -like 'validScalarPosInt*') { return '定义正整数校验函数：用于谐波数量、THD 阶数等必须为整数的参数。' }
    if ($t -like 'validInteger*') { return '定义整数校验函数：允许正负整数，因此 `harmonic < 0` 可作为特殊模式。' }
    if ($t -like 'validWindow*') { return '定义窗函数参数的合法形式：字符串 `hann/rect` 或函数句柄，例如 `@blackman`。' }
    if ($t -like 'validNFMethod*') { return '定义噪底估计方法的合法取值；既兼容数字编码，也支持可读字符串。' }
    if ($t -like 'validAvgMode*') { return '定义平均模式的合法取值；`normal` 表示功率平均，`coherent` 表示相干平均。' }
    if ($t -like 'validLogical*') { return '定义逻辑参数校验函数；允许 `true/false`，也允许 `0/1`。' }
    if ($t -like 'addOptional(p,*Fs*') { return '注册可选位置参数 `Fs`，默认采样率为 1 Hz；实际 ADC 数据通常要显式传入真实采样率。' }
    if ($t -like 'addOptional(p,*maxCode*') { return '注册可选位置参数 `maxCode`，默认取输入最大值减最小值；它用于把 ADC 输出归一化到满量程。' }
    if ($t -like 'addOptional(p,*harmonic*') { return '注册可选位置参数 `harmonic`，默认分析 5 阶谐波；负数有“从噪声中排除谐波”的特殊含义。' }
    if ($t -like 'addParameter(p,*') { return '注册一个 Name-Value 参数及其默认值和校验规则；这是函数接口灵活性的来源。' }
    if ($t -like 'parse(p,*') { return '实际解析用户传入的 `varargin`；若参数不合法，会在这里报错。' }

    if ($t -match '^(Fs|harmonic|OSR|sideBin|label|assumedSignal|nTHD) =') { return '从解析器结果中取出参数，保存为后续算法直接使用的局部变量。' }
    if ($t -like 'if ischar(p.Results.NFMethod)*') { return '判断噪底估计方法是否以字符串给出；若是字符串则转换成内部数字编码。' }
    if ($t -eq 'switch p.Results.NFMethod') { return '按噪底方法字符串进入分支转换。' }
    if ($t -match "case '(auto|median|mean|exclude)'") { return '匹配一种噪底估计方法字符串，并在下一行赋予对应数字编码。' }
    if ($t -match '^nfmethod =') { return '设置内部噪底估计方法编号：0=auto，1=median，2=mean，3=exclude。' }
    if ($t -like 'if ~isequal(p.Results.averageMode*') { return '检查新版 `averageMode` 是否被用户显式设置；新版参数优先于旧版 `coAvg`。' }
    if ($t -like 'if ischar(p.Results.averageMode)*') { return '判断平均模式是否以字符串给出；字符串需要转换成数字开关。' }
    if ($t -eq 'switch p.Results.averageMode') { return '根据平均模式字符串选择普通平均或相干平均。' }
    if ($t -match '^coAvg = 0') { return '关闭相干平均，使用普通功率谱平均。' }
    if ($t -match '^coAvg = 1') { return '开启相干平均，后续会先对齐相位再累加 FFT。' }
    if ($t -like 'coAvg = p.Results*') { return '确定最终相干平均开关；新版参数默认时会回退到旧参数。' }
    if ($t -like 'if ~isnan(p.Results.maxSignal)*') { return '判断用户是否设置新版满量程 `maxSignal`；若设置则覆盖位置参数 `maxCode`。' }
    if ($t -match '^maxSignal =') { return '确定用于归一化 ADC 数据的满量程范围。' }
    if ($t -like 'if ~isequal(p.Results.window*') { return '判断新版窗函数参数是否被显式设置；新版 `window` 优先于旧版 `winType`。' }
    if ($t -match '^windowFunc =') { return '确定实际使用的窗函数，避免变量名直接叫 `window` 而遮蔽 MATLAB 内置函数。' }
    if ($t -like 'if ~(isnumeric(p.Results.disp)*') { return '判断新版绘图开关 `disp` 是否被设置。' }
    if ($t -match '^dispPlot =') { return '把绘图开关转换成逻辑值，决定后面是否调用 `plot/semilogx`。' }
    if ($t -like 'if p.Results.cutoff > 0*') { return '若新版 `cutoff` 大于 0，则使用它作为低频剔除截止频率。' }
    if ($t -match '^cutoffFreq =') { return '确定最终使用的低频噪声截止频率。' }
    if ($t -like 'dispItem =*') { return '把显示项目字符串转换成小写字符数组，后续逐字符判断要显示哪些标注。' }
    if ($t -match '^show_[a-z] =') { return '生成一个显示开关；对应 `dispItem` 中的某个字符，控制图上某类文本或标记是否出现。' }

    if ($t -eq '[N,M] = size(sig);') { return '读取输入信号矩阵尺寸；`N` 是行数，`M` 是列数。' }
    if ($t -eq 'N_fft = M;') { return '默认把列数作为 FFT 长度；矩阵输入时每一行是一次采样记录。' }
    if ($t -like 'if(M==1*') { return '检测列向量输入；若用户传入列向量，需要转成行向量以统一后续处理。' }
    if ($t -eq "sig = sig';") { return '把列向量转置成行向量。' }
    if ($t -eq 'N_fft = N;') { return '列向量转置后，原行数才是真正的 FFT 长度。' }
    if ($t -eq '[N_run,~] = size(sig);') { return '得到运行次数；单行是一次运行，多行表示多次测量可用于平均。' }
    if ($t -like 'Nd2 =*') { return '计算单边频谱点数；实信号 FFT 只需要 DC 到 Nyquist 的正频率部分。' }
    if ($t -like 'freq =*') { return '生成频率坐标轴，把 FFT bin 编号换算成 Hz。' }

    if ($t -eq 'if ischar(windowFunc)') { return '判断窗函数是否用内置字符串形式指定。' }
    if ($t -like "if strcmp(windowFunc, 'hann')*") { return '选择内置 Hann 窗；它能降低泄漏旁瓣，但会展宽主瓣。' }
    if ($t -like "elseif strcmp(windowFunc, 'rect')*") { return '选择矩形窗；相干采样时最干净，非相干采样时泄漏严重。' }
    if ($t -match '^win = hannwin') { return '调用文件末尾的嵌套 Hann 窗函数生成窗向量。' }
    if ($t -match '^win = rectwin_emb') { return '调用文件末尾的嵌套矩形窗函数生成全 1 窗向量。' }
    if ($t -like 'warning("Unsupported window type*') { return '当字符串窗函数不受支持时发出警告，并退回矩形窗。' }
    if ($t -like 'win = window(windowFunc*periodic*') { return '调用 MATLAB `window` 生成周期窗；这通常依赖 Signal Processing Toolbox。' }
    if ($t -like 'win = window(windowFunc,N_fft)*') { return '若周期窗语法失败，尝试不带 `periodic` 的通用窗函数调用。' }
    if ($t -like 'warning("Unsupported window function*') { return '函数句柄窗也无法生成时提示用户，并退回矩形窗。' }

    if ($t -like 'spec = zeros*') { return '初始化完整双边频谱累加器；普通平均累加功率，相干平均累加复数 FFT。' }
    if ($t -eq 'ME = 0;') { return '初始化有效测量次数计数器；全零数据会被跳过。' }
    if ($t -eq 'for iter = 1:N_run') { return '外层循环逐行处理每次测量；多行输入时每一行独立做 FFT 后再平均。' }
    if ($t -like 'tdata = sig(iter,:)*') { return '取出当前一次运行的时域数据。' }
    if ($t -like 'if(rms(tdata)==0)*') { return '检查当前数据是否全零；全零记录没有频谱意义。' }
    if ($t -like 'tdata = tdata./maxSignal*') { return '把 ADC 码值除以满量程，换成相对满量程单位，为 dBFS 归一化做准备。' }
    if ($t -like 'tdata = tdata-mean*') { return '去掉直流分量；频谱分析通常关注交流输入信号和噪声失真。' }
    if ($t -like 'tdata = tdata.*win*') { return '乘窗并按窗 RMS 做能量归一化，避免窗函数改变总体噪声功率标定。' }
    if ($t -eq 'if(coAvg)') { return '根据 `coAvg` 选择相干平均路径或普通功率平均路径。' }
    if ($t -like 'tspec = fft(tdata)*') { return '对当前记录做 FFT，得到复数频谱；复数相位用于相干平均。' }
    if ($t -like 'tspec(1) = 0*') { return '清除 DC bin，避免直流偏置被误认为主信号。' }
    if ($t.StartsWith('[~, bin] = max(abs(tspec')) { return '在带内寻找幅度最大的 FFT bin，作为基波信号位置。' }
    if ($t -eq 'if bin == 1') { return '防止主信号落在 DC bin；此时无法用基波相位做相干平均。' }
    if ($t -like "warning('Signal detected at DC bin*") { return '提示用户当前运行的主峰在 DC，因此跳过这一行数据的相干平均。' }
    if ($t -like 'phi = tspec(bin)*') { return '提取基波单位相位因子；幅度归一化后只保留相位。' }
    if ($t -like 'phasor = conj(phi)*') { return '构造相位旋转因子，用来把基波旋转到共同参考相位。' }
    if ($t -like 'marker = zeros*') { return '创建标记数组，记录哪些 bin 已按谐波关系处理过。' }
    if ($t -eq 'for iter2 = 1:N_fft' -and $n -lt 350) { return '内层循环遍历谐波序列，把基波、谐波及其折叠位置逐个相位对齐。' }
    if ($t -like 'J = (bin-1)*iter2*') { return '计算第 `iter2` 阶谐波对应的未折叠 bin 编号；`bin-1` 是从 0 开始的 bin。' }
    if ($t -like 'if(mod(floor(J/N_fft*2),2) == 0)*') { return '判断谐波位于偶数还是奇数 Nyquist 区；奇偶区决定折叠是否镜像。' }
    if ($t -like 'b = J-floor*') { return '偶数 Nyquist 区按普通取模方式折回 FFT bin。' }
    if ($t -like 'if(marker(b) == 0)*') { return '只处理尚未对齐过的 bin，避免多个谐波折叠到同一 bin 时重复旋转。' }
    if ($t -like 'tspec(b) = tspec(b).*phasor*') { return '对偶数区折叠的谐波 bin 应用相位旋转。' }
    if ($t -like 'marker(b) = 1*') { return '标记这个 bin 已经完成相位处理。' }
    if ($t -like 'b = N_fft-J+floor*') { return '奇数 Nyquist 区发生镜像折叠，因此用镜像公式计算 bin。' }
    if ($t -like 'tspec(b) = tspec(b).*conj(phasor)*') { return '对奇数区镜像折叠的谐波使用共轭相位旋转，补偿频谱反转。' }
    if ($t -like 'phasor = phasor * conj(phi)*') { return '更新到下一阶谐波所需的相位旋转量。' }
    if ($t -eq 'for iter2 = 1:N_fft' -and $n -ge 350) { return '第二个内层循环处理非谐波 bin，让整条复频谱按基波相位连续对齐。' }
    if ($t -like 'if(marker(iter2) == 0)*') { return '只处理尚未在谐波对齐循环中处理过的非谐波 bin。' }
    if ($t -like 'tspec(iter2) = tspec(iter2).*') { return '按相对于基波 bin 的比例指数旋转非谐波分量，维持频谱相位连续性。' }
    if ($t -like 'spec = spec + tspec*') { return '相干平均路径累加复数频谱；相位对齐后信号相加增强，随机噪声相对下降。' }
    if ($t -like 'spec = spec+abs(fft(tdata)).^2*') { return '普通平均路径累加功率谱；不关心相位，只平均每次运行的功率。' }
    if ($t -like 'ME = ME+1*') { return '有效运行次数加 1，用于最终平均归一化。' }
    if ($t -like 'spec = abs(spec).^2/(N_fft^2)*16/ME^2*') { return '相干平均后先取幅度平方，再按 FFT 长度、满量程正弦标定和运行次数平方归一化。' }
    if ($t -like 'spec(1) = 0*') { return '清除 DC bin，避免直流分量进入指标计算。' }
    if ($t -like 'spec = spec/(N_fft^2)*16/ME*') { return '普通功率平均按 FFT 长度、满量程正弦标定和运行次数归一化。' }
    if ($t -like 'spec = spec(1:Nd2)*') { return '保留单边正频率谱，后续指标都在 DC 到 Nyquist 范围内计算。' }
    if ($t -like 'spec_inband = spec(1:floor(N_fft/2/OSR))*') { return '提取带内频谱；OSR 大于 1 时只看低频信号带宽。' }

    if ($t -like 'if cutoffFreq > 0*') { return '若设置了低频截止，准备清零截止频率以下的谱线。' }
    if ($t -like 'spec(1:ceil(cutoffFreq/Fs*N_fft))*') { return '把低频 bin 置零，相当于忽略 DC 附近 flicker noise。' }
    if ($t.StartsWith('[~, bin] = max(spec_inband)')) { return '在带内功率谱中寻找最大 bin，作为主信号峰值。' }
    if ($t -match '^sig_[elr] =') { return '取主峰及左右邻近 bin 的对数功率，用于抛物线插值估计真实峰值位置。' }
    if ($t -like 'bin_r = bin +*') { return '用三点抛物线插值细化主频位置；`bin_r` 可以是小数 bin。' }
    if ($t -like 'if(isnan(bin_r))*') { return '若插值公式数值异常，则退回整数 bin。' }
    if ($t -like 'bin_offset =*') { return '计算插值峰值相对整数 bin 的偏移，用来判断是否存在明显非相干泄漏。' }
    if ($t -like 'if abs(bin_offset) >*') { return '若主峰偏离 FFT bin 超过阈值，认为可能有频谱泄漏。' }
    if ($t -like "warning('plotspec:spectrumLeakage'*") { return '发出频谱泄漏警告，建议使用合适窗函数或保证相干采样。' }

    if ($t -like 'if ischar(sideBin)*') { return '若 `sideBin` 为 `auto`，进入自动检测主瓣宽度流程。' }
    if ($t -like 't = 0:(N_fft-1)*') { return '生成理想正弦的采样序号，用于模拟当前窗函数下的理想泄漏形状。' }
    if ($t -like 'ideal_signal = sin*') { return '生成位于估计主频 `bin_r` 的单位幅度理想正弦。' }
    if ($t -like 'ideal_signal = ideal_signal .* win*') { return '对理想正弦使用同样窗函数和能量归一化，使其泄漏主瓣可与实测谱比较。' }
    if ($t -like 'ideal_spec = abs(fft(ideal_signal))*') { return '计算理想正弦的功率谱，并使用同样满量程标定。' }
    if ($t -like 'ideal_spec = ideal_spec(1:Nd2)*') { return '理想谱也只保留单边正频率部分。' }
    if ($t -like 'scale_factor =*') { return '把理想谱缩放到与实测主峰相同高度。' }
    if ($t -like 'ideal_spec = ideal_spec * scale_factor*') { return '应用缩放，使后续能直接比较理想泄漏和实测噪底。' }
    if ($t -like 'n_inband = floor*') { return '计算带内 bin 数，用于噪声、噪底和搜索范围。' }
    if ($t -like 'noise_floor_per_bin = median*') { return '用带内中位数估计每个 bin 的典型噪底；中位数对尖峰更稳健。' }
    if ($t -like 'sideBin = 0*') { return '初始化自动检测得到的边带 bin 数。' }
    if ($t -like 'max_sidebin =*') { return '限制向左右搜索的最大范围，避免越过 DC、Nyquist 或带宽边界。' }
    if ($t -like 'for sb = 1:max_sidebin*') { return '从主峰向外逐步搜索，寻找理想主瓣跌到噪底以下的位置。' }
    if ($t -like 'left_bin =*') { return '计算当前搜索距离对应的左侧 bin。' }
    if ($t -like 'right_bin =*') { return '计算当前搜索距离对应的右侧 bin。' }
    if ($t -like 'left_below =*') { return '判断理想谱左侧这个 bin 是否已经低于噪底。' }
    if ($t -like 'right_below =*') { return '判断理想谱右侧这个 bin 是否已经低于噪底。' }
    if ($t -like 'if left_below && right_below*') { return '若左右两边都低于噪底，说明主瓣有效宽度到此为止。' }
    if ($t -like 'sideBin = sb - 1*') { return '使用前一个距离作为主信号积分半宽，避免把低于噪底的 bin 计入信号。' }
    if ($t -like 'if sideBin == 0*') { return '若搜索没有提前结束，则用最大允许范围作为保守主瓣宽度。' }
    if ($t -like 'sideBin = max_sidebin*') { return '自动检测失败或主瓣很宽时，采用最大搜索范围。' }

    if ($t -like 'sig = sum(spec(max(bin-sideBin*') { return '把主峰及左右 `sideBin` 个 bin 的功率相加，得到主信号功率。' }
    if ($t -like 'pwr = 10*log10(sig)*') { return '把线性信号功率转换成 dBFS。' }
    if ($t -like 'if(~isnan(assumedSignal))*') { return '若用户指定了信号功率，则覆盖频谱积分得到的值。' }
    if ($t -like 'sig = 10.^(assumedSignal/10)*') { return '把用户指定的 dB 信号功率转换回线性功率。' }
    if ($t -like 'pwr = assumedSignal*') { return '直接使用用户指定的 dBFS 信号功率。' }
    if ($t -like 'if(harmonic < 0)*') { return '当 `harmonic` 为负数时，进入“从频谱中清除谐波”的特殊模式。' }
    if ($t -like 'for i = 2:-harmonic*') { return '循环处理 2 阶到指定阶数的谐波；负号把 `harmonic` 的绝对值当作阶数。' }
    if ($t -like 'b = alias(round((bin_r-1)*i),N_fft)*') { return '调用 `alias.m` 把第 i 阶谐波折叠回单边频谱对应 bin。' }
    if ($t -like 'spec(max(b+1-sideBin*') { return '把该谐波及附近主瓣 bin 清零，避免它们影响后续显示或噪声估计。' }

    if ($t -eq 'if(dispPlot)') { return '若开启绘图，则进入频谱绘制流程。' }
    if ($t -like 'if (OSR == 1)*') { return '根据 OSR 判断横轴用线性频率还是对数频率。' }
    if ($t -like 'h = plot*') { return 'OSR=1 时用线性横轴绘制 dBFS 频谱，并返回线对象句柄。' }
    if ($t -like 'h = semilogx*') { return 'OSR>1 时用对数横轴绘制频谱，便于观察低频带内区域。' }
    if ($t -eq 'grid on;') { return '打开网格，方便读频率和幅度。' }
    if ($t -eq 'hold on;') { return '保持当前图像，后续可叠加信号峰、谐波、噪底线等标注。' }
    if ($t -like 'if(label && show_s)*') { return '若允许标注且选择显示信号项，则突出显示主信号 bin。' }
    if ($t -like 'plot(freq(max(bin-sideBin*') { return '在线性横轴图上用红线标出主信号积分范围。' }
    if ($t -like 'plot(freq(bin),*') { return '用红圈标出主峰 bin。' }
    if ($t -like 'semilogx(freq(max(bin-sideBin*') { return '在对数横轴图上标出主信号积分范围。' }
    if ($t -like 'if(harmonic > 0 && show_h)*') { return '若启用谐波标注，则在图上标出 2 阶到指定阶谐波。' }
    if ($t -like 'for i = 2:harmonic*') { return '循环遍历每个要标注或计算的谐波阶数。' }
    if ($t -like 'plot(b/N_fft*Fs,*') { return '在谐波折叠后的频率位置画红色方块。' }
    if ($t -like 'text(b/N_fft*Fs,*') { return '在谐波标记旁写上谐波阶数。' }

    if ($t -like 'sigs = spec(bin)*') { return '保存主峰单个 bin 的功率，用于 SFDR 与最大杂散比较。' }
    if ($t -like 'sigs = 10.^(assumedSignal/10)*') { return '若信号功率被外部指定，则 SFDR 的信号参考也使用该值。' }
    if ($t -like 'spec(max(bin-sideBin*') { return '从频谱中清除主信号及其主瓣 bin，剩余部分用于噪声、失真和杂散计算。' }
    if ($t -like 'spec(1:sideBin) = 0*') { return '清除 DC 附近若干 bin，避免直流残留进入噪声计算。' }
    if ($t -like 'noi = sum(spec_inband)*') { return '初步把带内剩余功率求和，作为噪声加失真功率。' }
    if ($t.StartsWith('[spur, sbin] = max')) { return '找到带内剩余谱线中最大的杂散峰及其 bin。' }
    if ($t -like 'SNDR =*') { return '计算 SNDR：主信号功率除以噪声加失真功率，再转换为 dB。' }
    if ($t -like 'SFDR =*') { return '计算 SFDR：主信号峰功率与最大杂散功率的比值。' }
    if ($t -like 'ENoB =*') { return '由 SNDR 换算有效位数，公式来自理想 ADC 量化噪声关系。' }
    if ($t -like 'if(dispPlot && label && show_p)*') { return '若启用最大杂散标注，则在图上标出 SFDR 对应的 spur。' }
    if ($t -like 'plot((sbin-1)/N_fft*Fs*') { return '在最大杂散频率位置画红色菱形。' }
    if ($t -like "text((sbin-1)/N_fft*Fs*MaxSpur*") { return '在最大杂散旁添加 `MaxSpur` 文本。' }

    if ($t -eq 'if(N_run == 1)') { return '根据运行次数选择中位数噪声估计的校正系数。' }
    if ($t -like 'Mn = 0.72*') { return '单次 FFT 时采用经验校正系数，把中位数谱线换算为均值噪声功率。' }
    if ($t -like 'Mn = (1-2/(9*N_run))*') { return '多次平均时用 Wilson-Hilferty 近似校正卡方分布中位数。' }
    if ($t -like 'noi_median =*') { return '方法 1：用中位数估计每 bin 噪声，再乘以带内 bin 数得到总噪声。' }
    if ($t -like 'spec_sort = sort*') { return '把带内谱线排序，为截尾均值噪声估计做准备。' }
    if ($t -like 'noi_mean = mean*') { return '方法 2：去掉低端和高端约 5% 后求平均，降低异常尖峰影响。' }
    if ($t -like 'spec_noise = spec*') { return '复制剩余频谱，准备剔除谐波后估计噪声。' }
    if ($t -like 'for i = 2:nTHD*') { return '循环处理 THD 或谐波剔除需要的 2 到 nTHD 阶谐波。' }
    if ($t -like 'b = alias(round((bin_r-1)*i),N_fft) +1*') { return '把第 i 阶谐波折叠回频谱 bin，并加 1 转成 MATLAB 1-based 索引。' }
    if ($t -like 'spec_noise(b) = 0*') { return '把该谐波 bin 清零，使噪声估计不把谐波失真算入随机噪声。' }
    if ($t -like 'noi_exclude =*') { return '方法 3：谐波剔除后直接求带内剩余功率。' }
    if ($t -like 'if(nfmethod == 0)*') { return '若选择自动噪底方法，则综合三种估计。' }
    if ($t.StartsWith('noi = median([noi_median')) { return '自动模式取三种噪声估计值的中位数，避免单一方法偏差过大。' }
    if ($t -like 'noi_all =*') { return '保存三种噪声估计结果，用于一致性检查。' }
    if ($t -like 'if max(noi_all) / min(noi_all) >*') { return '若三种噪底估计差异超过 25%，说明频谱噪底不规则。' }
    if ($t -like "warning('plotspec:irregularNoiseFloor'*") { return '提示用户噪底估计方法分歧较大，建议手动指定 `NFMethod`。' }
    if ($t -like 'elseif(nfmethod == 1)*') { return '选择中位数法作为最终噪声功率。' }
    if ($t -like 'noi = noi_median*') { return '最终噪声功率采用中位数法结果。' }
    if ($t -like 'elseif(nfmethod == 2)*') { return '选择截尾均值法作为最终噪声功率。' }
    if ($t -like 'noi = noi_mean*') { return '最终噪声功率采用截尾均值结果。' }
    if ($t -like 'noi = noi_exclude*') { return '最终噪声功率采用谐波剔除法结果。' }
    if ($t -eq 'thd = 0;') { return '初始化 THD 线性功率累加器。' }
    if ($t -like 'thd = thd + spec(b)*') { return '累加当前谐波 bin 的功率。' }
    if ($t -like 'THD = 10*log10(thd/sigs)*') { return '计算 THD：谐波总功率与主信号参考功率之比，单位 dB。' }
    if ($t -like 'SNR = 10*log10(sig/noi)*') { return '计算 SNR：主信号功率与最终噪声功率之比。' }
    if ($t -like 'NF = SNR - pwr*') { return '计算相对 0 dBFS 的噪底指标；这里变量名 `NF` 实际表示噪声余量/噪底相关量。' }

    if ($t -like 'minx =*') { return '根据带内谱线中位数设置 y 轴下限，并限制在合理显示范围。' }
    if ($t.StartsWith('axis([Fs/N_fft')) { return '设置频谱图坐标范围：从一个 FFT bin 到 Nyquist，幅度从噪底附近到 0 dBFS。' }
    if ($t -eq 'if(label)') { return '若启用标注，开始添加带宽线、指标文字和噪底线。' }
    if ($t.StartsWith('plot([1,1]*Fs/2/OSR')) { return '画出带内带宽边界 `Fs/(2*OSR)` 的竖线。' }
    if ($t -like 'TX = 10^*') { return '对数横轴下计算文字 x 坐标，使文本靠近低频侧。' }
    if ($t -like 'if((bin-1)/N_fft < 0.2)*') { return '线性横轴下根据主信号是否靠左来选择文字位置，避免遮挡主峰。' }
    if ($t -like 'TYD =*') { return '计算指标文字的垂直间距。' }
    if ($t -like 'txt_fs =*') { return '把采样率转成带 G/M/K 或普通数字的字符串。' }
    if ($t -like 'Fin =*') { return '根据插值后的主峰 bin 估计输入信号频率。' }
    if ($t -like 'txt_fin =*') { return '把输入频率转成便于阅读的字符串。' }
    if ($t -like 'TYN = 0*') { return '初始化图中文字行号计数器。' }
    if ($t -like 'TYN = TYN + 1*') { return '文字行号加 1，让下一条指标显示在下一行。' }
    if ($t.StartsWith("text(TX,TYD*TYN,['Fin/Fs")) { return '在图上写输入频率和采样频率。' }
    if ($t.StartsWith("text(TX,TYD*TYN,['ENoB")) { return '在图上写 ENOB。' }
    if ($t.StartsWith("text(TX,TYD*TYN,['SNDR")) { return '在图上写 SNDR。' }
    if ($t.StartsWith("text(TX,TYD*TYN,['SFDR")) { return '在图上写 SFDR。' }
    if ($t.StartsWith("text(TX,TYD*TYN,['THD")) { return '在图上写 THD。' }
    if ($t.StartsWith("text(TX,TYD*TYN,['SNR")) { return '在图上写 SNR。' }
    if ($t.StartsWith("text(TX,TYD*TYN,['Noise Floor")) { return '在图上写噪底相关指标。' }
    if ($t -like "text(bin/N_fft*Fs*Sig*") { return 'OSR 图中在主峰附近标出信号功率。' }
    if ($t.StartsWith('semilogx([Fs/N_fft')) { return '对数横轴下画噪声谱密度参考线。' }
    if ($t.StartsWith("text(TX,TYD*TYN,['NSD")) { return '在图上写 NSD，也就是归一化到 1 Hz 带宽的噪声谱密度。' }
    if ($t.StartsWith("text(TX,TYD*TYN,['OSR")) { return '在图上写 OSR 数值。' }
    if ($t.StartsWith('plot([0,Fs/2]')) { return '线性横轴下画 NSD 参考水平线。' }
    if ($t -like "xlabel('Freq (Hz)'*") { return '设置 x 轴标签为频率 Hz。' }
    if ($t -like "ylabel('dBFS'*") { return '设置 y 轴标签为 dBFS。' }
    if ($t -like "title(sprintf('Power Spectrum (%dx Coherently Averaged)'*") { return '相干平均模式下设置标题，说明运行次数。' }
    if ($t -like "title(sprintf('Power Spectrum (%dx Averaged)'*") { return '普通平均模式下设置标题，说明运行次数。' }
    if ($t -like "title('Power Spectrum'*") { return '单次运行时设置普通频谱标题。' }

    if ($t -match '^(enob|sndr|sfdr|snr|thd|sigpwr|noi|nsd) =') { return '把内部计算变量映射到函数输出；注意输出 `noi` 对应这里的 `NF`，`nsd` 为 dBFS/Hz。' }
    if ($t -like 'if(~dispPlot)*') { return '如果没有绘图，则图形句柄输出为空。' }
    if ($t -eq 'h = [];') { return '无图模式返回空句柄，调用者可安全忽略第 9 个输出。' }
    if ($t -like 'function w = rectwin_emb*') { return '定义嵌套矩形窗函数；嵌套函数只能在 `plotspec` 内部直接调用。' }
    if ($t -like 'w = ones*') { return '矩形窗就是全 1 向量，相当于不加窗。' }
    if ($t -like 'function w = hannwin*') { return '定义嵌套 Hann 窗函数；避免依赖 Signal Processing Toolbox 的 `hann`。' }
    if ($t -like 'if N == 1*') { return '处理长度为 1 的边界情况，避免除法或向量公式异常。' }
    if ($t -eq 'w = 1;') { return '单点窗的值定义为 1。' }
    if ($t -like 'n = 0:(N-1)*') { return '生成 Hann 窗的离散样本序号。' }
    if ($t -like 'w = 0.5 * (1 - cos*') { return '计算周期 Hann 窗；这里分母用 `N`，适合 FFT 周期窗思想。' }

    return '执行当前代码块中的一步具体计算或绘图操作；建议结合本表前后行和上方算法章节理解其输入、输出和副作用。'
}

function Explain-AliasLine([int]$n, [string]$line) {
    $t = $line.Trim()
    $common = Explain-Common $t
    if ($n -eq 1) { return '定义 `alias(fin,fs)` 函数；输入原始频率和采样频率，输出折叠到第一 Nyquist 带的频率。' }
    if ($n -ge 2 -and $n -le 35) { return '函数帮助文本；解释别名折叠、输入输出、例子和 Nyquist 区规则。' }
    if ($null -ne $common) { return $common }
    if ($t -eq 'if fs <= 0') { return '检查采样频率是否为正；采样频率为 0 或负数没有物理意义。' }
    if ($t -like "error('alias:invalidFs'*") { return '采样频率非法时抛出带 ID 的错误，方便调用者捕获。' }
    if ($t -like 'if(~isreal(fin)*') { return '检查输入频率和采样频率是否为实数；复频率不适用于这里的折叠公式。' }
    if ($t -like "error('alias:invalidInput'*") { return '输入存在复数时抛出错误。' }
    if ($t -like 'nyquistZone =*') { return '计算 0-based Nyquist 区编号；每个区宽度是 `fs/2`。' }
    if ($t -like 'baseOffset =*') { return '计算输入频率在一个采样周期 `fs` 内的余量，类似取模。' }
    if ($t -like 'isEvenZone =*') { return '判断 Nyquist 区编号是否为偶数；偶数区正常折叠，奇数区镜像折叠。' }
    if ($t -like 'fal = isEvenZone*') { return '用向量化表达式同时处理标量和数组：偶数区输出 `baseOffset`，奇数区输出 `fs-baseOffset`。' }
    return '执行别名折叠函数中的一行辅助计算；结合 Nyquist 区解释理解。'
}

$intro = @'
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

'@

$lines = New-Object System.Collections.Generic.List[string]
$intro -split "`n" | ForEach-Object { $lines.Add($_) }
$lines.Add('')
$lines.Add('## `plotspec.m` 逐行解析')
$lines.Add('')
$lines.Add('下表按复制到示例包中的 `plotspec.m` 真实行号展开。代码列保留原行内容；解释列说明 MATLAB 语法作用和信号处理意义。')
$lines.Add('')
$lines.Add('| 行号 | 代码 | 解释 |')
$lines.Add('| ---: | --- | --- |')
$psLines = Get-Content -LiteralPath $plotspec
for ($i = 0; $i -lt $psLines.Count; $i++) {
    $lineNo = $i + 1
    $code = Escape-MdCell $psLines[$i]
    $exp = Explain-PlotSpecLine $lineNo $psLines[$i]
    $lines.Add("| $lineNo | $code | $exp |")
}

$lines.Add('')
$lines.Add('## `alias.m` 逐行解析')
$lines.Add('')
$lines.Add('`alias.m` 是本示例包必须携带的依赖。它很短，但对谐波折叠、THD、SFDR 标注都很关键。')
$lines.Add('')
$lines.Add('| 行号 | 代码 | 解释 |')
$lines.Add('| ---: | --- | --- |')
$aLines = Get-Content -LiteralPath $alias
for ($i = 0; $i -lt $aLines.Count; $i++) {
    $lineNo = $i + 1
    $code = Escape-MdCell $aLines[$i]
    $exp = Explain-AliasLine $lineNo $aLines[$i]
    $lines.Add("| $lineNo | $code | $exp |")
}

$tail = @'

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
'@
$tail -split "`n" | ForEach-Object { $lines.Add($_) }

Set-Content -LiteralPath $out -Value $lines -Encoding UTF8
Write-Host "Wrote $out with $($lines.Count) lines."
