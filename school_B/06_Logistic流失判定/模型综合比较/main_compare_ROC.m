%% main_compare_ROC.m —— 问题2：优化Logistic模型 vs 随机森林模型 ROC 综合比较
%  功能：在同一测试集上综合比较 优化Logistic模型（13变量） 与
%        随机森林模型 的判别性能，以 ROC 曲线与 AUC 为核心指标。
%
%  处理流程：
%    1) 读取两个模型的测试集预测概率：
%         优化Logistic：../优化Logistic模型/prediction_result.xlsx（若缺失，
%            则根据已保存的 Optimized_Logistic_beta.xlsx（β标准化尺度）在
%            完全相同的数据划分（rng(2026)，70%/30%，同一测试集）下做
%            纯推理计算测试集预测概率，并保存该新文件 —— 不重新训练模型，
%            也不修改/覆盖之前任何模型文件）；
%         随机森林：../../07_随机森林流失判定/RF_prediction_result.xlsx。
%    2) 校验两模型测试集是否一致（样本数 / 客户编号 / 真实流失标签），
%       若客户编号顺序不一致则按客户编号匹配对齐。
%    3) 手动计算 ROC 曲线与 AUC（不依赖任何工具箱）：
%       按预测概率降序排序，逐样本累积真阳性率 TPR=TP/(TP+FN)、
%       假阳性率 FPR=FP/(FP+TN)，梯形法则 AUC=Σ[(FPR_{i+1}-FPR_i)×
%       (TPR_i+TPR_{i+1})/2]。
%    4) 绘制 优化Logistic_vs_RF_ROC.png（两条曲线 + y=x 随机基准线）。
%    5) 保存 模型ROC比较.xlsx：Sheet1 模型AUC比较，Sheet2 ROC数据。
%
%  【重要要求】1. 不允许修改之前任何模型文件（原始Logistic / 优化Logistic /
%                  随机森林 的既有 xlsx、png、txt 均保持不变）。
%               2. 不重新训练模型（仅读取已保存的预测概率 / β 系数）。
%               3. 直接读取已经保存好的预测概率结果。
%               4. 两个模型必须使用完全相同的测试集。
%
%  环境：MATLAB R2025a（仅基础函数，不依赖统计/机器学习工具箱）
%  运行方式：MATLAB 命令行直接执行 main_compare_ROC

clc; clear; close all;

%% ---------- 0) 定位工作目录（所有路径由 pwd 动态获取） ----------
scriptDir = fileparts(mfilename('fullpath'));
if ~isempty(scriptDir)
    cd(scriptDir);                    % 切换到 06_Logistic流失判定/模型综合比较/
end
outDir = pwd;
optDir = fullfile(pwd, '..', '优化Logistic模型');       % 上一级：优化Logistic
rfDir  = fullfile(pwd, '..', '..', '07_随机森林流失判定'); % 上两级：随机森林
csvFile = fullfile(pwd, '..', '..', '01_数据预处理', 'B_processed.csv');

fprintf('======== 优化Logistic模型 vs 随机森林模型 ROC 综合比较 ========\n');

%% ---------- 1) 优化Logistic：读取预测概率（缺失时用已保存β推理重建） ----------
optPredFile = fullfile(optDir, 'prediction_result.xlsx');
if ~isfile(optPredFile)
    fprintf('优化Logistic模型缺少 prediction_result.xlsx，\n');
    fprintf('根据已保存 β（Optimized_Logistic_beta.xlsx）在相同数据划分下推理重建（不重训、不改动既有文件）...\n');
    [keepIdx, Yte, pTest] = infer_optimized_predictions(optDir, csvFile);
    write_prediction_file(keepIdx, Yte, pTest, optPredFile);
    fprintf('已生成：%s\n', optPredFile);
else
    fprintf('已找到：%s\n', optPredFile);
end

