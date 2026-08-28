function [model, method, importance, nTrees] = train_randomforest(X, Y)
% TRAIN_RANDOMFOREST 随机森林二分类流失判定模型训练
%
%   双路径实现（优先调用统计/机器学习工具箱，无工具箱则手动实现）：
%     [路径1] TreeBagger（工具箱可用时）：
%        TreeBagger(100, X, categorical(Y)) 分类随机森林，
%        随机特征数 sqrt(16)=4，最小叶节点样本 10，
%        开启 OOB 预测与 OOB 置换重要性。
%     [路径2] 手动实现（无工具箱时自动切换）：
%        Bootstrap 有放回抽样 + CART 决策树 + Gini 基尼指数最优分裂 +
%        每次分裂随机抽样 mtry 个特征，特征重要性 = 节点分裂贡献累计
%        （每个内部节点以其 Gini 增益贡献累加到对应特征）。
%
%   超参数（与题目要求一致）：
%     nTrees   = 100     树的数量
%     mtry     = floor(sqrt(16)) = 4   每次分裂随机选择的特征数
%     maxDepth = 10      最大树深度（从根深度 0 计）
%     minLeaf  = 10      叶节点最少样本数
%   说明：决策树按"特征≤阈值"分裂，对量纲不敏感，输入变量无需标准化。
%   随机种子 rng(2026) 在函数内部固定，保证训练结果可复现。
%
%   输入：
%     X —— Ntr×16 训练输入（原始量纲即可）
%     Y —— Ntr×1  训练标签（0/1，1=流失）
%   输出：
%     model     —— TreeBagger 路径：TreeBagger 对象；手动路径：cell 数组（每棵树的 struct）
%     method    —— 'TreeBagger' 或 '手动CART'
%     importance—— P×1 特征重要性（OOB 置换重要性 或 节点分裂贡献累计）
%     nTrees    —— 使用的树数量

nTrees   = 100;
mtry     = floor(sqrt(size(X, 2)));   % sqrt(16) = 4
maxDepth = 10;
minLeaf  = 10;

%% 路径检测：统计/机器学习工具箱是否可用
useTreeBagger = ~isempty(which('TreeBagger'));

if useTreeBagger
    % ---------------- 路径1：TreeBagger（工具箱） ----------------
    method = 'TreeBagger';
    fprintf('检测到统计/机器学习工具箱，使用 TreeBagger 训练分类随机森林...\n');

    rng(2026);                                    % 固定随机种子
    resp = categorical(Y, [0; 1], {'0'; '1'});    % 数值标签 -> 分类标签（强制分类任务）
    model = TreeBagger(nTrees, X, resp, ...
        'NumPredictorsToSample', mtry, ...        % 每次分裂随机特征数 sqrt(16)=4
        'MinLeaf', minLeaf, ...                   % 叶节点最小样本数 10
        'OOBPrediction', 'on', ...                % 记录袋外预测（用于重要性）
        'OOBPredictorImportance', 'on');          % 计算 OOB 置换重要性

    % 特征重要性：优先函数 oobPermutedPredictorImportance，退化取属性
    try
        importance = oobPermutedPredictorImportance(model);
    catch
        importance = model.OOBPermutedPredictorDeltaError;
    end
    importance = importance(:);                   % 统一为列向量
    if ~all(isfinite(importance))                 % 防御：异常时置 0
        importance = zeros(size(importance));
    end

else
    % ---------------- 路径2：手动实现（无工具箱） ----------------
    method = '手动CART';
    fprintf('未检测到 TreeBagger，使用手动实现（Bootstrap + CART + Gini 基尼指数）...\n');

    Ntr = size(X, 1);
    forest     = cell(nTrees, 1);
    importance = zeros(size(X, 2), 1);            % 节点分裂贡献累计

    rng(2026);                                    % 固定随机种子（复现训练）
    for t = 1:nTrees
        idxb = randi(Ntr, Ntr, 1);                % Bootstrap 有放回抽样
        [tree, contrib] = build_tree(X, Y, idxb, 0, ...
            zeros(size(X, 2), 1), maxDepth, minLeaf, mtry);
        forest{t} = tree;
        importance = importance + contrib;        % 累计该树的贡献
    end
    model = forest;
