function res = anova_manual(x, churn, varName, alpha)
% ANOVA_MANUAL 手动实现单因素方差分析（One-way ANOVA，F 检验）
%   研究问题：不同流失状态下，连续变量 X 的均值是否存在显著差异。
%
%   总体划分（k = 2）：
%     G1：是否流失 = 0（未流失）
%     G2：是否流失 = 1（流失）
%   记第 i 组第 j 个样本为 x_ij，第 i 组样本量为 n_i，总样本量为 N。
%
%   手动计算步骤：
%     步骤1 第 i 组样本均值：x̄_i = (1/n_i)·Σ_j x_ij
%     步骤2 总体均值：x̄ = (1/N)·Σ_i Σ_j x_ij
%     步骤3 总离差平方和：SST = Σ_i Σ_j (x_ij - x̄)²
%     步骤4 组间平方和：SSA = Σ_i n_i·(x̄_i - x̄)²
%     步骤5 组内平方和：SSE = Σ_i Σ_j (x_ij - x̄_i)²
%     步骤6 验证平方和分解：SST = SSA + SSE，误差 |SST-(SSA+SSE)| 接近 0
%     步骤7 组间均方：MSA = SSA / df_A，df_A = k-1
%     步骤8 组内均方：MSE = SSE / df_E，df_E = N-k
%     步骤9 F 统计量：F = MSA / MSE，由 F(df_A, df_E) 计算 p 值
%
%   p 值说明：不使用 fcdf 等现成函数。F 分布上尾概率用正则化不完全
%   beta 函数表示（p = I_{d2/(d2+d1·F)}(d2/2, d1/2)），并在对数空间
%   计算，极小 p 值（如 1E-300 以下）不会下溢为 0，仍能给出科学计数形式。
%
%   缺失值处理：原始数据禁止修改。总费用存在 NaN，计算时忽略缺失值，
%   并输出原始样本数量 / 缺失数量 / 有效样本数量。
%
%   输入：
%     x       —— 连续变量取值列向量（可含 NaN）
%     churn   —— 目标变量"是否流失"列向量（0=未流失，1=流失）
%     varName —— 连续变量名称（中文，字符串）
%     alpha   —— 显著性水平（默认 0.05）
%   输出：
%     res —— 结果结构体，含数值统计量与 4 个输出表格：
%            descTbl  Sheet1 描述统计（流失状态/样本数量/均值/标准差）
%            sqTbl    Sheet2 平方和计算过程（总体均值/SST/SSA/SSE/分解误差）
%            anovaTbl Sheet3 ANOVA表（来源/平方和/自由度/均方/F值/p值）
%            conclTbl Sheet4 检验结论（变量名称/F/df1/df2/p值/显著性）

if nargin < 4
    alpha = 0.05;
end

x = x(:);
churn = churn(:);

%% ---------- 缺失值处理（忽略缺失值，不修改原始数据） ----------
N_orig    = numel(x);                     % 原始样本数量
N_missing = sum(isnan(x));                % 缺失数量
valid     = ~isnan(x) & ~isnan(churn);    % 有效样本掩码
N_valid   = sum(valid);                   % 有效样本数量
xv = x(valid);
cv = churn(valid);

%% ---------- 分组（k = 2） ----------
g1 = (cv == 0);                           % G1：未流失
g2 = (cv == 1);                           % G2：流失
n1 = sum(g1);
n2 = sum(g2);
N  = n1 + n2;                             % 有效总样本量（= N_valid）
x1 = xv(g1);
x2 = xv(g2);

%% ---------- 步骤1：各组样本均值 ----------
mean1 = mean(x1);
mean2 = mean(x2);
sd1   = std(x1);                          % 样本标准差（1/(n-1)）
sd2   = std(x2);

%% ---------- 步骤2：总体均值 ----------
grandMean = mean(xv);

%% ---------- 步骤3：总离差平方和 SST ----------
SST = sum((xv - grandMean).^2);

%% ---------- 步骤4：组间平方和 SSA ----------
SSA = n1 * (mean1 - grandMean)^2 + n2 * (mean2 - grandMean)^2;

%% ---------- 步骤5：组内平方和 SSE ----------
SSE = sum((x1 - mean1).^2) + sum((x2 - mean2).^2);

%% ---------- 步骤6：验证平方和分解 SST = SSA + SSE ----------
sqErr = abs(SST - (SSA + SSE));