%% ---------- 2) 读取两个模型的测试集预测概率结果 ----------
[logID, logY, logP] = read_prediction_file(optPredFile);
[rfID,  rfY,  rfP ] = read_prediction_file(fullfile(rfDir, 'RF_prediction_result.xlsx'));
fprintf('读取完成：优化Logistic %d 个样本，随机森林 %d 个样本。\n', numel(logID), numel(rfID));

%% ---------- 3) 校验测试集一致性，并按客户编号对齐 ----------
[logY, logP, rfY, rfP] = align_test_sets(logID, logY, logP, rfID, rfY, rfP);

%% ---------- 4) 手动计算 ROC 曲线与 AUC ----------
[optFPR, optTPR, optAUC] = compute_roc(logY, logP);
[rfFPR,  rfTPR,  rfAUC ] = compute_roc(rfY,  rfP);
fprintf('优化Logistic AUC = %.4f\n', optAUC);
fprintf('随机森林 AUC = %.4f\n', rfAUC);

%% ---------- 5) 绘制 ROC 对比图 ----------
plot_roc_compare(optFPR, optTPR, optAUC, rfFPR, rfTPR, rfAUC, outDir);

%% ---------- 6) 保存 模型ROC比较.xlsx ----------
save_roc_excel(optAUC, rfAUC, optFPR, optTPR, rfFPR, rfTPR, outDir);

%% ---------- 7) 完成 ----------
fprintf('\n====================================\n');
fprintf('  ROC模型比较完成\n');
fprintf('  优化Logistic AUC = %.4f\n', optAUC);
fprintf('  随机森林 AUC = %.4f\n', rfAUC);
fprintf('  生成文件：\n');
fprintf('    优化Logistic_vs_RF_ROC.png\n');
fprintf('    模型ROC比较.xlsx\n');
fprintf('  保存路径：\n');
fprintf('    06_Logistic流失判定/模型综合比较/\n');
fprintf('====================================\n');

%% ================================================================
%%  局部函数
%% ================================================================

function [keepIdxTest, Yte, pTest] = infer_optimized_predictions(optDir, csvFile)
% INFER_OPTIMIZED_PREDICTIONS 用已保存的 β 系数在相同测试集上纯推理预测
%   与 prepare_opt_variables.m 完全一致：13 个变量（12 分类 + 在网时长）、
%   在网时长 Z-score 标准化（参数由全样本计算）、rng(2026) 70/30 划分。
%   仅读取数据与 β，不调用任何模型训练过程。

% 1) 读取数据并删除总费用缺失样本（与 load_opt_data.m 一致）
data = readtable(csvFile, 'VariableNamingRule', 'preserve');
bad = isnan(data.('总费用'));
origRow = find(~bad);                 % 客户编号 = 有效样本原始行号
data(bad, :) = [];

% 2) 13 个解释变量（顺序与 prepare_opt_variables.m 完全一致）
catVars = {'是否为老年人'; '是否有伴侣'; '是否有家属'; ...
           '是否开通在线安全'; '是否开通在线备份'; '是否开通设备保护'; ...
           '是否开通技术支持'; '是否开通电视流媒体'; '是否开通电影流媒体'; ...
           '合同类型'; '是否使用电子账单'; '支付方式'};
contVars = {'在网时长（月）'};
vars = [catVars; contVars];           % 13 个输入变量

Y = data.('是否流失');
X_raw = table2array(data(:, vars));
valid = all(~isnan(X_raw), 2);
X_raw = X_raw(valid, :);
Y     = Y(valid);
origRow = origRow(valid);
N = size(X_raw, 1);

% 3) 连续变量 Z-score 标准化（全样本参数，与 prepare_opt_variables.m 一致）
contIdx = numel(vars);
mu    = mean(X_raw(:, contIdx), 1);
sigma = std(X_raw(:, contIdx), 0, 1);
sigma(sigma == 0) = 1;
X_std = X_raw;
X_std(:, contIdx) = (X_raw(:, contIdx) - mu) ./ sigma;

% 4) 数据划分：rng(2026)，70% 训练 / 30% 测试（与之前所有模型一致）
rng(2026);
perm  = randperm(N);
nTr   = round(N * 0.70);
te    = perm(nTr+1 : end);
nTe   = N - nTr;