end

fprintf('随机森林训练完成：方法 = %s，树数 = %d。\n', method, nTrees);

end

%% ==================== 局部函数：手动 CART 决策树 ====================
function [node, contrib] = build_tree(X, Y, idx, depth, contrib, maxDepth, minLeaf, mtry)
% BUILD_TREE 递归构建 CART 决策树（二分类，Gini 指数最优分裂）
%
%   树结构（MATLAB struct）：
%     叶节点：  struct('isLeaf', true,  'prob', p, ...)
%     内部节点：struct('isLeaf', false, 'feature', j, 'threshold', t,
%                      'left', L, 'right', R)
%   分裂规则：X(:,feature) <= threshold 分到左子树，否则右子树。
%   分裂准则：Gini 指数，遍历候选特征所有"相邻不同取值"的中点为阈值，
%     取 Gini 增益最大的 (特征, 阈值)。分裂增益同时累加到 contrib 对应特征
%     （节点分裂贡献法特征重要性）。
%   停止条件：达到最大深度 / 样本过少 / 样本纯（全0或全1） / 无有效分裂。

N    = numel(idx);
n1   = sum(Y(idx));
prob = n1 / N;

% 停止条件：深度达上限 / 样本不足以再分（< 2×minLeaf）/ 节点纯
if depth >= maxDepth || N < 2 * minLeaf || n1 == 0 || n1 == N
    node = struct('isLeaf', true, 'prob', prob, ...
                  'feature', [], 'threshold', [], 'left', [], 'right', []);
    return;
end

gParent = 1 - prob^2 - (1 - prob)^2;      % 父节点 Gini 指数
bestG   = 0;
bestFeat = [];
bestThr  = [];
P = size(X, 2);

cand = randperm(P, mtry);                 % 随机抽样 mtry 个候选特征
for j = cand
    xs = X(idx, j);
    [xs, o] = sort(xs);                   % 升序排序（MATLAB sort 对相等元素保持稳定）
    ys = Y(idx(o));

    d   = diff(xs);
    pos = find(d > 0);                    % 分裂候选位置：xs(pos) < xs(pos+1)
    if isempty(pos), continue; end

    csy = cumsum(ys);
    nL  = pos(:);                         % 左侧样本数 = pos
    nR  = N - nL;
    ok  = (nL >= minLeaf) & (nR >= minLeaf);   % 两侧都不小于最小叶样本
    if ~any(ok), continue; end

    sL = csy(pos);                        % 左侧正类样本数
    sR = csy(end) - sL;                   % 右侧正类样本数
    pL = sL ./ nL;
    pR = sR ./ nR;
    gL = 1 - pL.^2 - (1 - pL).^2;         % 左子节点 Gini
    gR = 1 - pR.^2 - (1 - pR).^2;         % 右子节点 Gini
    gain = gParent - (nL .* gL + nR .* gR) ./ N;   % Gini 增益

    gain(~ok) = -Inf;                     % 非法分裂置 -Inf
    [gBest, gi] = max(gain);
    if gBest > bestG
        bestG   = gBest;
        bestFeat = j;
        bestThr = (xs(pos(gi)) + xs(pos(gi) + 1)) / 2;   % 相邻值中点作为阈值
    end
end

% 无有效分裂（增益 ≤ 0）→ 生成叶节点
if bestG <= 0
    node = struct('isLeaf', true, 'prob', prob, ...
                  'feature', [], 'threshold', [], 'left', [], 'right', []);
    return;
end

% 记录分裂贡献并递归构建子树
contrib(bestFeat) = contrib(bestFeat) + bestG;

mask = X(idx, bestFeat) <= bestThr;
[left, contrib]  = build_tree(X, Y, idx(mask),   depth + 1, contrib, maxDepth, minLeaf, mtry);
[right, contrib] = build_tree(X, Y, idx(~mask),  depth + 1, contrib, maxDepth, minLeaf, mtry);

node = struct('isLeaf', false, 'prob', prob, ...
              'feature', bestFeat, 'threshold', bestThr, ...
              'left', left, 'right', right);

end
