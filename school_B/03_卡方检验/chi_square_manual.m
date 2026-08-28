function [chi2, df, p, C, sig] = chi_square_manual(O, E, alpha)
% CHI_SQUARE_MANUAL 手动完成卡方独立性检验
%   计算步骤：
%     1) 观察频数矩阵 O（由 build_contingency_table 提供）
%     2) 理论频数矩阵 E（由 calculate_expected_table 提供）
%     3) 每个单元格卡方贡献：C_ij = (O_ij - E_ij)² / E_ij
%     4) 卡方统计量：χ² = Σ C_ij（全部单元格贡献之和）
%     5) 自由度：df = (行数 - 1) × (列数 - 1)
%     6) p 值：p = P(χ² > 观测值 | H0)，用高精度上尾概率手动计算，
%        极小 p 值不会下溢为 0（可表示到 ~1E-300 量级）。
%
%   说明：不使用 chi2cdf 等现成函数；上尾概率通过正则化不完全伽马函数
%         Q(a,x) 手动计算，其中 a = df/2，x = χ²/2。
%         - 当 x 较小时：幂级数求 P(a,x)，p = 1 - P（无消减误差）；
%         - 当 x 较大时：Lentz 连分式在对数空间直接求 Q(a,x），
%           避免 e^{-x}·x^a 下溢，从而精确表示极小 p 值。
%
%   输入：
%     O     —— r×2 观察频数矩阵
%     E     —— r×2 理论频数矩阵
%     alpha —— 显著性水平（默认 0.05）
%   输出：
%     chi2 —— 卡方统计量
%     df   —— 自由度
%     p    —— p 值（double，可小至 ~1E-300）
%     C    —— r×2 每个单元格的卡方贡献矩阵
%     sig  —— '显著' 或 '不显著'

if nargin < 3
    alpha = 0.05;
end

% 步骤 3：每个单元格卡方贡献 C_ij = (O_ij - E_ij)² / E_ij
C = (O - E).^2 ./ E;

% 步骤 4：卡方统计量 = 全部单元格贡献之和
chi2 = sum(C(:));

% 步骤 5：自由度 df = (r-1) × (c-1)
df = (size(O, 1) - 1) * (size(O, 2) - 1);

% 步骤 6：p 值（高精度手动实现，不使用 chi2cdf）
p = chi2_survival_manual(chi2, df);

% 显著性判断
if p < alpha
    sig = '显著';
else
    sig = '不显著';
end

end

%% ==================== 本地子函数 ====================

function p = chi2_survival_manual(chi2, df)
% CHI2_SURVIVAL_MANUAL 卡方分布上尾概率 p = P(χ² > chi2)
%   等价于正则化上不完全伽马函数 Q(a, x)，其中 a = df/2，x = χ²/2。
%   用对数空间计算避免下溢，支持极小 p 值（如 1E-258）。
%
%   输入：
%     chi2 —— 卡方统计量（非负）
%     df   —— 自由度（正整数）
%   输出：
%     p    —— 上尾概率

a = df / 2;
x = chi2 / 2;

if x < a + 1
    % ---- 中等 x 分支：幂级数求 P(a,x)，p = 1 - P（此时 P 不接近 1，无消减误差） ----
    P = gamma_lower_series(a, x);
    p = 1 - P;
    p = max(0, min(1, p));
else
    % ---- 大 x 分支：Lentz 连分式在对数空间求 Q(a,x) ----
    FPMIN = 1e-300;     % 防止除法下溢的极小值
    EPS   = 1e-16;      % 收敛阈值
    b = x + 1 - a;
    c = 1 / FPMIN;
    d = 1 / b;
    h = d;
    converged = false;
    for i = 1:5000
        an = -i * (i - a);
        b  = b + 2;
        d  = an * d + b;
        if abs(d) < FPMIN, d = FPMIN; end
        c  = b + an / c;
        if abs(c) < FPMIN, c = FPMIN; end
        d  = 1 / d;
        del = d * c;
        h  = h * del;
        if abs(del - 1) < EPS
            converged = true;
            break;
        end
    end

    if ~converged
        % 极罕见情况：连分式未收敛，退回幂级数分支
        P = gamma_lower_series(a, x);
        p = max(0, 1 - P);
        warning('[chi_square_manual] 连分式未收敛，已退回幂级数分支。');
        return;
    end

    % Γ(a,x) ≈ e^{-x}·x^a·h，取对数得 log(Γ(a,x)) = -x + a·ln(x) + ln(h)
    % 正则化：log Q(a,x) = log(Γ(a,x)) - log(Γ(a))
    logQ = (-x + a * log(x) + log(h)) - gammaln(a);
    p = exp(logQ);
    p = max(0, min(1, p));
end

end

function P = gamma_lower_series(a, x)
% GAMMA_LOWER_SERIES 用幂级数计算正则化下不完全伽马函数 P(a,x)
%   P(a,x) = e^{-x}·x^a / Γ(a+1) × Σ_{n=0}^∞ x^n / ((a+1)(a+2)···(a+n))
%   注：分母自 a+1 起（不含 a），故换算为 Γ(a+1) = a·Γ(a)，避免系数缺失。
    logPref = a * log(x) - x - gammaln(a + 1);
    S = 1;
    term = 1;
    for n = 1:5000
        term = term * x / (a + n);
        S = S + term;
        if abs(term) < 1e-16 * S
            break;
        end
    end
    P = exp(logPref) * S;
end
