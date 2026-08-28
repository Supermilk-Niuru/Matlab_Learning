%% main_retention_dual_threshold.m —— 问题3 双阈值客户挽留策略（高风险 p>0.7 不挽留）
%  本程序仅使用优化 Logistic 模型
%  删除变量：互联网服务类型、月费用、总费用
%  β参数来源：06_Logistic流失判定/优化Logistic模型/Optimized_Logistic_beta.xlsx
%  （严禁使用原始 Logistic 模型的 Logistic_beta.xlsx / Logistic方程.txt）
%
%  功能：读取 B_processed.csv（删除总费用缺失样本 11 行 → 7032 个有效客户），
%        读取优化 Logistic 模型原始尺度 β，计算 7032 个客户的流失概率
%        p = 1/(1+exp(-z))，z = β0 + Σβj·xj（13 个变量），
%        应用双阈值规则：经济临界概率 π = C/(qL) = 150/700 ≈ 0.2142857，
%        高风险上限 pmax = 0.7。
%          p < π          → 不挽留（低风险）
%          π ≤ p ≤ 0.7    → 建议挽留
%          p > 0.7        → 不挽留（高风险，明确区分，不纳入挽留名单）
%        输出全部客户概率表、挽留名单、三类客户统计、新旧策略比较与分布图。
%
%  环境：MATLAB R2025a（仅基础函数，不使用统计/机器学习工具箱）
%  数据：../01_数据预处理/B_processed.csv（与第二问优化模型读取一致）
%  模型：../06_Logistic流失判定/优化Logistic模型/Optimized_Logistic_beta.xlsx
%  说明：不修改 08_客户挽留策略/ 中任何已有文件，全部新结果保存于本文件夹。
%
%  输出（保存在本文件夹 09_客户挽留策略_双阈值优化/）：
%    retention_probability_dual_threshold.xlsx  全部 7032 客户概率与最终决策
%    retention_result_dual_threshold.xlsx       建议挽留名单（π ≤ p ≤ 0.7）
%    retention_statistics_dual_threshold.xlsx   总体统计 / 三类画像 / 新旧比较（3 个 Sheet）
%    retention_probability_dual_threshold.png   流失概率分布 + 双阈值线 + 三区域标注
%
%  运行方式：MATLAB 命令行直接执行 main_retention_dual_threshold

clc; clear; close all;

%% ---------- 0) 定位工作目录（相对路径；不覆盖已有文件） ----------
scriptDir = fileparts(mfilename('fullpath'));
if ~isempty(scriptDir)
    cd(scriptDir);                        % 切换到 09_客户挽留策略_双阈值优化/
end
outDir = pwd;

% 不覆盖已有文件：若任一输出文件已存在则停止
outFiles = {'retention_probability_dual_threshold.xlsx'; ...
            'retention_result_dual_threshold.xlsx'; ...
            'retention_statistics_dual_threshold.xlsx'; ...
            'retention_probability_dual_threshold.png'};
for k = 1:numel(outFiles)
    if isfile(fullfile(outDir, outFiles{k}))
        error('[main_retention_dual_threshold] 输出文件已存在（遵守"不覆盖已有文件"，已停止）：%s\n请移动或删除该文件后重新运行。', ...
            fullfile(outDir, outFiles{k}));
    end
end

fprintf('======== 第三问：双阈值客户挽留策略 ========\n\n');

%% ---------- 1) 读取数据：B_processed.csv，删除总费用缺失样本 ----------
csvFile = fullfile(pwd, '..', '01_数据预处理', 'B_processed.csv');
if ~isfile(csvFile)
    error('[main_retention_dual_threshold] 未找到数据文件：%s\n请先运行 01_数据预处理/main_preprocess.m。', csvFile);
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
    error('[main_retention_dual_threshold] 未找到优化模型 β 文件：%s', betaFile);
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
%（按 β 表变量名称匹配，而非依赖表格行号）
expectedVars = {'是否为老年人'; '是否有伴侣'; '是否有家属'; ...
                '是否开通在线安全'; '是否开通在线备份'; '是否开通设备保护'; ...
                '是否开通技术支持'; '是否开通电视流媒体'; '是否开通电影流媒体'; ...
                '合同类型'; '是否使用电子账单'; '支付方式'; '在网时长（月）'};
if numVars ~= 13
    error('[main_retention_dual_threshold] 优化模型变量数量应为 13，实际为 %d，请检查 %s。', numVars, betaFile);
end
if ~all(strcmp(varCol(2:end), expectedVars))
    error('[main_retention_dual_threshold] 优化模型变量顺序与预期不一致，请检查 %s。', betaFile);
end

%% ---------- 3) 提取 13 个变量并按 β 顺序构建设计矩阵（原始尺度） ----------
% 完全忽略：互联网服务类型、月费用、总费用（VIF>10 已剔除）
X_raw = table2array(data(:, expectedVars));   % 7032×13，顺序与 β 表一致
if any(any(isnan(X_raw), 2))                  % 防御性检查
    warning('[main_retention_dual_threshold] 输入变量中存在缺失值，请检查数据。');
