%% main_retention.m —— 问题3 客户挽留策略建模（基于优化 Logistic 模型）
%  功能：读取 B_processed.csv（删除总费用缺失样本 11 行 → 7032 个有效客户），
%        读取优化 Logistic 模型的原始尺度 β 系数（Optimized_Logistic_beta.xlsx），
%        计算 7032 个客户的流失概率 p = 1/(1+exp(-z))，z = β0 + Σβi·xi（13 个变量），
%        依据经济损失决策模型（挽留成本 C=150，挽留成功率 q=0.35，
%        客户流失损失 L=2000）推导临界概率 π = C/(q·L) = 150/700 ≈ 0.2142857，
%        判定 p >= π 建议挽留，否则无需挽留；输出挽留名单、统计与分布图。
%
%  环境：MATLAB R2025a（仅基础函数，不使用统计/机器学习工具箱）
%  数据：../01_数据预处理/B_processed.csv（与第二问优化模型读取一致）
%  模型：../06_Logistic流失判定/优化Logistic模型/Optimized_Logistic_beta.xlsx
%
%  输出（保存在本文件夹 08_客户挽留策略/）：
%    retention_probability.xlsx              全部 7032 客户：编号/真实标签/预测概率p/临界概率π/是否建议挽留
%    retention_result.xlsx                   建议挽留客户名单：编号/预测流失概率/真实流失标签
%    retention_statistics.xlsx               挽留策略统计（总数/挽留人数/比例/覆盖情况）
%    retention_probability_distribution.png  流失概率分布直方图（含 π 阈值线）
%
%  运行方式：MATLAB 命令行直接执行 main_retention

clc; clear; close all;

%% ---------- 0) 定位工作目录（相对路径；不覆盖已有文件） ----------
scriptDir = fileparts(mfilename('fullpath'));
if ~isempty(scriptDir)
    cd(scriptDir);                        % 切换到 08_客户挽留策略/
end
outDir = pwd;

% 不覆盖已有文件：若任一输出文件已存在则停止
outFiles = {'retention_probability.xlsx'; 'retention_result.xlsx'; ...
            'retention_statistics.xlsx'; 'retention_probability_distribution.png'};
for k = 1:numel(outFiles)
    if isfile(fullfile(outDir, outFiles{k}))
        error('[main_retention] 输出文件已存在（遵守"不覆盖已有文件"，已停止）：%s\n请移动或删除该文件后重新运行。', ...
            fullfile(outDir, outFiles{k}));
    end
end

fprintf('======== 问题3：客户挽留策略建模（基于优化 Logistic 模型） ========\n');

%% ---------- 1) 读取数据：B_processed.csv，删除总费用缺失样本 ----------
csvFile = fullfile(pwd, '..', '01_数据预处理', 'B_processed.csv');
if ~isfile(csvFile)
    error('[main_retention] 未找到数据文件：%s\n请先运行 01_数据预处理/main_preprocess.m。', csvFile);
end
data = readtable(csvFile, 'VariableNamingRule', 'preserve');
bad     = isnan(data.('总费用'));        % 总费用缺失样本（11 行）
custID  = find(~bad);                    % 保留样本在 B_processed.csv 中的原始行号 = 客户编号
data(bad, :) = [];
N       = height(data);                  % 7032
Y       = data.('是否流失');             % 真实流失标签（Y=1 流失，Y=0 未流失）
fprintf('读取数据成功：%d 个有效客户。\n', N);

%% ---------- 2) 读取优化 Logistic 模型 β（原始尺度） ----------
betaFile = fullfile(pwd, '..', '06_Logistic流失判定', '优化Logistic模型', 'Optimized_Logistic_beta.xlsx');
if ~isfile(betaFile)
    error('[main_retention] 未找到优化模型 β 文件：%s', betaFile);
end
betaTbl  = readtable(betaFile, 'VariableNamingRule', 'preserve');
betaOrig = betaTbl.('β原始尺度');        % 原始尺度 β（含截距，14×1）
varCol   = betaTbl.('变量名称');         % 变量名称（14×1）
if iscell(varCol), varCol = string(varCol); end
beta0    = betaOrig(1);                  % 截距 β0
betaFeat = betaOrig(2:end);              % 13 个变量的原始尺度 β
numVars  = numel(betaFeat);
fprintf('读取优化 Logistic 模型成功：Optimized_Logistic_beta.xlsx\n');
fprintf('变量数量：%d。\n', numVars);

% 校验：变量数量与顺序必须与 Optimized_Logistic_beta.xlsx 完全一致
expectedVars = {'是否为老年人'; '是否有伴侣'; '是否有家属'; ...
                '是否开通在线安全'; '是否开通在线备份'; '是否开通设备保护'; ...
                '是否开通技术支持'; '是否开通电视流媒体'; '是否开通电影流媒体'; ...
                '合同类型'; '是否使用电子账单'; '支付方式'; '在网时长（月）'};
if numVars ~= 13
    error('[main_retention] 优化模型变量数量应为 13，实际为 %d，请检查 %s。', numVars, betaFile);
end
if ~all(strcmp(varCol(2:end), expectedVars))
    error('[main_retention] 优化模型变量顺序与预期不一致，请检查 %s。', betaFile);
end

