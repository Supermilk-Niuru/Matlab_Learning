function [beta, stats] = logistic_newton(X, Y)
% LOGISTIC_NEWTON 牛顿迭代法求解 Logistic 回归（最大似然估计，IRLS）
%
%   概率模型：P(Y=1|X) = 1/(1+exp(-z))，z = Xβ，Y=1 表示流失。
%   负对数似然最小化等价于最大似然，牛顿迭代：
%     第 k 次：
%       p_i = 1/(1+exp(-Xβ))            （预测概率）
%       W   = diag(p_i(1-p_i))          （权重矩阵）
%       g   = X'(Y-p)                   （梯度）
%       H   = X'WX                      （Hessian 矩阵，负对数似然的二阶导）
%       β_new = β_old + inv(H)·g        （牛顿更新）
%   收敛准则：||β_new - β_old|| < 1e-8，或最大迭代 100 次。
%   输出每一次迭代误差。
%
%   显著性检验（Wald 检验）：协方差阵 ≈ H^{-1}，
%     标准误 se = sqrt(diag(H^{-1}))，z统计量 = β/se，p值 = 2(1-Φ(|z|))。
%   标准正态 CDF 由基础函数 erf 计算：Φ(x) = 0.5(1+erf(x/√2))，
%     故 p值 = 1 - erf(|z|/√2)。不依赖统计/机器学习工具箱。
%
%   输入：
%     X —— N×(D+1) 设计矩阵（第一列为截距 1）
%     Y —— N×1 二分类标签（0/1）
%   输出：
%     beta  —— (D+1)×1 系数向量（β(1)=截距 β0）
%     stats —— 结构体：se / z / p / iter / err

maxIter = 100;               % 最大迭代次数
tol     = 1e-8;              % 收敛容差

%% ---- 初始化 β = 0 ----
p  = size(X, 2);
beta = zeros(p, 1);

fprintf('======== 牛顿迭代法求解 Logistic 回归（最大似然估计） ========\n');

%% ---- 牛顿迭代 ----
for k = 1:maxIter
    prob = sigmoid_stable(X * beta);          % p_i
    g    = X' * (Y - prob);                   % 梯度
    w    = prob .* (1 - prob);                % 权重 p_i(1-p_i)
    H    = (X .* w)' * X;                     % Hessian = X'WX（避免构造完整对角阵）
    delta = H \ g;                            % 左除求解（数值上等价于 inv(H)*g，更稳定）
    betaNew = beta + delta;
    err = norm(betaNew - beta, 2);            % 迭代误差 ||β_new-β_old||
    fprintf('  迭代 %2d：||β_new-β_old|| = %.3e\n', k, err);
    beta = betaNew;
    if err < tol
        fprintf('  已收敛（误差 < %.0e），迭代次数：%d。\n', tol, k);
        break;
    end
end
if err >= tol
    fprintf('  警告：达到最大迭代次数 %d，误差 = %.3e。\n', maxIter, err);
end

%% ---- 标准误 / z统计量 / p值（Wald 检验） ----
prob = sigmoid_stable(X * beta);              % 在最终 β 处重算概率
w    = prob .* (1 - prob);
H    = (X .* w)' * X;
covBeta = inv(H);                             % 参数协方差阵 ≈ H^{-1}
se  = sqrt(diag(covBeta));
z   = beta ./ se;                             % z 统计量
pv  = 1 - erf(abs(z) / sqrt(2));              % 双尾 p 值（标准正态分布）

stats = struct('se', se, 'z', z, 'p', pv, 'iter', k, 'err', err);

end

%% ---------- 局部函数 ----------
function p = sigmoid_stable(z)
% SIGMOID_STABLE 数值稳定的 sigmoid 函数，避免 exp 溢出
%   p = 1/(1+exp(-z))
p = zeros(size(z));
pos = z >= 0;
p(pos)  = 1 ./ (1 + exp(-z(pos)));
p(~pos) = exp(z(~pos)) ./ (1 + exp(z(~pos)));
end