% 5) 读取已保存的 β（标准化尺度，14×1：截距 β0 + 13 个变量）
betaTbl = readtable(fullfile(optDir, 'Optimized_Logistic_beta.xlsx'), ...
                    'Sheet', 'β系数', 'VariableNamingRule', 'preserve');
betaStd = betaTbl.('β标准化尺度');
if numel(betaStd) ~= numel(vars) + 1
    error('β 系数数量（%d）与变量数（%d）+1 不符。', numel(betaStd), numel(vars));
end

% 6) 测试集预测概率（数值稳定的 sigmoid，与 main_optimized_logistic.m 一致）
Xte  = [ones(nTe, 1), X_std(te, :)];
zTe  = Xte * betaStd;
pTest = zeros(nTe, 1);
pos = zTe >= 0;
pTest(pos)  = 1 ./ (1 + exp(-zTe(pos)));
pTest(~pos) = exp(zTe(~pos)) ./ (1 + exp(zTe(~pos)));

keepIdxTest = origRow(te);
Yte = Y(te);

end

function write_prediction_file(keepIdx, Yte, pTest, file)
% WRITE_PREDICTION_FILE 保存测试集预测结果（客户编号 | 真实流失状态 | 预测概率P | 预测类别）
predClass = double(pTest >= 0.5);
predTbl = table(keepIdx, Yte, pTest, predClass, ...
    'VariableNames', {'客户编号', '真实流失状态', '预测概率P', '预测类别'});
if isfile(file); delete(file); end
writetable(predTbl, file, 'Sheet', '预测结果', 'WriteMode', 'overwritesheet');

end

function [id, y, p] = read_prediction_file(file)
% READ_PREDICTION_FILE 读取测试集预测结果文件
%   输入：file —— 预测结果 xlsx（表头：客户编号 | 真实流失状态 | 预测概率P | 预测类别）
%   输出：id 客户编号 / y 真实流失状态 / p 预测概率P
T = readtable(file, 'Sheet', '预测结果', 'VariableNamingRule', 'preserve');
id = T.('客户编号');
y  = T.('真实流失状态');
p  = T.('预测概率P');

end

function [logY, logP, rfY, rfP] = align_test_sets(logID, logY, logP, rfID, rfY, rfP)
% ALIGN_TEST_SETS 校验两模型测试集一致性并按客户编号对齐
%   若两模型客户编号顺序完全一致，直接使用；
%   否则按客户编号匹配对齐，并校验匹配后的真实标签一致。
%   两模型数据划分均由 rng(2026) 产生，正常情况下客户编号应完全一致。

if numel(logID) ~= numel(rfID)
    error('两模型测试集样本数不一致：优化Logistic %d，随机森林 %d。', numel(logID), numel(rfID));
end

if isequal(logID, rfID)
    fprintf('测试集一致性校验：两模型客户编号顺序完全一致（%d 个样本）。\n', numel(logID));
else
    fprintf('两模型客户编号顺序不一致，按客户编号匹配对齐...\n');
    [common, ia, ib] = intersect(logID, rfID, 'stable');
    if numel(common) ~= numel(logID)
        error('按客户编号匹配后仅 %d 个样本一致，测试集不对齐。', numel(common));
    end
    logY = logY(ia);  logP = logP(ia);
    rfY  = rfY(ib);   rfP  = rfP(ib);
    fprintf('按客户编号匹配完成：%d 个样本。\n', numel(common));
end

if ~isequal(logY, rfY)
    nDiff = sum(logY ~= rfY);
    error('两模型测试集真实流失标签不一致（%d 处不同），无法进行 ROC 比较。', nDiff);
end
fprintf('测试集一致性校验通过：样本数、客户编号、真实流失标签均一致。\n');
fprintf('  正类（流失）%d 个，负类（未流失）%d 个。\n', sum(logY == 1), sum(logY == 0));

end