%% ---------- 3) 提取 13 个变量并按 β 顺序构建设计矩阵（原始尺度） ----------
X_raw = table2array(data(:, expectedVars));   % 7032×13，顺序与 β 表一致
if any(any(isnan(X_raw), 2))                  % 防御性检查
    warning('[main_retention] 输入变量中存在缺失值，请检查数据。');
end
X = [ones(N, 1), X_raw];                      % 7032×14（含截距列）

%% ---------- 4) 计算客户流失概率 p = 1/(1+exp(-z)) ----------
z = X * [beta0; betaFeat(:)];
p = zeros(N, 1);
pos = z >= 0;                                 % 数值稳定的 sigmoid
p(pos)  = 1 ./ (1 + exp(-z(pos)));
p(~pos) = exp(z(~pos)) ./ (1 + exp(z(~pos)));

%% ---------- 5) 经济损失决策模型：临界概率 π ----------
C = 150;      % 挽留成本
q = 0.35;     % 挽留成功率
L = 2000;     % 客户流失损失
% 不挽留期望损失 E0 = p·L
% 挽留期望损失   E1 = C + (1-q)·p·L
% E0 = E1  →  p·L = C + (1-q)·p·L  →  π = C / (q·L) = 150 / 700 ≈ 0.2142857
piStar = C / (q * L);                        % 0.214285714285714
retain = p >= piStar;                        % 建议挽留标记（逻辑向量）
retainStr = repmat("否", N, 1);
retainStr(retain) = "是";

%% ---------- 6) 输出 1：retention_probability.xlsx（全部 7032 客户） ----------
probTbl = table(custID, Y, p, repmat(piStar, N, 1), retainStr, ...
    'VariableNames', {'客户编号', '真实流失标签', '预测流失概率p', '临界概率π', '是否建议挽留'});
probFile = fullfile(outDir, 'retention_probability.xlsx');
writetable(probTbl, probFile, 'Sheet', '挽留概率', 'WriteMode', 'overwritesheet');
fprintf('已保存：retention_probability.xlsx（全部 %d 客户）。\n', N);

%% ---------- 7) 输出 2：retention_result.xlsx（建议挽留客户名单） ----------
retainIdx = find(retain);
resTbl = table(custID(retainIdx), p(retainIdx), Y(retainIdx), ...
    'VariableNames', {'客户编号', '预测流失概率', '真实流失标签'});
resFile = fullfile(outDir, 'retention_result.xlsx');
writetable(resTbl, resFile, 'Sheet', '挽留名单', 'WriteMode', 'overwritesheet');
nRetain = numel(retainIdx);
fprintf('已保存：retention_result.xlsx（建议挽留 %d 人）。\n', nRetain);

%% ---------- 8) 输出 3：retention_statistics.xlsx（统计） ----------
nChurn   = sum(Y == 1);                       % 真实流失人数
nCover   = sum(Y == 1 & retain);              % 成功覆盖的潜在流失客户数（真实流失且建议挽留）
coverage = nCover / nChurn;                   % 挽留覆盖率
statNames = {'客户总数'; '建议挽留人数'; '建议挽留比例'; '真实流失人数'; ...
             '成功覆盖的潜在流失客户数'; '挽留覆盖率'};
statVals  = [N; nRetain; nRetain / N; nChurn; nCover; coverage];
statsTbl  = table(statNames, statVals, 'VariableNames', {'指标', '数值'});
statsFile = fullfile(outDir, 'retention_statistics.xlsx');
writetable(statsTbl, statsFile, 'Sheet', '挽留统计', 'WriteMode', 'overwritesheet');
fprintf('已保存：retention_statistics.xlsx。\n');

%% ---------- 9) 输出 4：retention_probability_distribution.png（流失概率分布直方图） ----------
% 中文字体设置（无 CJK 字体时自动回退默认，不影响运行）
try
    fnts = listfonts;
    cjkFonts = {'PingFang SC', 'Hiragino Sans GB', 'Microsoft YaHei', 'SimHei', ...
                'STHeiti', 'Songti SC', 'Noto Sans CJK SC'};
    for i = 1:numel(cjkFonts)
        if any(strcmpi(fnts, cjkFonts{i}))
            set(0, 'DefaultAxesFontName', cjkFonts{i});
            set(0, 'DefaultTextFontName', cjkFonts{i});
            break;
        end
    end
catch
end

fig = figure('Color', 'w', 'Position', [100 100 920 620]);
histogram(p, 50, 'FaceColor', [0.35 0.55 0.85], 'EdgeColor', 'none');
hold on;
yl = ylim;
plot([piStar piStar], yl, 'r--', 'LineWidth', 2);              % 决策阈值线 π
text(piStar, yl(2) * 0.97, sprintf('π = %.7f', piStar), ...
    'Color', 'r', 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
xlabel('客户流失概率 p');
ylabel('客户数量');
title('客户流失概率分布与挽留决策阈值');
legend({'客户流失概率分布', '决策阈值 π = 150/700'}, 'Location', 'north');
grid on; box on;
saveas(fig, fullfile(outDir, 'retention_probability_distribution.png'));
close(fig);
fprintf('已保存：retention_probability_distribution.png。\n');

%% ---------- 10) 完成 ----------
fprintf('\n====================================\n');
fprintf('客户挽留策略计算完成\n');
fprintf('临界概率：π=%.7f\n', piStar);
fprintf('客户总数：%d\n', N);
fprintf('建议挽留人数：%d\n', nRetain);
fprintf('====================================\n');
