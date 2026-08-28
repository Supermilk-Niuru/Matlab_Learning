function [K_best, sseVec, silVec, idxBest, centersBest] = select_K(X, Krange, prefix, outDir, nRep)
% SELECT_K 最佳聚类数 K 的选择（测试 K = 2,3,...,8）
%   1) 对每个 K 执行 K-means（多起点取类内平方和最小），记录 SSE；
%   2) 手动计算平均轮廓系数（Silhouette）；
%   3) 绘制 SSE 肘部图（SSE_K.png）与轮廓系数变化图（Silhouette_K.png）；
%   4) 综合两种指标确定最佳 K。
%
%   最佳 K 综合判定规则：
%     肘部法：将 SSE 曲线归一化后，找曲线上离首尾连线（弦）最远的点；
%     轮廓系数法：取平均轮廓系数最大的 K；
%     若两法一致 → 采用该 K；
%     若不一致 → 轮廓系数存在明显峰值（峰比次峰高 0.02 以上）时优先
%                 轮廓系数，否则采用肘部法。
%
%   输入：
%     X      —— N×D 标准化数据矩阵
%     Krange —— 待选聚类数向量（默认 2:8）
%     prefix —— 输出文件名前缀（'A' / 'B'）
%     outDir —— 输出文件夹（自动创建）
%     nRep   —— K-means 多起点重复次数
%   输出：
%     K_best      —— 综合确定的最佳 K
%     sseVec      —— 各 K 对应的类内平方和 SSE（列向量）
%     silVec      —— 各 K 对应的平均轮廓系数（列向量）
%     idxBest     —— 最佳 K 下的聚类标签（N×1）
%     centersBest —— 最佳 K 下的聚类中心（标准化空间，K×D）

if nargin < 2, Krange = 2:8; end
Krange = Krange(:)';
nK = numel(Krange);

sseVec      = zeros(nK, 1);
silVec      = zeros(nK, 1);
idxAll      = cell(nK, 1);
centersAll  = cell(nK, 1);

fprintf('  --- 最佳 K 值选择（K = %d .. %d） ---\n', Krange(1), Krange(end));
for i = 1:nK
    K = Krange(i);
    [idxK, cK, sseK] = kmeans_cluster(X, K, nRep);
    idxAll{i}     = idxK;
    centersAll{i} = cK;
    sseVec(i)     = sseK;
    silVec(i)     = mean_silhouette(X, idxK);
    fprintf('    K=%d : SSE=%.4e   平均轮廓系数=%.4f\n', K, sseK, silVec(i));
end

%% 综合判定最佳 K
K_best = decide_best_K(sseVec, silVec, Krange);
iBest  = find(Krange == K_best, 1);
idxBest     = idxAll{iBest};
centersBest = centersAll{iBest};
fprintf('  >> 综合（SSE 肘部法 + 平均轮廓系数）确定最佳 K = %d\n', K_best);

%% 绘制 SSE 肘部图
figure('Color', 'w', 'Position', [100 100 620 420]);
plot(Krange, sseVec, '-o', 'LineWidth', 1.6, 'MarkerSize', 7, ...
     'MarkerFaceColor', [0.30 0.55 0.90]);
hold on;
plot(K_best, sseVec(iBest), 'ro', 'MarkerSize', 12, 'LineWidth', 1.8);  % 标注最佳 K
hold off;
xlabel('聚类数 K');  ylabel('SSE（类内平方和）');
title(sprintf('SSE 肘部图（方案 %s）', prefix));
grid on;  box on;
xlim([Krange(1) - 0.3, Krange(end) + 0.3]);
saveas(gcf, fullfile(outDir, sprintf('SSE_%s.png', prefix)));

%% 绘制平均轮廓系数变化图
figure('Color', 'w', 'Position', [100 100 620 420]);
plot(Krange, silVec, '-s', 'LineWidth', 1.6, 'MarkerSize', 7, ...
     'MarkerFaceColor', [0.90 0.50 0.30]);
