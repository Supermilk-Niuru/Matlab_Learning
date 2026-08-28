function save_cluster_result(R)
% SAVE_CLUSTER_RESULT 保存单个聚类方案的 Excel 结果文件
%   在方案文件夹下生成：
%     cluster_result_<A/B>.xlsx       客户编码 | 聚类类别 | 是否流失
%     cluster_center_<A/B>.xlsx       变量 | Cluster1 | Cluster2 | ...（标准化前真实均值）
%     cluster_statistics_<A/B>.xlsx   聚类类别 | 客户数量 | 占比 | 流失人数 | 流失率
%
%   说明："是否流失"仅用于结果统计（流失人数 / 流失率），不作为聚类输入。
%
%   输入：
%     R —— 结构体，字段：
%       outDir  方案输出文件夹
%       scShort 'A' / 'B'（文件名后缀）
%       vars    输入变量名（元胞数组，D×1）
%       X_raw   未标准化数据矩阵（真实取值，N×D）
%       keepIdx 客户编码（原始行号，N×1）
%       churn   是否流失（N×1，0=未流失 1=流失）
%       idx     聚类标签（N×1）
%       K       聚类数

%% 1) 聚类结果表：客户编码 | 聚类类别 | 是否流失
resultTbl = table(R.keepIdx, R.idx, R.churn, ...
    'VariableNames', {'客户编码', '聚类类别', '是否流失'});
resFile = fullfile(R.outDir, sprintf('cluster_result_%s.xlsx', R.scShort));
if isfile(resFile); delete(resFile); end
writetable(resultTbl, resFile, 'Sheet', '聚类结果', 'WriteMode', 'overwritesheet');

%% 2) 聚类中心表：变量 | Cluster1 | ... | ClusterK（标准化前真实均值）
D = numel(R.vars);
centerReal = zeros(D, R.K);
for k = 1:R.K
    m = (R.idx == k);
    centerReal(:, k) = mean(R.X_raw(m, :), 1)';
end
cNames = arrayfun(@(k) sprintf('Cluster%d', k), 1:R.K, 'UniformOutput', false);
% 变量名列 + 数值聚类中心列（分开建表再横向拼接，避免 table 对元胞列的拆分）
centerTbl = [table(R.vars(:), 'VariableNames', {'变量'}), ...
             array2table(centerReal, 'VariableNames', cNames)];
cenFile = fullfile(R.outDir, sprintf('cluster_center_%s.xlsx', R.scShort));
if isfile(cenFile); delete(cenFile); end
writetable(centerTbl, cenFile, 'Sheet', '聚类中心', 'WriteMode', 'overwritesheet');

%% 3) 聚类统计表：聚类类别 | 客户数量 | 占比(%) | 流失人数 | 流失率(%)
N = numel(R.idx);
cnt      = accumarray(R.idx, 1);
churnCnt = accumarray(R.idx, R.churn);
rate     = churnCnt ./ cnt * 100;

% 含"合计"行（聚类类别列为文本，便于混排）
catCell = [num2cell((1:R.K)'); {'合计'}];
statTbl = table(catCell, ...
                [cnt; sum(cnt)], ...
                [cnt / N * 100; 100], ...
                [churnCnt; sum(churnCnt)], ...
                [rate; sum(churnCnt) / N * 100], ...
    'VariableNames', {'聚类类别', '客户数量', '占比(%)', '流失人数', '流失率(%)'});
statFile = fullfile(R.outDir, sprintf('cluster_statistics_%s.xlsx', R.scShort));
if isfile(statFile); delete(statFile); end
writetable(statTbl, statFile, 'Sheet', '聚类统计', 'WriteMode', 'overwritesheet');

fprintf('  已保存：%s\n            %s\n            %s\n', resFile, cenFile, statFile);

end
