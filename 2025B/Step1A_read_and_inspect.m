%% Step1A_read_and_inspect.m
% =========================================================================
%  2025年全国大学生数学建模竞赛 B 题 —— 碳化硅外延层厚度的确定
%  第一阶段 Step 1A：原始数据读取 + 数据结构检查 + 原始光谱可视化
%
%  本脚本只完成以下工作（不做任何后续建模）：
%    1. 读取附件1~4（按列位置读取前两列，不依赖列名）；
%    2. 建立 SiC_10 / SiC_15 / Si_10 / Si_15 四组数据；
%    3. 数据结构检查（行数、列数、极值、缺失值、Inf、非有限值、重复波数、波数顺序）；
%    4. 波数采样间隔统计（平均/中位数/标准差/最小/最大）；
%    5. 绘制四组原始光谱（不平滑、不滤波、不删除任何数据点）；
%    6. 输出数据质量报告。
%
%  注意：本阶段严禁滤波、平滑、FFT、插值、峰谷检测、基线校正、
%        折射率计算、厚度计算等一切后续处理。
% =========================================================================

clear; clc; close all;

%% =====================================================================
%  第一部分：读取四组原始数据
%  ---------------------------------------------------------------------
%  使用 readtable 读取 Excel；不假设列名固定，按列位置取第1列(波数)
%  和第2列(反射率 %)。原始百分比反射率保留在 Reflectance_percent，
%  另建 Reflectance = Reflectance_percent / 100，不覆盖原始数据。
% =====================================================================
files  = {'附件1.xlsx', '附件2.xlsx', '附件3.xlsx', '附件4.xlsx'};
names  = {'SiC_10', 'SiC_15', 'Si_10', 'Si_15'};
titles = {'SiC，入射角10°', 'SiC，入射角15°', '硅，入射角10°', '硅，入射角15°'};

% 预声明结构体数组的全部字段，便于按索引赋值
Data = struct('name', {}, 'title', {}, 'sortedForPlot', {}, ...
              'Wavenumber', {}, 'Reflectance_percent', {}, 'Reflectance', {});
for k = 1:4
    D = loadSpectrum(files{k});               % 读取单个文件的前两列
    D.name  = names{k};                       % 数据组名
    D.title = titles{k};                      % 中文标题（用于图与报告）
    D.sortedForPlot = false;                  % 记录绘图时是否发生排序
    Data(k) = D;
end

% 按题目要求建立四组独立的工作区变量
SiC_10 = Data(1);
SiC_15 = Data(2);
Si_10  = Data(3);
Si_15  = Data(4);

%% =====================================================================
%  第二部分：数据结构检查与波数采样间隔分析
%  ---------------------------------------------------------------------
%  checkDataset 对每组数据做完整检查，返回一个统计结果结构体。
% =====================================================================
S = checkDataset(Data(1));                    % 第 1 组数据检查结果
for k = 2:4                                   % 追加第 2~4 组，保证字段一致
    S(k) = checkDataset(Data(k));
end

%% =====================================================================
%  第三部分：绘制四组原始光谱
%  ---------------------------------------------------------------------
%  plotSpectrum 使用原始数据绘图（不平滑、不滤波、不删除数据点）。
%  若波数原始数据为降序，则仅在绘图内部按升序重排，并返回排序标记；
%  原始数据本身不作任何改动。
% =====================================================================
for k = 1:4
    Data(k).sortedForPlot = plotSpectrum(Data(k), k);
end

%% =====================================================================
%  第四部分：输出数据质量报告
% =====================================================================
for k = 1:4
    printReport(Data(k), S(k));
end

% -------------------------------------------------------------------------
%  局部函数：读取单个 Excel 文件（按列位置取前两列）
% -------------------------------------------------------------------------
function D = loadSpectrum(xlsxFile)
    % 读取表格；保留原始表头，避免因非ASCII表头引发变量名警告
    T = readtable(xlsxFile, 'VariableNamingRule', 'preserve');
    wav = T{:, 1};                            % 第1列：波数 (cm^-1)，按位置取
    refl = T{:, 2};                           % 第2列：反射率 (%)
    D.Wavenumber = wav(:);                    % 统一为列向量
    D.Reflectance_percent = refl(:);          % 原始百分比反射率（保留）
    D.Reflectance = D.Reflectance_percent / 100;  % 小数反射率（另建，不覆盖原始）
end