end
X = [ones(N, 1), X_raw];                      % 7032×14（含截距列）

%% ---------- 4) 计算客户流失概率 p = 1/(1+exp(-z)) ----------
z = X * [beta0; betaFeat(:)];
p = zeros(N, 1);
pos = z >= 0;                                 % 数值稳定的 sigmoid
p(pos)  = 1 ./ (1 + exp(-z(pos)));
p(~pos) = exp(z(~pos)) ./ (1 + exp(z(~pos)));

%% ---------- 5) 双阈值规则：经济临界概率 π 与高风险上限 pmax ----------
C = 150;      % 挽留成本
q = 0.35;     % 挽留成功率
L = 2000;     % 客户流失损失
piStar = C / (q * L);                        % 0.214285714285714（经济临界概率）
pMax   = 0.7;                                % 高风险上限（p>0.7 不挽留）

lowRisk  = p <  piStar;                      % 低风险：不挽留
retain   = (p >= piStar) & (p <= pMax);      % 建议挽留：π ≤ p ≤ 0.7
highRisk = p >  pMax;                        % 高风险：不挽留

% 校验1：三类互斥且完整（区间不重叠，且覆盖全部客户）
assert(sum(lowRisk) + sum(retain) + sum(highRisk) == N, ...
    '[main_retention_dual_threshold] 三类客户人数之和不等于总客户数，区间划分异常。');
nLow   = sum(lowRisk);
nRet   = sum(retain);
nHigh  = sum(highRisk);

% 决策标签（三类互斥）
decisionStr = repmat("不挽留", N, 1);
decisionStr(retain) = "建议挽留";
decisionStr(highRisk) = "高风险不挽留";

fprintf('经济临界概率 π = %.7f\n', piStar);
fprintf('高风险上限 = %.7f\n', pMax);

%% ---------- 6) 输出 1：retention_probability_dual_threshold.xlsx（全部 7032 客户） ----------
probTbl = table(custID, Y, p, repmat(piStar, N, 1), repmat(pMax, N, 1), decisionStr, ...
    'VariableNames', {'客户编号', '真实流失标签', '预测流失概率p', ...
                      '经济临界概率π', '高风险上限', '最终决策'});
probFile = fullfile(outDir, 'retention_probability_dual_threshold.xlsx');
writetable(probTbl, probFile, 'Sheet', '双阈值概率', 'WriteMode', 'overwritesheet');
fprintf('已保存：retention_probability_dual_threshold.xlsx（全部 %d 客户）。\n', N);

%% ---------- 7) 输出 2：retention_result_dual_threshold.xlsx（建议挽留名单） ----------
retainIdx = find(retain);
resTbl = table(custID(retainIdx), p(retainIdx), Y(retainIdx), ...
    'VariableNames', {'客户编号', '预测流失概率', '真实流失标签'});
resFile = fullfile(outDir, 'retention_result_dual_threshold.xlsx');
writetable(resTbl, resFile, 'Sheet', '挽留名单', 'WriteMode', 'overwritesheet');
fprintf('已保存：retention_result_dual_threshold.xlsx（建议挽留 %d 人）。\n', nRet);

%% ---------- 8) 输出 3：retention_statistics_dual_threshold.xlsx（3 个 Sheet） ----------
% 校验2：真实流失人数必须仍为 1869
assert(sum(Y == 1) == 1869, ...
    '[main_retention_dual_threshold] 真实流失人数应为 1869，实际为 %d。', sum(Y == 1));
nChurn  = sum(Y == 1);                              % 真实流失人数
nRetChurn = sum(Y == 1 & retain);                   % 建议挽留客户中的真实流失人数
coverage  = nRetChurn / nChurn;                     % 挽留覆盖率

% ---- Sheet 1：总体策略统计 ----
statNames = {'总客户数'; '建议挽留人数'; '建议挽留比例'; ...
             '低风险不挽留人数'; '高风险不挽留人数'; ...
             '真实流失人数'; '建议挽留客户中的真实流失人数'; '挽留覆盖率'};
statVals  = [N; nRet; nRet / N; nLow; nHigh; nChurn; nRetChurn; coverage];
statsTbl1 = table(statNames, statVals, 'VariableNames', {'指标', '数值'});
statsFile = fullfile(outDir, 'retention_statistics_dual_threshold.xlsx');
writetable(statsTbl1, statsFile, 'Sheet', '总体策略统计', 'WriteMode', 'overwritesheet');

