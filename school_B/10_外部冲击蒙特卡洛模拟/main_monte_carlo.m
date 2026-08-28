%% main_monte_carlo.m —— 问题4（第一步）：单客户流失概率的动态蒙特卡洛模拟
%  ======================================================================
%  目标：在外部冲击（竞争对手降价 + 宏观经济等随机扰动）下，对一个代表性
%        客户的流失概率 p(t) 进行蒙特卡洛模拟，输出一条代表性的动态流失
%        概率轨迹 p_median(t)。【本阶段只做蒙特卡洛模拟，不做稳健性评价、
%        不做动态挽留策略设计。】
%
%  随机过程模型（建模手给定，严格使用、不自行修改）：
%     漂移项   μ(p,t)  = k · (Δprice/price) · (1-p(t))
%     波动项   σ(p,t)  = σ0 · sqrt(p(t)·(1-p(t)))
%     离散形式 P_{t+Δt} = P_t + k·(Δprice/price)·(1-p_t)·Δt
%                          + σ0·sqrt(p_t·(1-p_t))·Z ,  Z ~ N(0,1)
%     边界处理  0 ≤ p(t) ≤ 1（每一步更新后裁剪）
%
%  外部环境因素的进入方式：
%     竞争对手降价（有规律的外部冲击）→ 确定性情景参数 Δprice/price 进入漂移项；
%     宏观经济等无规律因素             → Z ~ N(0,1) 随机扰动进入波动项。
%
%  初始流失概率 p(0)：
%     使用【优化 Logistic 模型】（读取 06_Logistic流失判定/优化Logistic模型/
%     Optimized_Logistic_beta.xlsx 中已估计好的"原始变量尺度"β 系数，
%     不重新训练、不读取原始 Logistic 模型）。
%     对全部 7032 名有效客户计算 p(0)，选取 p(0) 最接近整体中位数的客户
%     作为代表性客户（客观、可复现），其 p(0) 即为模拟初始值。
%
%  蒙特卡洛：
%     rng(2026) 固定随机种子；num_simulations 条路径均从同一 p(0) 出发；
%     代表性轨迹 = 各时刻所有路径的中位数 p_median(t)（附 5%~95% 分位区间）。
%
%  本程序不修改、不覆盖 01~09 任何目录中的文件；全部输出保存在
%   10_外部冲击蒙特卡洛模拟/（main_monte_carlo.m / monte_carlo_result.xlsx /
%   monte_carlo_probability.png）。
%
%  运行方式：MATLAB R2025a 命令行直接执行 main_monte_carlo（仅基础函数）。
%  ======================================================================

clc; clear; close all;

%% ---------- 0) 定位工作目录 ----------
% 本脚本位于 10_外部冲击蒙特卡洛模拟/；数据与模型在上级目录 01_数据预处理/、
% 06_Logistic流失判定/。输出文件与脚本保存在同一目录（不修改 01~09 任何文件）。
scriptDir = fileparts(mfilename('fullpath'));
if ~isempty(scriptDir)
    cd(scriptDir);                        % 切换到 10_外部冲击蒙特卡洛模拟/
end
outDir = pwd;                             % 输出目录 = 脚本所在目录

%% ---------- 1) 模型参数（集中设置：含义清晰、便于修改，不重复定义） ----------
% 漂移系数 k：衡量竞争价格压力（Δprice/price）对流失概率上升的敏感程度。
%   —— 基准情景假设：k = 0.3。题目未直接给出 k，不伪装成数据拟合结果。
k = 0.3;

% 竞争对手相对价格变化率 Δprice/price（确定性外部环境/情景参数，不用随机数生成）：
%   竞争对手降价 → 我司相对价格劣势扩大 → 流失概率上升。
%   本脚本将 Δprice/price 定义为"竞争价格压力/相对价格劣势的变化率"，
%   取正数 0.10 表示竞争对手降价使我司相对价格劣势扩大 10%，
%   于是漂移项 k·price_change_rate·(1-p) > 0，流失概率随竞争压力上升，符合业务直觉。
%   修改此参数即可模拟不同降价幅度的情景（如 0.05 / 0.15 / 0.20）。
%   —— 基准情景假设：price_change_rate = 0.10。
price_change_rate = 0.05;

% 随机波动系数 sigma0：刻画宏观经济等无规律因素的扰动强度。
%   —— 基准情景假设：sigma0 = 0.1。题目未直接给出，不伪装成数据拟合结果。
sigma0 = 0.1;

% 模拟总时间 T（月）与时间步长 dt（月）。
%   —— 基准情景假设：T = 24（月），dt = 0.5（月）。
%      更细的时间网格使轨迹更平滑；噪声项严格按建模手给定形式（不含 sqrt(dt)）。
T  = 24;                 % 模拟总时间（月）
dt = 0.5;                % 时间步长（月）
N  = round(T / dt);      % 时间步数

% 蒙特卡洛模拟次数（每条路径独立随机，但均从同一 p(0) 出发）
num_simulations = 5000;

