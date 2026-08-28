function [idx, centers, SSE] = kmeans_cluster(X, K, nRep)
% KMEANS_CLUSTER 手动实现 K-means 聚类（不依赖统计/机器学习工具箱）
%   聚类目标：最小化类内平方和（组内误差平方和）
%     SSE = Σ_i Σ_k ||x_i - μ_k||² · 1{c_i = k}
%   距离：欧氏距离。
%   初始化：kmeans++（第一个中心均匀随机，后续中心按 D(x)² 比例选取）。
%   迭代：Lloyd 算法（分配最近中心 → 中心更新为簇内均值），直到分配不变。
%   多起点：重复 nRep 次，取类内平方和最小的一次。
%           主程序已设置随机种子 rng，故结果可复现。
%
%   输入：
%     X    —— N×D 标准化数据矩阵
%     K    —— 聚类数
%     nRep —— 随机起始重复次数（默认 20）
%   输出：
%     idx     —— N×1 聚类标签（取值 1..K）
%     centers —— K×D 聚类中心（标准化空间）
%     SSE     —— 类内平方和（聚类目标函数值）

if nargin < 3
    nRep = 20;
end

[N, D] = size(X);
bestSSE = Inf;
idx     = zeros(N, 1);
centers = zeros(K, D);

for r = 1:nRep
    [idxR, cR, sseR] = kmeans_once(X, K);
    if sseR < bestSSE
        bestSSE = sseR;
        idx     = idxR;
        centers = cR;
    end
end

SSE = bestSSE;

end

%% ==================== 本地子函数 ====================

function [idx, centers, SSE] = kmeans_once(X, K)
% KMEANS_ONCE 单次 K-means：kmeans++ 初始化 + Lloyd 迭代

[N, D] = size(X);
centers = kmeanspp_init(X, K);
idx = zeros(N, 1);

maxIter = 200;
for it = 1:maxIter
    % 1) 分配：每个样本归入欧氏距离最近的中心
    D2 = sum((reshape(X, [N, 1, D]) - reshape(centers, [1, K, D])).^2, 3);
    [~, newIdx] = min(D2, [], 2);

    if isequal(newIdx, idx)
        idx = newIdx;
        break;
    end
    idx = newIdx;

    % 2) 更新：中心 = 簇内样本均值（空簇保留原中心，下轮重新分配）
    for k = 1:K
        inK = find(idx == k);
        if ~isempty(inK)
            centers(k, :) = mean(X(inK, :), 1);
        end
    end
end

% 最终分配与类内平方和（目标函数值）
D2 = sum((reshape(X, [N, 1, D]) - reshape(centers, [1, K, D])).^2, 3);
[minVal, idx] = min(D2, [], 2);
SSE = sum(minVal);

end

function centers = kmeanspp_init(X, K)
% KMEANS++_INIT 初始化聚类中心
%   第一个中心从样本中均匀随机选取；之后每个新中心按与已选中心
%   最短距离的平方成比例的概率选取（D² 加权采样）。

[N, D] = size(X);
centers = zeros(K, D);
centers(1, :) = X(randi(N), :);

for k = 2:K
    d2 = sum((reshape(X, [N, 1, D]) - reshape(centers(1:k-1, :), [1, k-1, D])).^2, 3);
    md2 = min(d2, [], 2);
    total = sum(md2);
    if total <= 0
        centers(k, :) = X(randi(N), :);      % 所有点与已选中心重合（罕见）
    else
        cdf = cumsum(md2) / total;
        centers(k, :) = X(find(cdf >= rand(), 1, 'first'), :);
    end
end

end
