function overallTbl = analyze_overall_churn(data, overallDir)
% ANALYZE_OVERALL_CHURN 步骤一：整体客户流失情况分析
%   统计流失/未流失客户数量、总客户数量与流失率，
%   绘制整体流失条形图与饼图，并返回 Excel 统计表。
%
%   输入：
%     data      —— B_processed 数据表（含字段 是否流失）
%     overallDir—— 整体流失分析图片保存文件夹
%   输出：
%     overallTbl —— 状态 | 数量 | 比例 统计表

% ---------- 统计 ----------
churnCol = data.('是否流失');
nTotal = numel(churnCol);
nChurn = sum(churnCol == 1);          % 流失客户数量
nNot   = sum(churnCol == 0);          % 未流失客户数量
rate   = nChurn / nTotal;             % 流失率 R = 流失人数 / 总人数

fprintf('-------- 步骤一：整体客户流失情况分析 --------\n');
fprintf('流失客户数量：%d\n', nChurn);
fprintf('未流失客户数量：%d\n', nNot);
fprintf('总客户数量：%d\n', nTotal);
fprintf('流失率：%.4f（%.2f%%）\n', rate, rate * 100);

% ---------- 图1：条形图（流失状态 vs 客户数量） ----------
draw_bar_pie(overallDir, 'churn_bar', 'bar', ...
             {'未流失', '流失'}, [nNot, nChurn], ...
             '整体客户流失情况', '流失状态', '客户数量');

% ---------- 图2：饼图（流失/未流失比例） ----------
draw_bar_pie(overallDir, 'churn_pie', 'pie', ...
             {'未流失', '流失'}, [nNot, nChurn], '客户流失比例');

% ---------- Excel 统计表 ----------
status = {'流失'; '未流失'; '总计'};
counts = [nChurn; nNot; nTotal];
ratio  = [nChurn / nTotal; nNot / nTotal; 1];
overallTbl = table(status, counts, ratio, ...
                   'VariableNames', {'状态', '数量', '比例'});

fprintf('\n');

end