% -------------------------------------------------------------------------
%  局部函数：数据结构与质量检查
% -------------------------------------------------------------------------
function S = checkDataset(D)
    wav  = D.Wavenumber;
    refl = D.Reflectance_percent;

    % ---- 基本结构 ----
    S.nRows    = numel(wav);                  % 数据行数
    S.nCols    = 2;                           % 本阶段只用前两列（波数、反射率）
    S.wavMin   = min(wav);                    % 波数最小值
    S.wavMax   = max(wav);                    % 波数最大值
    S.reflMin  = min(refl);                   % 反射率最小值
    S.reflMax  = max(refl);                   % 反射率最大值

    % ---- 数据质量 ----
    S.nMissing   = sum(ismissing(wav)) + sum(ismissing(refl));   % 缺失值(NaN/空)
    S.nInf       = sum(isinf(wav)) + sum(isinf(refl));           % Inf 数量
    S.nNonFinite = sum(~isfinite(wav)) + sum(~isfinite(refl));   % 非有限值总数
    S.nDupWav    = numel(wav) - numel(unique(wav));              % 重复波数数量

    % ---- 波数顺序判断 ----
    dW = diff(wav);
    S.isAscending  = all(dW > 0);             % 严格升序
    S.isDescending = all(dW < 0);             % 严格降序
    S.hasDupWav    = any(dW == 0);            % 存在重复波数
    S.isUnordered  = ~(all(dW >= 0) || all(dW <= 0));  % 存在无序数据

    % ---- 采样间隔统计（先不做等间隔假设，交由数据说话）----
    S.dW       = dW;
    S.dWMean   = mean(dW);                    % 平均采样间隔
    S.dWMedian = median(dW);                  % 中位数采样间隔
    S.dWStd    = std(dW);                     % 采样间隔标准差
    S.dWMin    = min(dW);                     % 最小采样间隔
    S.dWMax    = max(dW);                     % 最大采样间隔
end

% -------------------------------------------------------------------------
%  局部函数：绘制单组原始光谱
% -------------------------------------------------------------------------
function sortedFlag = plotSpectrum(D, figNum)
    wav  = D.Wavenumber;
    refl = D.Reflectance_percent;
    sortedFlag = false;

    % 若原始波数为降序：仅为绘图方便按升序重排，并记录发生过排序
    if wav(1) > wav(end)
        [wav, idx] = sort(wav);
        refl = refl(idx);
        sortedFlag = true;
    end

    figure(figNum);                          % 四张图分别对应 figure 1~4
    plot(wav, refl, 'LineWidth', 0.8);
    xlabel('Wavenumber (cm^{-1})');          % tex 解释器将 ^{ -1 } 渲染为上标
    ylabel('Reflectance (%)');
    title(D.title);
    grid on;
    box  on;
    set(gcf, 'Color', 'w');                  % 白色图窗背景，提高可读性
end

% -------------------------------------------------------------------------
%  局部函数：打印单组数据质量报告
% -------------------------------------------------------------------------
function printReport(D, S)
    fprintf('\n==============================\n');
    fprintf('数据集：%s\n', D.title);
    fprintf('==============================\n');
    fprintf('数据点数：%d\n', S.nRows);
    fprintf('数据列数：%d\n', S.nCols);
    fprintf('波数范围：[%.4f, %.4f] cm^{-1}\n', S.wavMin, S.wavMax);
    fprintf('反射率范围：[%.4f, %.4f] %%\n', S.reflMin, S.reflMax);
    fprintf('缺失值数量：%d\n', S.nMissing);
    fprintf('Inf 数量：%d\n', S.nInf);
    fprintf('非有限值数量：%d\n', S.nNonFinite);
    fprintf('重复波数数量：%d\n', S.nDupWav);

    % 波数顺序判定结果
    if S.isAscending
        orderStr = '严格升序';
    elseif S.isDescending
        orderStr = '严格降序';
    elseif S.isUnordered
        orderStr = '存在无序';
    else
        orderStr = '非严格单调（存在重复波数或平段）';
    end
    fprintf('波数顺序：%s\n', orderStr);

    % 采样间隔统计
    fprintf('平均采样间隔：%.6f cm^{-1}\n', S.dWMean);
    fprintf('中位数采样间隔：%.6f cm^{-1}\n', S.dWMedian);
    fprintf('采样间隔标准差：%.6f cm^{-1}\n', S.dWStd);
    fprintf('最小采样间隔：%.6f cm^{-1}\n', S.dWMin);
    fprintf('最大采样间隔：%.6f cm^{-1}\n', S.dWMax);

    % 绘图排序记录
    if D.sortedForPlot
        fprintf('绘图排序：原始波数为降序，绘图时已按升序重排（仅用于绘图，原始数据未改动）\n');
    else
        fprintf('绘图排序：未发生排序（保持原始顺序绘图）\n');
    end
end
