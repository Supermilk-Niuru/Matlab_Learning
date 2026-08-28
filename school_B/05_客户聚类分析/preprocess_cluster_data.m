function [X_std, X_raw, keepIdx] = preprocess_cluster_data(data, varList)
% PREPROCESS_CLUSTER_DATA 聚类数据预处理
%   1) 从数据表提取输入变量（分类变量按数值编码、连续变量按原始值，
%      不修改原始数据 B_processed.csv）；
%   2) 删除包含缺失值（NaN）的行（仅 总费用 存在 11 个 NaN），保留行的
%      原始行号作为"客户编码"；
%   3) 对输入变量做 Z-score 标准化：z = (x - mean(x)) / std(x)。
%
%   说明：标准化只作用于聚类数据副本 X_std，原始数据保持不变。
%         同时返回未标准化的 X_raw（真实取值），供聚类中心（真实均值）
%         分析使用。
%
%   输入：
%     data    —— 读取后的数据表（readtable, VariableNamingRule='preserve'）
%     varList —— 聚类输入变量名称（元胞数组，长度 D）
%   输出：
%     X_std   —— N×D 标准化矩阵（Z-score，用于聚类）
%     X_raw   —— N×D 未标准化矩阵（真实取值）
%     keepIdx —— 保留行的原始行号（N×1，作为"客户编码"）

%% 1) 提取输入变量（全部为数值列）
varList = varList(:);
X_raw = table2array(data(:, varList));      % 原始取值矩阵（可含 NaN）

%% 2) 删除包含缺失值的行
valid   = all(~isnan(X_raw), 2);
keepIdx = find(valid);                       % 保留行的原始行号 = 客户编码
X_raw   = X_raw(valid, :);
N       = size(X_raw, 1);

%% 3) Z-score 标准化（仅数据副本）
mu    = mean(X_raw, 1);
sigma = std(X_raw, 0, 1);
sigma(sigma == 0) = 1;                       % 防御：常数变量不除零
X_std = (X_raw - mu) ./ sigma;

fprintf('  预处理：%d 个输入变量，有效样本 %d 行（删除含缺失值行 %d 行）。\n', ...
        numel(varList), N, height(data) - N);

end