% ---- Sheet 2：三类客户画像 ----
catNames = {'低风险(p<π)'; '建议挽留(π≤p≤0.7)'; '高风险(p>0.7)'};
catCount = [nLow; nRet; nHigh];
catRatio = catCount / N;
catChurn = [sum(Y == 1 & lowRisk); nRetChurn; sum(Y == 1 & highRisk)];
catRate  = catChurn ./ catCount;
statsTbl2 = table(catNames, catCount, catRatio, catChurn, catRate, ...
    'VariableNames', {'类别', '人数', '占比', '真实流失人数', '真实流失率'});
writetable(statsTbl2, statsFile, 'Sheet', '三类客户画像', 'WriteMode', 'overwritesheet');

% ---- Sheet 3：新旧策略比较（原 p≥π  vs  新 π≤p≤0.7） ----
oldRetain = p >= piStar;                            % 原策略建议挽留
nOldRet   = sum(oldRetain);
newRetain = retain;                                 % 新策略建议挽留
nNewRet   = nRet;
nCutHigh  = sum(oldRetain & highRisk);              % 被新规则剔除的高风险客户（p>0.7 且原策略会挽留）
% 注：由于 pMax=0.7 > π，p>0.7 的客户全部落在原策略 p≥π 集合内，故 nCutHigh = nHigh。
cmpNames = {'原策略建议挽留人数(p≥π)'; '新策略建议挽留人数(π≤p≤0.7)'; ...
            '被新规则剔除的高风险客户人数(p>0.7)'; ...
            '原策略挽留比例'; '新策略挽留比例'};
cmpVals  = [nOldRet; nNewRet; nCutHigh; nOldRet / N; nNewRet / N];
statsTbl3 = table(cmpNames, cmpVals, 'VariableNames', {'指标', '数值'});
writetable(statsTbl3, statsFile, 'Sheet', '新旧策略比较', 'WriteMode', 'overwritesheet');
fprintf('已保存：retention_statistics_dual_threshold.xlsx（3 个 Sheet）。\n');

%% ---------- 9) 输出 4：retention_probability_dual_threshold.png（双阈值分布图） ----------
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

fig = figure('Color', 'w', 'Position', [100 100 1000 640]);
histogram(p, 50, 'FaceColor', [0.35 0.55 0.85], 'EdgeColor', 'none');
hold on;
yl = ylim;
% 两条竖直虚线：经济临界概率 π 与高风险上限 0.7
plot([piStar piStar], yl, 'r--', 'LineWidth', 2);
plot([pMax   pMax],   yl, 'g--', 'LineWidth', 2);
% 三区域标注（位于各区间的水平中点）
text(piStar / 2,            yl(2) * 0.92, '不挽留', ...
    'Color', 'k', 'FontSize', 11, 'HorizontalAlignment', 'center');
text((piStar + pMax) / 2,   yl(2) * 0.92, '建议挽留', ...
    'Color', [0.00 0.45 0.80], 'FontSize', 11, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
text((pMax + 1) / 2,        yl(2) * 0.92, '高风险不挽留', ...
    'Color', 'k', 'FontSize', 11, 'HorizontalAlignment', 'center');
% 阈值标注
text(piStar, yl(2) * 0.97, sprintf('π=%.7f', piStar), ...
    'Color', 'r', 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
text(pMax,   yl(2) * 0.97, sprintf('0.7'), ...
    'Color', [0.00 0.55 0.00], 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
xlabel('预测流失概率 p');
ylabel('客户数量');
title('客户流失概率分布与双阈值挽留决策（π=0.2142857，高风险上限 p=0.7）');
legend({'流失概率分布', '经济临界概率 π', '高风险上限 0.7'}, 'Location', 'north');
grid on; box on;
saveas(fig, fullfile(outDir, 'retention_probability_dual_threshold.png'));
close(fig);
fprintf('已保存：retention_probability_dual_threshold.png。\n');

%% ---------- 10) 命令窗口打印关键结果 ----------
fprintf('\n经济临界概率 π = %.7f\n', piStar);
fprintf('高风险上限 = %.7f\n', pMax);
fprintf('\n总客户数：%d\n', N);
fprintf('\n低风险客户（p < π）：%d 人\n', nLow);
fprintf('建议挽留客户（π ≤ p ≤ 0.7）：%d 人\n', nRet);
fprintf('高风险客户（p > 0.7）：%d 人\n', nHigh);
fprintf('\n建议挽留比例：%.2f%%\n', nRet / N * 100);
fprintf('\n真实流失客户：%d 人\n', nChurn);
fprintf('建议挽留客户中的真实流失人数：%d 人\n', nRetChurn);
fprintf('挽留覆盖率：%.2f%%\n', coverage * 100);

% 校验3：新旧策略比较复核打印
fprintf('\n[新旧策略比较] 原策略(p≥π)建议挽留 %d 人；新策略(π≤p≤0.7)建议挽留 %d 人；剔除高风险 %d 人。\n', ...
    nOldRet, nNewRet, nCutHigh);

fprintf('\n============================================\n');
fprintf('双阈值客户挽留策略计算完成。\n');
fprintf('============================================\n');