function [FPR, TPR, AUC] = compute_roc(Y, p)
% COMPUTE_ROC 手动计算 ROC 曲线与 AUC（不依赖任何工具箱）
%   按预测概率降序排序，逐样本累积：
%     TPR = 累积真阳性 / 正类总数（灵敏度）
%     FPR = 累积假阳性 / 负类总数（1-特异度）
%   梯形法则：AUC = Σ[(FPR_{i+1}-FPR_i)×(TPR_i+TPR_{i+1})/2]
%   输出：FPR / TPR 均为列向量（含起点 (0,0)），AUC 为标量。

[~, idx] = sort(p, 'descend');
ys = Y(idx);
nPos = sum(ys == 1);
nNeg = sum(ys == 0);

tp = cumsum(ys);                      % 累积真阳性
fp = cumsum(1 - ys);                  % 累积假阳性
TPR = [0; tp / nPos];                 % 起点 (0,0)，终点 (1,1)
FPR = [0; fp / nNeg];
AUC = trapz(FPR, TPR);                % 梯形法则求曲线下面积

end

function plot_roc_compare(optFPR, optTPR, optAUC, rfFPR, rfTPR, rfAUC, outDir)
% PLOT_ROC_COMPARE 绘制优化Logistic vs 随机森林 的 ROC 对比图
%   白底、两条彩色曲线 + y=x 随机基准线（虚线），图例含各自 AUC。

figure('Color', 'w', 'Position', [120 120 720 560]);
plot(optFPR, optTPR, '-b', 'LineWidth', 1.6); hold on;
plot(rfFPR,  rfTPR,  '-r', 'LineWidth', 1.6);
plot([0 1], [0 1], '--k', 'LineWidth', 1);     % 随机基准线 y=x
hold off;
xlabel('False Positive Rate (FPR)');
ylabel('True Positive Rate (TPR)');
title('优化Logistic模型 vs 随机森林模型 ROC 曲线');
legend(sprintf('Optimized Logistic Regression (AUC = %.4f)', optAUC), ...
       sprintf('Random Forest (AUC = %.4f)', rfAUC), ...
       'Random Guess (y=x)', 'Location', 'southeast');
grid on; box on;

pngFile = fullfile(outDir, '优化Logistic_vs_RF_ROC.png');
saveas(gcf, pngFile);
close(gcf);
fprintf('已保存 ROC 对比图：%s\n', pngFile);

end

function save_roc_excel(optAUC, rfAUC, optFPR, optTPR, rfFPR, rfTPR, outDir)
% SAVE_ROC_EXCEL 保存 模型ROC比较.xlsx
%   Sheet1 模型AUC比较：模型 | AUC
%   Sheet2 ROC数据   ：模型名称 | FPR | TPR（两模型全部 ROC 点）

% ---- Sheet1：模型AUC比较 ----
aucTbl = table({'优化Logistic模型'; '随机森林模型'}, [optAUC; rfAUC], ...
    'VariableNames', {'模型', 'AUC'});

% ---- Sheet2：ROC数据（两模型逐点） ----
n1 = numel(optFPR); n2 = numel(rfFPR);
name = cell(n1 + n2, 1);
name(1:n1)          = repmat({'Optimized Logistic'}, n1, 1);
name(n1+1 : n1+n2)  = repmat({'Random Forest'}, n2, 1);
rocTbl = table(name, [optFPR; rfFPR], [optTPR; rfTPR], ...
    'VariableNames', {'模型名称', 'FPR', 'TPR'});

xlsFile = fullfile(outDir, '模型ROC比较.xlsx');
if isfile(xlsFile); delete(xlsFile); end
writetable(aucTbl, xlsFile, 'Sheet', '模型AUC比较', 'WriteMode', 'overwritesheet');
writetable(rocTbl, xlsFile, 'Sheet', 'ROC数据',   'WriteMode', 'overwritesheet');
fprintf('已保存 模型ROC比较.xlsx：\n  Sheet1 模型AUC比较（%d 行）\n  Sheet2 ROC数据（%d 行）\n', ...
    height(aucTbl), height(rocTbl));

end
