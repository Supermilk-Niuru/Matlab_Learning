%% main_cluster.m —— 电信客户流失分析：基于显著影响因素的客户群体聚类分析
%  功能：读取 01_数据预处理/B_processed.csv（7043×20），以假设检验
%        （分类变量卡方独立性检验 + 连续变量单因素方差分析）筛选出的
%        显著影响变量（p<0.05）为输入，对客户进行 K-means 无监督聚类。
%
%  两套方案（敏感性分析，"是否开通多条线路"卡方显著但 F 检验不显著）：
%    方案A_包含多条线路：显著分类变量 13 个 + 是否开通多条线路 + 连续变量 3 个 = 17 个
%    方案B_不包含多条线路：显著分类变量 13 个 + 连续变量 3 个 = 16 个
%
%  完整流程（每套方案）：
%    ① 数据预处理：提取输入变量 → 删除含缺失值行 → Z-score 标准化（数据副本）；
%    ② 最佳 K 选择：K = 2..8，计算 SSE 与平均轮廓系数，绘制肘部图与
%       轮廓系数图，综合两指标确定最佳 K；
%    ③ K-means 聚类：手动实现（kmeans++ 初始化 + Lloyd 迭代），欧氏距离，
%       目标函数为最小化类内平方和 SSE = Σ||x_i - μ_k||²；
%    ④ 结果输出：cluster_result / cluster_center（真实均值）/ cluster_statistics；
%    ⑤ PCA 降维（SVD）绘制二维散点图；
%    ⑥ 汇总生成 聚类方案比较.xlsx。
%
%  说明：
%    - 本步骤属探索性统计分析；
%    - 不训练分类模型、不预测客户流失、不使用"是否流失"作为聚类输入、
%      不修改原始数据、不进行特征选择算法；
%    - "是否流失"仅在聚类结果统计（流失人数/流失率）中使用；
%    - 数据无客户 ID 列，"客户编码"取 B_processed.csv 的原始行号。
%
%  环境：MATLAB R2025a（仅基础函数，不依赖统计/机器学习工具箱）
%  依赖函数：preprocess_cluster_data / kmeans_cluster / select_K /
%           PCA_visualization / save_cluster_result
%  运行方式：MATLAB 命令行直接执行 main_cluster

clc; clear; close all;

%% ---------- 0) 定位工作目录（相对路径，不依赖绝对路径） ----------
scriptDir = fileparts(mfilename('fullpath'));
if ~isempty(scriptDir)
    cd(scriptDir);
end

%% ---------- 1) 读取数据 ----------
csvFile = fullfile(pwd, '..', '01_数据预处理', 'B_processed.csv');
if ~isfile(csvFile)
    error('[main_cluster] 未找到数据文件：%s\n请先运行 01_数据预处理/main_preprocess.m。', csvFile);
end
data = readtable(csvFile, 'VariableNamingRule', 'preserve');
fprintf('======== 客户聚类分析（K-means） ========\n');
fprintf('读取数据：%d 行 × %d 列\n', size(data, 1), size(data, 2));

churnCol = data.('是否流失');   % 目标变量（仅用于结果统计，不作为聚类输入）

%% ---------- 2) 输入变量清单（显著性检验筛选，p < 0.05） ----------
% 显著分类变量（13 个）
catVars = {'是否为老年人'; '是否有伴侣'; '是否有家属'; ...
           '互联网服务类型'; '是否开通在线安全'; '是否开通在线备份'; ...
           '是否开通设备保护'; '是否开通技术支持'; ...
           '是否开通电视流媒体'; '是否开通电影流媒体'; ...
           '合同类型'; '是否使用电子账单'; '支付方式'};
% 特殊情况变量：卡方检验显著、F 检验不显著（方案 A 额外加入，作敏感性分析）
multiLine = {'是否开通多条线路'};
% 连续变量（3 个）
contVars = {'在网时长（月）'; '月费用'; '总费用'};

varA = [catVars; multiLine; contVars];   % 方案A：13 + 1 + 3 = 17 个
varB = [catVars;             contVars];   % 方案B：13 + 3 = 16 个