hold on;
plot(K_best, silVec(iBest), 'ro', 'MarkerSize', 12, 'LineWidth', 1.8);  % 标注最佳 K
hold off;
xlabel('聚类数 K');  ylabel('平均轮廓系数');
title(sprintf('平均轮廓系数变化图（方案 %s）', prefix));
grid on;  box on;
xlim([Krange(1) - 0.3, Krange(end) + 0.3]);
saveas(gcf, fullfile(outDir, sprintf('Silhouette_%s.png', prefix)));

end

%% ==================== 本地子函数 ====================

function s = mean_silhouette(X, idx)
% MEAN_SILHOUETTE 手动计算平均轮廓系数
%   a(i)：样本 i 到同簇其它样本的平均距离；
%   b(i)：样本 i 到最近其它簇的平均距离（取各其它簇平均距离的最小值）；
%   s(i) = (b(i) - a(i)) / max(a(i), b(i))，
%   平均轮廓系数 = mean(s(i))。取值范围 [-1, 1]，越大聚类结构越好。
%
%   距离矩阵用恒等式 ||a-b||² = |a|² + |b|² - 2ab' 计算，
%   避免高维张量展开造成的内存膨胀。

[N, D] = size(X);
K   = max(idx);
aVal = zeros(N, 1);
bVal = inf(N, 1);

for a = 1:K
    mA = find(idx == a);
    nA = numel(mA);
    if nA == 0, continue; end

    DA   = X(mA, :);
    nrmA = sum(DA.^2, 2);                       % nA×1

    % 簇内：到同簇其它样本的平均距离（对角线恰为 0，sum 后除以 nA-1 即排除自身）
    if nA == 1
        aVal(mA) = 0;
    else
        DAA = nrmA + nrmA' - 2 * (DA * DA');    % nA×nA，对角线恰为 0
        DAA = max(DAA, 0);                       % 消除浮点微小负值
        aVal(mA) = sum(DAA, 2) / (nA - 1);       % nA 项（含 0 对角线）除以 nA-1
    end

    % 簇间：到每个其它簇的平均距离，取最小值
    for b = 1:K
        if b == a, continue; end
        mB = find(idx == b);
        if isempty(mB), continue; end
        DB   = X(mB, :);
        nrmB = sum(DB.^2, 2);
        DAB  = nrmA + nrmB' - 2 * (DA * DB');   % nA×nB
        DAB  = max(DAB, 0);
        avgB = mean(DAB, 2);                     % 样本 i 到簇 b 的平均距离
        bVal(mA) = min(bVal(mA), avgB);
    end
end

sAll = (bVal - aVal) ./ max(aVal, bVal);
s = mean(sAll, 'omitnan');               % 防御：个别 0/0 的退化点不拖垮整体

end

function K_best = decide_best_K(sseVec, silVec, Krange)
% DECIDE_BEST_K 综合 SSE 肘部法与平均轮廓系数法判定最佳 K

% —— 肘部法：归一化后曲线上离首尾连线（弦）最远的点 ——
%   归一化后曲线从 (0,1) 到 (1,0)，弦方程为 sseN = 1 - Kf，
%   点到弦的垂直距离 ∝ |sseN + Kf - 1|（全部按列向量逐元素计算，保证标量索引）
Kf = (Krange(:) - Krange(1)) ./ (Krange(end) - Krange(1));     % nK×1，K 归一到 [0,1]
if max(sseVec) == min(sseVec)
    [~, iElbow] = min(sseVec);
else
    sseN = (sseVec - min(sseVec)) ./ (max(sseVec) - min(sseVec));  % nK×1，SSE 归一到 [0,1]
    [~, iElbow] = max(abs(sseN + Kf - 1));    % 到弦的垂直距离最大点（标量索引）
end

% —— 轮廓系数法：平均轮廓系数最大的 K ——
[~, iSil] = max(silVec);

if iElbow == iSil
    K_best = Krange(iSil);
else
    % 轮廓系数峰值明显（峰比次峰高 0.02 以上）时优先轮廓系数，否则取肘部
    silSorted = sort(silVec, 'descend');
    if silVec(iSil) - silSorted(2) > 0.02
        K_best = Krange(iSil);
    else
        K_best = Krange(iElbow);
    end
end

end
