function [Xtr, Ytr, Xte, Yte, keepIdxTest, vars, N, nTr, nTe] = load_RF_data()
% LOAD_RF_DATA 读取数据、删除缺失、提取随机森林输入变量并划分数据集
%
%   数据来源：01_数据预处理/B_processed.csv
%   目标变量：是否流失（Y=1 流失，Y=0 未流失）
%   输入变量（16 个，与问题2 Logistic 模型完全一致，取卡方检验显著变量 ∩
%     F 检验显著变量的交集，均不做标准化——决策树按阈值分裂，对量纲不敏感）：
%     分类变量（13 个）：是否为老年人、是否有伴侣、是否有家属、
%       互联网服务类型、是否开通在线安全、是否开通在线备份、是否开通设备保护、
%       是否开通技术支持、是否开通电视流媒体、是否开通电影流媒体、合同类型、
%       是否使用电子账单、支付方式
%     连续变量（3 个）：在网时长（月）、月费用、总费用
%   删除：总费用为空（NaN）的样本（11 行，与 Logistic 相同）。
%
%   数据划分（关键：与问题2 Logistic 模型的 prepare_variables 完全一致，
%   保证两个模型在"同一数据集 + 同一训练测试划分"下对比）：
%     rng(2026);
%     perm  = randperm(N);
%     nTr   = round(N*0.70);
%     测试集 = perm(nTr+1:end)，测试样本客户编号与 Logistic 完全相同。
%     注意：本函数在 randperm 之前不调用任何消耗随机数的函数，
%     以确保与 prepare_variables 得到完全相同的划分。
%
%   输出：
%     Xtr / Ytr      —— 训练集输入（Ntr×16）/ 训练集标签（Ntr×1）
%     Xte / Yte      —— 测试集输入 / 测试集标签
%     keepIdxTest    —— 测试样本的客户编号（原始行号）
%     vars           —— 16 个输入变量名称（16×1 元胞）
%     N / nTr / nTe  —— 有效样本总数 / 训练集样本数 / 测试集样本数

%% 1) 读取数据（相对路径：../01_数据预处理/B_processed.csv）
scriptDir = fileparts(mfilename('fullpath'));
csvFile = fullfile(scriptDir, '..', '01_数据预处理', 'B_processed.csv');
if ~isfile(csvFile)
    error('[load_RF_data] 未找到数据文件：%s', csvFile);
end
data = readtable(csvFile, 'VariableNamingRule', 'preserve');
fprintf('已读取数据：%d 行。\n', height(data));

%% 2) 删除总费用缺失样本（在网时长为 0 的新客户，无历史费用记录）
bad    = isnan(data.('总费用'));
origRow = find(~bad);                 % 有效样本的原始行号 = 客户编号
data   = data(~bad, :);
fprintf('删除总费用缺失样本 %d 行，有效样本 %d 行。\n', sum(bad), height(data));

%% 3) 提取 16 个输入变量
catVars = {'是否为老年人'; '是否有伴侣'; '是否有家属'; '互联网服务类型'; ...
           '是否开通在线安全'; '是否开通在线备份'; '是否开通设备保护'; ...
           '是否开通技术支持'; '是否开通电视流媒体'; '是否开通电影流媒体'; ...
           '合同类型'; '是否使用电子账单'; '支付方式'};
contVars = {'在网时长（月）'; '月费用'; '总费用'};
vars = [catVars; contVars];           % 16 个输入变量

Y = data.('是否流失');
X_raw = table2array(data(:, vars));

% 防御性缺失检查（与 prepare_variables 一致，保证行号对齐）
valid = all(~isnan(X_raw), 2);
if sum(~valid) > 0
    fprintf('  [load_RF_data] 额外删除含缺失值行 %d 行。\n', sum(~valid));
end
X_raw = X_raw(valid, :);
Y     = Y(valid);
origRow = origRow(valid);
N = size(X_raw, 1);

%% 4) 数据划分：训练集 70% / 测试集 30%（随机种子 2026，与 Logistic 完全一致）
rng(2026);                            % 固定随机种子
perm  = randperm(N);                  % 注意：此前不能有任何消耗随机数的调用
nTr   = round(N * 0.70);
nTe   = N - nTr;
tr    = perm(1:nTr);
te    = perm(nTr+1 : end);

Xtr = X_raw(tr, :);   Ytr = Y(tr);
Xte = X_raw(te, :);   Yte = Y(te);
keepIdxTest = origRow(te);            % 测试样本客户编号

fprintf('数据划分（随机种子 2026）：训练集 %d 个样本，测试集 %d 个样本。\n', nTr, nTe);
fprintf('（划分方式与问题2 Logistic 模型完全一致，测试集相同。）\n');

end