% 随机种子：保证结果可复现
rng(2026);

fprintf('======== 问题4：单客户流失概率蒙特卡洛模拟 ========\n\n');

%% ---------- 2) 读取优化 Logistic 模型 β 系数（原始变量尺度，不重新训练） ----------
optDir    = fullfile(pwd, '..', '06_Logistic流失判定', '优化Logistic模型');
betaFile  = fullfile(optDir, 'Optimized_Logistic_beta.xlsx');
if ~isfile(betaFile)
    error('[main_monte_carlo] 未找到优化Logistic模型文件：\n%s\n请先运行 06_Logistic流失判定/优化Logistic模型/main_optimized_logistic.m。', betaFile);
end
B          = readtable(betaFile, 'VariableNamingRule', 'preserve');
beta0_orig = B.('β原始尺度')(1);        % 截距 β0（原始变量尺度）
beta_orig  = B.('β原始尺度')(2:end);    % 13 个变量的原始尺度系数

%% ---------- 3) 读取有效客户数据（删除总费用缺失样本，与优化模型一致） ----------
csvFile = fullfile(pwd, '..', '01_数据预处理', 'B_processed.csv');
if ~isfile(csvFile)
    error('[main_monte_carlo] 未找到数据文件：%s\n请先运行 01_数据预处理/main_preprocess.m。', csvFile);
end
D = readtable(csvFile, 'VariableNamingRule', 'preserve');
bad     = isnan(D.('总费用'));
origRow = find(~bad);                   % 客户编号 = 有效样本在 B_processed.csv 中的原始行号
D(bad, :) = [];

%% ---------- 4) 优化 Logistic 的 13 个输入变量 ----------
catVars = {'是否为老年人'; '是否有伴侣'; '是否有家属'; ...
           '是否开通在线安全'; '是否开通在线备份'; '是否开通设备保护'; ...
           '是否开通技术支持'; '是否开通电视流媒体'; '是否开通电影流媒体'; ...
           '合同类型'; '是否使用电子账单'; '支付方式'};
contVar = '在网时长（月）';
Xcat = table2array(D(:, catVars));      % 12 个分类变量（0/1/2 类别编码，直接使用）
Xcon = D.(contVar);                     % 连续变量（原始值，月）

%% ---------- 5) 计算全部有效客户 p(0)，选取中位数代表性客户 ----------
% 优化Logistic原始尺度方程：logit = β0 + Σβ_i·X_i（在网时长按原始值代入）
logit = beta0_orig + Xcat * beta_orig(1:12) + beta_orig(13) .* Xcon;

% 数值稳定的 sigmoid：p = 1/(1+e^{-logit})
p0All = zeros(size(logit));
pos   = logit >= 0;
p0All(pos)  = 1 ./ (1 + exp(-logit(pos)));
p0All(~pos) = exp(logit(~pos)) ./ (1 + exp(logit(~pos)));

% 选择 p(0) 最接近整体中位数的客户作为代表性客户（客观、可复现）
med0  = median(p0All);
[~, idx] = min(abs(p0All - med0));
custID = origRow(idx);
p0     = p0All(idx);

fprintf('代表性客户编号：%d\n', custID);
fprintf('（选择规则：7032 名有效客户中，优化Logistic p(0) 最接近整体中位数 %.4f 的客户）\n', med0);
fprintf('\n该客户 13 个优化Logistic输入变量：\n');
for i = 1:12
    fprintf('    %-14s = %g\n', catVars{i}, Xcat(idx, i));
end
fprintf('    %-14s = %g\n', contVar, Xcon(idx));
fprintf('初始流失概率 p(0)：%.4f\n', p0);

fprintf('\n蒙特卡洛模拟次数：%d\n', num_simulations);
fprintf('模拟总时间：%g（月）\n', T);
fprintf('时间步长：%g（月）\n', dt);

fprintf('\n竞争对手价格变化率 Δprice/price：%+.2f\n', price_change_rate);
fprintf('漂移系数 k：%.3f\n', k);
fprintf('随机波动系数 sigma0：%.3f\n', sigma0);

fprintf('\n[参数说明] k、sigma0、T、dt 均为基准情景假设（题目未直接给出），\n');
fprintf('仅用于展示外部冲击下客户流失概率的动态演化；后续可通过敏感性分析进一步校准。\n');

%% ---------- 6) 蒙特卡洛模拟：num_simulations 条路径，均从 p(0) 出发 ----------
tAll = (0:N) * dt;                      % 时间向量（N+1 个时刻）
pAll = zeros(num_simulations, N+1);     % 每条路径 × 每个时刻
pAll(:, 1) = p0;

for s = 1:num_simulations
    p = p0;
    Z = randn(1, N);                    % 每个时间步一个标准正态随机扰动
    for j = 1:N
        % 严格按建模手给定离散形式计算（噪声项不含 sqrt(dt)）
        p = p + k * price_change_rate * (1 - p) * dt ...
              + sigma0 * sqrt(p * (1 - p)) * Z(j);
        % 边界处理：确保 0 ≤ p(t) ≤ 1
        p = max(0, min(1, p));
        pAll(s, j+1) = p;
    end
