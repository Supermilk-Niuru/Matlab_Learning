function [Xtr, Ytr, Xte, Yte, keepIdxTest, P] = prepare_opt_variables(data, origRow)
% PREPARE_OPT_VARIABLES 优化模型变量准备：提取 13 个变量、标准化、划分数据集
%
%   优化后的解释变量（13 个，删除了 VIF>10 的 3 个严重共线性变量：
%     互联网服务类型、月费用、总费用）：
%     分类变量（12 个，保持数值编码）：
%       是否为老年人、是否有伴侣、是否有家属、是否开通在线安全、
%       是否开通在线备份、是否开通设备保护、是否开通技术支持、
%       是否开通电视流媒体、是否开通电影流媒体、合同类型、
%       是否使用电子账单、支付方式
%     连续变量（1 个，Z-score 标准化）：在网时长（月）
%   Z-score 标准化：x' = (x - mean) / std，参数由全部有效样本（7032 行）计算，
%     仅作用于数据副本，不修改 B_processed.csv。
%
%   数据划分（关键：与原始 Logistic 模型完全一致，保证测试集相同）：
%     rng(2026); perm = randperm(N); nTr = round(N*0.70);
%     训练集 70% / 测试集 30%，测试样本客户编号与原始模型完全相同。
%     注意：本函数在 randperm 之前不调用任何消耗随机数的函数。
%
%   输入：
%     data    —— 有效样本数据表
%     origRow —— 有效样本的原始行号（客户编号）
%   输出：
%     Xtr / Ytr —— 训练设计矩阵（含截距列，标准化尺度）/ 训练标签
%     Xte / Yte —— 测试设计矩阵 / 测试标签
%     keepIdxTest —— 测试样本的客户编号（原始行号）
%     P         —— 结构体：vars / catVars / contVars / contIdx / mu / sigma

%% 1) 优化后的输入变量清单（13 个）
catVars = {'是否为老年人'; '是否有伴侣'; '是否有家属'; ...
           '是否开通在线安全'; '是否开通在线备份'; '是否开通设备保护'; ...
           '是否开通技术支持'; '是否开通电视流媒体'; '是否开通电影流媒体'; ...
           '合同类型'; '是否使用电子账单'; '支付方式'};
contVars = {'在网时长（月）'};
vars = [catVars; contVars];               % 13 个输入变量
D    = numel(vars);

% 目标变量：是否流失（Y=1 流失，Y=0 未流失）
Y = data.('是否流失');

%% 2) 提取输入变量并删除缺失（防御性检查）
X_raw = table2array(data(:, vars));
valid = all(~isnan(X_raw), 2);
if sum(~valid) > 0
    fprintf('  [prepare_opt_variables] 额外删除含缺失值行 %d 行。\n', sum(~valid));
end
X_raw = X_raw(valid, :);
Y     = Y(valid);
origRow = origRow(valid);
N = size(X_raw, 1);

%% 3) 连续变量 Z-score 标准化（仅作用于副本，参数由全部样本计算）
contIdx = D;                              % 在网时长（月）为第 13 个变量
mu    = mean(X_raw(:, contIdx), 1);
sigma = std(X_raw(:, contIdx), 0, 1);
sigma(sigma == 0) = 1;                    % 防御：常数变量不除零
X_std = X_raw;
X_std(:, contIdx) = (X_raw(:, contIdx) - mu) ./ sigma;

%% 4) 数据划分：训练集 70% / 测试集 30%（与原始 Logistic 完全一致的随机序列）
rng(2026);
perm  = randperm(N);
nTr   = round(N * 0.70);
nTe   = N - nTr;
tr    = perm(1:nTr);
te    = perm(nTr+1 : end);
fprintf('数据划分（随机种子 2026）：训练集 %d 个样本，测试集 %d 个样本（与原始模型相同）。\n', nTr, nTe);

Xtr = [ones(nTr, 1), X_std(tr, :)];       % 训练设计矩阵（含截距列）
Ytr = Y(tr);
Xte = [ones(nTe, 1), X_std(te, :)];       % 测试设计矩阵
Yte = Y(te);
keepIdxTest = origRow(te);                % 测试样本的客户编号

%% 5) 返回标准化参数（供还原原始尺度）
P = struct('vars', {vars}, 'catVars', {catVars}, 'contVars', {contVars}, ...
           'contIdx', contIdx, 'mu', mu, 'sigma', sigma);

end
