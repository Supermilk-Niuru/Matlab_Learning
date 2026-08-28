%% Step1B_peak_valley.m
% =========================================================================
%  2025年全国大学生数学建模竞赛 B 题 —— 碳化硅外延层厚度的确定
%  第二阶段 Step 1B：原始干涉光谱的候选极大/极小值（峰/谷）探索
%
%  本阶段仅做探索性峰谷检测，检测结果一律记为“候选极值”：
%    - 不建立厚度模型 / 不计算厚度 / 不拟合折射率
%    - 不进行多光束干涉分析 / 不进行FFT / 不进行最终结论判断
%  最终哪些峰谷真正用于厚度计算，需依据峰谷间距、条纹连续性、
%  光谱形状与物理模型进一步判断。
% =========================================================================

clear; clc; close all;

%% ================= 探索性参数（集中定义，勿散落代码各处） =================
% findpeaks 参数（反射率单位均为 %）
% 说明：数据逐点波动极小（均值约0.01%），prominence=0.5 已可忽略噪声，
%       同时能捕获高波数端幅度<1%的弱干涉条纹（探索性阈值，不取过严）。
minPeakProminence = 0.5;    % 峰显著性阈值：候选峰必须比邻近谷高/低至少该值
minPeakDistance   = 10;     % 峰间最小波数距离 (cm^-1)，低于该间隔的小峰视为重复/噪声

% 分析区间（仅用于峰谷检测；原始数据全部保留，不删除区间外数据）
SiC_interval = [1050, 4000];   % 碳化硅：避开 1050 cm^-1 以下的本征强吸收结构
Si_interval  = [400,  4000];   % 硅：全波段分析

%% ================= 加载四组原始数据（复用 Step1A 读取逻辑） =================
files  = {'附件1.xlsx', '附件2.xlsx', '附件3.xlsx', '附件4.xlsx'};
names  = {'SiC_10', 'SiC_15', 'Si_10', 'Si_15'};
titles = {'SiC，入射角10°', 'SiC，入射角15°', '硅，入射角10°', '硅，入射角15°'};
intervals = {SiC_interval, SiC_interval, Si_interval, Si_interval};

Data = struct('name', {}, 'title', {}, 'interval', {}, ...
              'Wavenumber', {}, 'Reflectance_percent', {}, 'Reflectance', {});
for k = 1:4
    D = loadSpectrum(files{k});          % 读取原始数据，不做任何修改
    D.name  = names{k};
    D.title = titles{k};
    D.interval = intervals{k};
    Data(k) = D;
end

SiC_10 = Data(1);  SiC_15 = Data(2);  Si_10 = Data(3);  Si_15 = Data(4);

%% ================= 候选峰 / 谷检测 =================
[Peaks_SiC_10, Valleys_SiC_10] = detectExtrema(Data(1), minPeakProminence, minPeakDistance);
[Peaks_SiC_15, Valleys_SiC_15] = detectExtrema(Data(2), minPeakProminence, minPeakDistance);
[Peaks_Si_10,  Valleys_Si_10 ] = detectExtrema(Data(3), minPeakProminence, minPeakDistance);
[Peaks_Si_15,  Valleys_Si_15 ] = detectExtrema(Data(4), minPeakProminence, minPeakDistance);

%% ================= 绘图：原始曲线 + 候选峰 + 候选谷 =================
Peaks   = {Peaks_SiC_10, Peaks_SiC_15, Peaks_Si_10, Peaks_Si_15};
Valleys = {Valleys_SiC_10, Valleys_SiC_15, Valleys_Si_10, Valleys_Si_15};
for k = 1:4
    plotSpectrumWithExtrema(Data(k), Peaks{k}, Valleys{k}, k);
end

%% ================= 命令窗口输出（按波数升序） =================
for k = 1:4
    fprintf('\n===================== %s =====================\n', Data(k).title);
    fprintf('分析区间：%.0f ~ %.0f cm^{-1}\n', Data(k).interval(1), Data(k).interval(2));
    fprintf('候选峰数量：%d\n', numel(Peaks{k}.Wavenumber));
    fprintf('候选谷数量：%d\n', numel(Valleys{k}.Wavenumber));
    fprintf('--- 候选峰（波数 cm^{-1} | 反射率 %% | 原始下标）---\n');
    for j = 1:numel(Peaks{k}.Wavenumber)
        fprintf('%9.2f | %9.4f | %d\n', Peaks{k}.Wavenumber(j), Peaks{k}.Reflectance(j), Peaks{k}.Index(j));
    end
    fprintf('--- 候选谷（波数 cm^{-1} | 反射率 %% | 原始下标）---\n');
    for j = 1:numel(Valleys{k}.Wavenumber)
        fprintf('%9.2f | %9.4f | %d\n', Valleys{k}.Wavenumber(j), Valleys{k}.Reflectance(j), Valleys{k}.Index(j));
    end
end

%% ================= 保存结果到 .mat =================
save('Step1B_peak_valley.mat', ...
     'Peaks_SiC_10', 'Valleys_SiC_10', ...
     'Peaks_SiC_15', 'Valleys_SiC_15', ...
     'Peaks_Si_10',  'Valleys_Si_10', ...
     'Peaks_Si_15',  'Valleys_Si_15');