end

% 代表性轨迹：各时刻所有路径的中位数；附 5%~95% 分位区间
pMed = median(pAll, 1);
p5   = prctile(pAll,  5, 1);
p95  = prctile(pAll, 95, 1);

%% ---------- 7) 绘图：单客户流失概率的动态蒙特卡洛模拟 ----------
figure('Color', 'w', 'Position', [100 100 900 560]);
hold on; box on;

% 浅色细线：示意蒙特卡洛的多条单条路径（抽样展示，不全部画出）
nShow  = 30;
shIdx  = round(linspace(1, num_simulations, nShow));
hSample = plot(tAll, pAll(shIdx(1), :), 'Color', [0.70 0.70 0.70 0.35], 'LineWidth', 0.6);
for s = shIdx(2:end)
    plot(tAll, pAll(s, :), 'Color', [0.70 0.70 0.70 0.35], 'LineWidth', 0.6);
end

% 5%~95% 分位区间带
hBand = fill([tAll, fliplr(tAll)], [p5, fliplr(p95)], [0.25 0.50 0.85], ...
             'FaceAlpha', 0.18, 'EdgeColor', 'none');

% 代表性中位数轨迹
hMed = plot(tAll, pMed, 'Color', [0.05 0.20 0.65], 'LineWidth', 2.4);

% 体现约束区间 0 ≤ p(t) ≤ 1
plot([0 T], [0 0], 'k--', 'LineWidth', 0.8);
plot([0 T], [1 1], 'k--', 'LineWidth', 0.8);
text(T*0.02, 0.955, '约束区间：0 ≤ p(t) ≤ 1', 'FontSize', 9, 'Color', [0.2 0.2 0.2]);

xlim([0 T]); ylim([0 1]);
xlabel('时间 t（月）');
ylabel('流失概率 p(t)');
title('单客户流失概率的动态蒙特卡洛模拟');
grid on;
legend([hSample hBand hMed], ...
       {'单条模拟路径（示例）', '5%～95% 分位区间', '代表性轨迹 p_{med}(t)'}, ...
       'Location', 'northwest', 'FontSize', 9);

% 隐藏全部坐标区工具栏（含图例内部），避免导出图像时残留
for hA = findall(gcf, 'type', 'axes')'
    hA.Toolbar.Visible = 'off';
end

pngFile = fullfile(outDir, 'monte_carlo_probability.png');
exportgraphics(gcf, pngFile, 'Resolution', 300);

%% ---------- 8) 保存结果：代表性轨迹 + 全部模拟路径 ----------
xlsxFile = fullfile(outDir, 'monte_carlo_result.xlsx');
if isfile(xlsxFile); delete(xlsxFile); end

% Sheet1：代表性轨迹（时间 t / 中位数 p(t) / 5% 分位 / 95% 分位）
outTbl = table(tAll(:), pMed(:), p5(:), p95(:), ...
    'VariableNames', {'时间t_月', '中位数流失概率_p_med', '第5百分位', '第95百分位'});
writetable(outTbl, xlsxFile, 'Sheet', '代表性轨迹', 'WriteMode', 'overwritesheet');

% Sheet2：全部模拟路径（每行一个时刻，每列一条模拟路径）
fullTbl = [table(tAll(:), 'VariableNames', {'时间t_月'}), array2table(pAll')];
writetable(fullTbl, xlsxFile, 'Sheet', '全部模拟路径', 'WriteMode', 'overwritesheet');

%% ---------- 9) 校验与完成输出 ----------
ok01 = all(pMed >= 0 & pMed <= 1);
fprintf('\np(t) 最小值：%.4f\n', min(pMed));
fprintf('p(t) 最大值：%.4f\n', max(pMed));
fprintf('p(0)：%.4f\n', pMed(1));
fprintf('p(T)：%.4f\n', pMed(end));

fprintf('\n已保存：\n  monte_carlo_result.xlsx\n  monte_carlo_probability.png\n  （目录：%s）\n', outDir);

fprintf('\n=====================================================\n');
fprintf('问题4蒙特卡洛动态流失概率模拟完成。\n');
fprintf('=====================================================\n');

fprintf('\n[校验] 代表性轨迹全部满足 0 ≤ p(t) ≤ 1：%s\n', tern(ok01));
fprintf('[校验] 使用优化 Logistic 模型（读取已估计 β 系数，未重新训练）：是\n');
fprintf('[校验] 未读取/未使用原始 Logistic 模型：是\n');
fprintf('[校验] 蒙特卡洛多路径模拟（%d 条，同一 p(0) 出发）：是\n', num_simulations);
fprintf('[校验] 未修改 01~09 任何目录文件（仅写入 10_外部冲击蒙特卡洛模拟/）：是\n');

%% 局部函数：三元判断（逻辑值 → 中文显示）
function s = tern(x)
    if x; s = '是'; else; s = '否'; end
end