%% ---------- 步骤7：组间均方 MSA（k = 2） ----------
k   = 2;
dfA = k - 1;
MSA = SSA / dfA;

%% ---------- 步骤8：组内均方 MSE ----------
dfE = N - k;
if dfE > 0
    MSE = SSE / dfE;
else
    MSE = NaN;
end

%% ---------- 步骤9：F 统计量与 p 值 ----------
if MSE > 0
    F = MSA / MSE;
else
    F = Inf;
end

if isinf(F)
    p    = 0;
    logp = -Inf;
else
    logp = f_survival_log(F, dfA, dfE);   % ln(p)，对数空间，极小 p 值不归零
    p    = exp(logp);                     % 若 logp < ~-745 则下溢为 0，属正常
end
pStr = format_p_log(logp);                % 科学计数法字符串（保证非零表示）

% 显著性判断（H0：各组均值相等；p < alpha 拒绝 H0）
if p < alpha
    sig = '显著';
else
    sig = '不显著';
end

%% ---------- 构造输出表格 ----------
% Sheet1 描述统计：流失状态 | 样本数量 | 均值 | 标准差
descTbl = table({'未流失'; '流失'; '总计'}, [n1; n2; N], ...
                [mean1; mean2; grandMean], [sd1; sd2; std(xv)], ...
                'VariableNames', {'流失状态', '样本数量', '均值', '标准差'});

% Sheet2 平方和计算过程：项目 | 数值
sqItems = {'总体均值'; '未流失组均值'; '流失组均值'; ...
           'SST（总离差平方和）'; 'SSA（组间平方和）'; 'SSE（组内平方和）'; ...
           'SSA+SSE'; '平方和误差 |SST-(SSA+SSE)|'};
sqVals  = [grandMean; mean1; mean2; SST; SSA; SSE; SSA + SSE; sqErr];
sqTbl   = table(sqItems, sqVals, 'VariableNames', {'项目', '数值'});

% Sheet3 ANOVA表：来源 | 平方和 | 自由度 | 均方 | F值 | p值
anovaTbl = table({'组间'; '组内'; '总计'}, ...
                 [SSA; SSE; SST], ...
                 [dfA; dfE; N - 1], ...
                 [MSA; MSE; NaN], ...
                 [F; NaN; NaN], ...
                 {pStr; ''; ''}, ...
                 'VariableNames', {'来源', '平方和', '自由度', '均方', 'F值', 'p值'});

% Sheet4 检验结论
conclTbl = table({varName}, F, dfA, dfE, {pStr}, {sig}, ...
                 N_orig, N_missing, N_valid, ...
                 'VariableNames', {'变量名称', 'F统计量', 'df1', 'df2', 'p值', ...
                                   '显著性判断', '原始样本数量', '缺失数量', '有效样本数量'});

%% ---------- 结果结构体 ----------
res.varName   = varName;
res.N_orig    = N_orig;
res.N_missing = N_missing;
res.N_valid   = N_valid;
res.n1 = n1;  res.n2 = n2;  res.N = N;
res.mean1 = mean1;  res.mean2 = mean2;  res.grandMean = grandMean;
res.sd1 = sd1;  res.sd2 = sd2;
res.SST = SST;  res.SSA = SSA;  res.SSE = SSE;  res.sqErr = sqErr;
res.dfA = dfA;  res.dfE = dfE;
res.MSA = MSA;  res.MSE = MSE;
res.F = F;  res.p = p;  res.logp = logp;  res.pStr = pStr;  res.sig = sig;
res.descTbl  = descTbl;
res.sqTbl    = sqTbl;
res.anovaTbl = anovaTbl;
res.conclTbl = conclTbl;

end

%% ==================== 本地子函数 ====================

function logp = f_survival_log(F, d1, d2)
% F_SURVIVAL_LOG F 分布上尾概率的自然对数 ln(p)，p = P(F > F_obs)
%   不使用 fcdf。用正则化不完全 beta 函数表示：
%     p = P(F(d1,d2) > F) = I_{d2/(d2 + d1·F)}(d2/2, d1/2)
%   在对数空间计算，即使 p 小到 1E-450 也不会下溢为 0。
%
%   输入：F 统计量（>0），自由度 d1、d2
%   输出：ln(p)

if F <= 0
    logp = 0;                             % p = 1
    return;
end