fprintf('\n结果已保存：Step1B_peak_valley.mat\n');

% =========================================================================
%  局部函数
% =========================================================================

% ---- 读取单个 Excel 文件的前两列（按列位置，不依赖列名）----
function D = loadSpectrum(xlsxFile)
    T = readtable(xlsxFile, 'VariableNamingRule', 'preserve');
    D.Wavenumber = T{:, 1}(:);              % 原始波数 cm^{-1}
    D.Reflectance_percent = T{:, 2}(:);     % 原始百分比反射率
    D.Reflectance = D.Reflectance_percent / 100;  % 小数反射率（不覆盖原始）
end

% ---- 对单组数据在指定区间内检测候选峰(P)与候选谷(V) ----
function [P, V] = detectExtrema(D, minProm, minDist)
    wav = D.Wavenumber;
    R   = D.Reflectance_percent;

    % 仅在本阶段分析区间内检测；区间外原始数据保持不动
    sel   = wav >= D.interval(1) & wav <= D.interval(2);
    w     = wav(sel);
    r     = R(sel);

    % 候选极大值：直接对反射率使用 findpeaks
    [pksP, locsP, ~, promP] = findpeaks(r, w, ...
        'MinPeakProminence', minProm, 'MinPeakDistance', minDist);
    P.Wavenumber  = locsP(:);                 % 波数（升序）
    P.Reflectance = pksP(:);                  % 原始百分比反射率
    P.Prominence  = promP(:);                 % 峰显著性
    [~, P.Index]  = ismember(P.Wavenumber, wav);   % 在完整数据中的下标

    % 候选极小值：对反射率取负后使用 findpeaks
    [pksV, locsV, ~, promV] = findpeaks(-r, w, ...
        'MinPeakProminence', minProm, 'MinPeakDistance', minDist);
    V.Wavenumber  = locsV(:);                 % 波数（升序）
    V.Reflectance = -pksV(:);                 % 还原为原始反射率
    V.Prominence  = promV(:);
    [~, V.Index]  = ismember(V.Wavenumber, wav);

    % 保险起见按波数升序排列
    [P.Wavenumber, oP] = sort(P.Wavenumber); P.Reflectance = P.Reflectance(oP);
    P.Prominence = P.Prominence(oP); P.Index = P.Index(oP);
    [V.Wavenumber, oV] = sort(V.Wavenumber); V.Reflectance = V.Reflectance(oV);
    V.Prominence = V.Prominence(oV); V.Index = V.Index(oV);
end

% ---- 绘制单组原始光谱 + 候选峰/谷 ----
function plotSpectrumWithExtrema(D, P, V, figNum)
    wav = D.Wavenumber;
    R   = D.Reflectance_percent;

    figure(figNum);
    plot(wav, R, 'k-', 'LineWidth', 0.8); hold on;

    % 浅色底纹标出本次峰谷检测的分析区间
    yl = get(gca, 'YLim');
    patch([D.interval(1), D.interval(2), D.interval(2), D.interval(1)], ...
          [yl(1), yl(1), yl(2), yl(2)], [0.92 0.96 1.0], ...
          'FaceAlpha', 0.5, 'EdgeColor', 'none');
    plot(wav, R, 'k-', 'LineWidth', 0.8);    % 底纹之上重画原始曲线

    % 候选极大值（红上三角）与候选极小值（蓝下三角）
    plot(P.Wavenumber, P.Reflectance, '^', 'MarkerSize', 6, ...
         'MarkerFaceColor', [1 0.2 0.2], 'MarkerEdgeColor', 'k');
    plot(V.Wavenumber, V.Reflectance, 'v', 'MarkerSize', 6, ...
         'MarkerFaceColor', [0.1 0.4 1], 'MarkerEdgeColor', 'k');

    % 标出对应波数（小字号，峰在上方、谷在下方）
    yspan = yl(2) - yl(1);
    for j = 1:numel(P.Wavenumber)
        text(P.Wavenumber(j), P.Reflectance(j) + 0.02*yspan, ...
             sprintf('%.0f', P.Wavenumber(j)), ...
             'FontSize', 6, 'HorizontalAlignment', 'center', 'Color', [0.7 0 0]);
    end
    for j = 1:numel(V.Wavenumber)
        text(V.Wavenumber(j), V.Reflectance(j) - 0.02*yspan, ...
             sprintf('%.0f', V.Wavenumber(j)), ...
             'FontSize', 6, 'HorizontalAlignment', 'center', 'Color', [0 0 0.7]);
    end

    xlabel('Wavenumber (cm^{-1})');
    ylabel('Reflectance (%)');
    title(sprintf('%s  （候选峰%d个，候选谷%d个）', D.title, numel(P.Wavenumber), numel(V.Wavenumber)));
    grid on; box on;
    set(gcf, 'Color', 'w');
    set(gca, 'Toolbar', []);                 % 关闭坐标轴浮动工具栏，保证导出图像干净
    legend({'原始反射率', '候选极大值', '候选极小值'}, 'Location', 'best');
    hold off;
end
