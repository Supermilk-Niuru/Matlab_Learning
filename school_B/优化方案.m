%% =========================================================================
%% 2026数学建模B题 - 第三/四问联动：基于边际效应递减的动态营销成本最优控制求解
%% =========================================================================
fprintf('====== 步骤 6：正在启动动态挽留成本的最优控制寻优求解 ======\n');

% --- [A. 优化模型超参数设定] ---
C0 = 150;           % 原基本成本基准
alpha_max = 0.85;   % 理论最大挽留成功率上限（极大投入下的极限）
r = 0.025;          % 成本敏感度系数
delta_alpha_drop = 0.05; % 外部冲击损失项

% 假设 prob_rf 是第二问随机森林吐出来的全网测试集流失概率序列（M_test * 1）
% 为了保证独立运行，若前面没跑，这里自动生成一个测试概率流
if ~exist('prob_rf', 'var')
    prob_rf = 0.1 + rand(300, 1) * 0.8; 
end
N_customers = length(prob_rf);

% --- [B. 构造控制变量 C 的搜索网格 (100 <= C <= 300)] ---
C_grid = 100:1:300;
total_costs_record = zeros(length(C_grid), 1);
alpha_record = zeros(length(C_grid), 1);
threshold_record = zeros(length(C_grid), 1);

% --- [C. 穷举网格搜索最优控制变量 C] ---
for idx = 1:length(C_grid)
    C_current = C_grid(idx);
    
    % 1. 计算当前成本下的动态挽留成功率 alpha(C)
    alpha_C = alpha_max / (1 + exp(-r * (C_current - C0))) - delta_alpha_drop;
    if alpha_C < 0, alpha_C = 0; end
    if alpha_C > 1, alpha_C = 1; end
    alpha_record(idx) = alpha_C;
    
    % 2. 计算当前内生动态阈值 delta*(C)
    delta_star = (150 + C_current) / (2000 * alpha_C);
    threshold_record(idx) = delta_star;
    
    % 3. 统计全网所有客户在当前决策下的期望总成本
    current_total_cost = 0;
    for i = 1:N_customers
        p_i = prob_rf(i);
        if p_i > delta_star
            % 启动挽留：总成本 = 基础150 + 追加C + 失败概率 * 2000损失
            cost_i = (150 + C_current) + (1 - alpha_C) * 2000 * p_i;
        else
            % 不启动挽留：总成本 = 真实流失期望损失
            cost_i = 2000 * p_i;
        end
        current_total_cost = current_total_cost + cost_i;
    end
    total_costs_record(idx) = current_total_cost;
end

% --- [D. 锁定最优决策点] ---
[min_cost, best_idx] = min(total_costs_record);
best_C = C_grid(best_idx);
best_alpha = alpha_record(best_idx);
best_threshold = threshold_record(best_idx);

% --- [E. 绘制极具说服力的最优决策成本曲线图] ---
figure('Color', 'w');
plot(C_grid, total_costs_record, 'b-', 'LineWidth', 2.5);
hold on;
plot(best_C, min_cost, 'ro', 'MarkerSize', 10, 'MarkerFaceColor', 'r');

xlabel('追加营销控制成本 C (元)', 'FontSize', 11);
ylabel('全网运营期望总损失 Cost(C) (元)', 'FontSize', 11);
title('全网期望综合总损失随追加营销成本的变动与最优化寻优', 'FontSize', 12, 'FontWeight', 'bold');
legend({'期望总成本曲线', ['最优控制点 C^* = ', num2str(best_C), '元']}, 'Location', 'NorthEast');
grid on;
hold off;

% 自动导出高清高质量论文用图
saveas(gcf, 'Optimal_Control_Marketing_Cost.png');

%% --- [F. 终端大捷报喜打印] ---
fprintf('\n==================== 优化模型求解结果 ====================\n');
fprintf('🎯 最优追加营销成本 C^*    : %.2f 元\n', best_C);
fprintf('✨ 此时挽留综合成功率 \\alpha(C^*) : %.2f%%\n', best_alpha * 100);
fprintf('📍 此时自适应动态流失阈值 \\delta^* : %.4f\n', best_threshold);
fprintf('💰 全网优化后期望最低总损失   : %.2f 元\n', min_cost);
fprintf('==========================================================\n');