x = d2 / (d2 + d1 * F);                   % 不完全 beta 的自变量
a = d2 / 2;                               % I_x 的第一参数
b = d1 / 2;                               % I_x 的第二参数

if x < (a + 1) / (a + b + 2)
    % 分支1：直接计算 I_x(a,b)。此时 I_x 较小（p 小），无消减误差。
    logp = log_incomplete_beta(a, b, x);
else
    % 分支2：I_x(a,b) = 1 - I_{1-x}(b,a)。1-x 很小，
    %        I_{1-x} 直接算出后取补，避免"1 减接近 1 的数"的消减。
    one_minus_x = d1 * F / (d2 + d1 * F); % 精确计算 1-x，避免大数相减
    Icomp = exp(log_incomplete_beta(b, a, one_minus_x));
    p = 1 - Icomp;
    logp = log(max(p, realmin));
end

end

function logI = log_incomplete_beta(a, b, x)
% LOG_INCOMPLETE_BETA 在对数空间计算正则化不完全 beta 函数 I_x(a,b)
%   I_x(a,b) = [x^a·(1-x)^b / (a·B(a,b))] × CF(x; a,b)
%   其中 CF 用 Lentz 连分式求值：
%     CF = 1/(1 + d1/(1 + d2/(1 + ...)))
%     d_{2m}   = m(b-m)x / ((a+2m-1)(a+2m))
%     d_{2m+1} = -(a+m)(a+b+m)x / ((a+2m)(a+2m+1))
%   前因子 a·log(x) + b·log(1-x) - log(a) - log(B(a,b)) 均在对数空间
%   累加，避免 x^a 溢出与 B(a,b) 越界；返回 ln(I_x)。
%
%   输入：a,b > 0，x ∈ (0,1)
%   输出：ln(I_x(a,b))

MAXIT = 10000;                            % 最大迭代次数
EPS   = 3e-14;                            % 收敛阈值
FPMIN = 1e-300;                           % 防除零/下溢的极小值

qab = a + b;
qap = a + 1;
qam = a - 1;

c = 1;
d = 1 - qab * x / qap;
if abs(d) < FPMIN, d = FPMIN; end
d = 1 / d;
logCF  = log(abs(d));                     % ln|CF| 累加器
sgnCF  = sign(d);                         % CF 符号（理论上恒正）

for m = 1:MAXIT
    m2 = 2 * m;
    % —— 偶项 ——
    aa = m * (b - m) * x / ((qam + m2) * (a + m2));
    d = 1 + aa * d;
    if abs(d) < FPMIN, d = FPMIN; end
    c = 1 + aa / c;
    if abs(c) < FPMIN, c = FPMIN; end
    d = 1 / d;
    del = d * c;
    if del < 0, sgnCF = -sgnCF; end
    logCF = logCF + log(abs(del));
    % —— 奇项 ——
    aa = -(a + m) * (qab + m) * x / ((a + m2) * (qap + m2));
    d = 1 + aa * d;
    if abs(d) < FPMIN, d = FPMIN; end
    c = 1 + aa / c;
    if abs(c) < FPMIN, c = FPMIN; end
    d = 1 / d;
    del = d * c;
    if del < 0, sgnCF = -sgnCF; end
    logCF = logCF + log(abs(del));

    if abs(del - 1) < EPS
        break;
    end
end

logBeta = gammaln(a) + gammaln(b) - gammaln(a + b);   % ln(B(a,b))
logI = logCF - log(a) - logBeta + a * log(x) + b * log(1 - x);

end

function pStr = format_p_log(logp)
% FORMAT_P_LOG 将 ln(p) 格式化为非零科学计数法字符串
%   极小 p 值（在 double 下溢为 0）仍能正确表示，如 '5.863038E-258'、
%   '1.2E-450'。格式：尾数（6 位小数）+ E + 带符号 3 位指数。
%
%   输入：logp = ln(p)
%   输出：pStr（如 '2.345678E-03'）

if ~isfinite(logp)
    pStr = '0.000000E+000';
    return;
end

log10p = logp / log(10);
e = floor(log10p);                        % 指数
m = 10^(log10p - e);                      % 尾数 ∈ [1,10)
if m >= 10                                % 防御：尾数进位
    m = m / 10;
    e = e + 1;
end

pStr = sprintf('%.6E', m);                % 例如 '2.345678E+00'
pStr = [pStr(1:end-4), sprintf('E%+03d', e)];   % 替换指数为真实值

end