schemeList = {
    '方案A_包含多条线路', 'A', varA, '包含是否开通多条线路的客户聚类结果';
    '方案B_不包含多条线路', 'B', varB, '不包含是否开通多条线路的客户聚类结果'
    };
nScheme = size(schemeList, 1);

%% ---------- 3) 参数与随机种子 ----------
rng(2026);          % 固定随机种子，保证结果可复现
nRep   = 20;        % K-means 多起点重复次数
Krange = 2:8;       % 待选聚类数

% 方案比较表（每行：方案名称/变量数量/最佳K/平均轮廓系数/SSE/各类别客户数量/各类别流失率）
comp = cell(nScheme, 7);

%% ---------- 4) 逐方案执行完整聚类流程 ----------
for s = 1:nScheme
    scName  = schemeList{s, 1};   % 方案文件夹名
    scShort = schemeList{s, 2};   % 'A' / 'B'
    vars    = schemeList{s, 3};
    scTitle = schemeList{s, 4};

    fprintf('\n=====================================================\n');
    fprintf('  %s（输入变量 %d 个）\n', scName, numel(vars));
    fprintf('=====================================================\n');

    outDir = fullfile(pwd, scName);
    if ~isfolder(outDir)
        mkdir(outDir);
    end

    % ---- 5) 数据预处理：提取 + 删除含缺失行 + Z-score 标准化 ----
    [X_std, X_raw, keepIdx] = preprocess_cluster_data(data, vars);
    N = size(X_std, 1);
    churnSub = churnCol(keepIdx);              % 与聚类样本对应的流失标签

    % ---- 6) 最佳 K 值选择（SSE 肘部 + 平均轮廓系数，绘制两张图） ----
    [K_best, sseVec, silVec, idxBest, centersStd] = ...
        select_K(X_std, Krange, scShort, outDir, nRep);

    % ---- 7) 保存聚类结果 / 聚类中心 / 聚类统计 ----
    R = struct('outDir', outDir, 'scShort', scShort, ...
               'vars', {vars}, 'X_raw', X_raw, ...
               'keepIdx', keepIdx, 'churn', churnSub, ...
               'idx', idxBest, 'K', K_best);
    save_cluster_result(R);

    % ---- 8) PCA 降维可视化（二维散点图） ----
    PCA_visualization(X_std, idxBest, scTitle, ...
        fullfile(outDir, sprintf('PCA散点图_%s.png', scShort)));

    % ---- 9) 汇总到方案比较表 ----
    iBest = find(Krange == K_best, 1);
    cnt      = accumarray(idxBest, 1);
    churnCnt = accumarray(idxBest, churnSub);
    rate     = churnCnt ./ cnt * 100;
    cntStr   = strjoin(arrayfun(@(k) sprintf('C%d:%d', k, cnt(k)), 1:K_best, ...
                       'UniformOutput', false), '; ');
    rateStr  = strjoin(arrayfun(@(k) sprintf('C%d:%.1f%%', k, rate(k)), 1:K_best, ...
                       'UniformOutput', false), '; ');
    comp(s, :) = {scName, numel(vars), K_best, silVec(iBest), sseVec(iBest), cntStr, rateStr};
end

%% ---------- 10) 生成 聚类方案比较.xlsx ----------
compTbl = cell2table(comp, 'VariableNames', ...
    {'方案名称', '变量数量', '最佳K值', '平均轮廓系数', 'SSE', ...
     '各类别客户数量', '各类别流失率'});
compFile = fullfile(pwd, '聚类方案比较.xlsx');
if isfile(compFile); delete(compFile); end
writetable(compTbl, compFile, 'Sheet', '方案比较', 'WriteMode', 'overwritesheet');
fprintf('\n======== 方案比较 ========\n');
disp(compTbl);
fprintf('已保存方案比较表：%s\n', compFile);

%% ---------- 11) 完成 ----------
fprintf('\n=====================================================\n');
fprintf('  客户聚类分析完成。\n');
fprintf('  方案A（含多条线路）最佳 K = %d，方案B（不含多条线路）最佳 K = %d。\n', ...
        comp{1, 3}, comp{2, 3});
fprintf('  详细结果目录：%s\n', pwd);
fprintf('=====================================================\n');
