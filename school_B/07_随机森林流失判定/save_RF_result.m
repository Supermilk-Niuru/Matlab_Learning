function save_RF_result(keepIdxTest, Yte, pTest, predClass, vars, importance, outDir)
% SAVE_RF_RESULT 保存随机森林结果：测试集预测结果 / 特征重要性
%
%   输入：
%     keepIdxTest —— 测试样本客户编号（Nte×1）
%     Yte         —— 测试集真实流失状态
%     pTest       —— 测试集预测流失概率 P（多棵树的平均投票比例）
%     predClass   —— 测试集预测类别（1=流失，0=未流失）
%     vars        —— 16 个输入变量名称（16×1 元胞）
%     importance  —— 特征重要性（P×1，OOB 置换重要性 或 节点分裂贡献累计）
%     outDir      —— 输出文件夹
%
%   输出文件：
%     RF_prediction_result.xlsx   客户编号 | 真实流失状态 | 预测概率P | 预测类别
%     RF_feature_importance.xlsx  排名 | 变量名称 | 重要性 | 重要性(%)
%     feature_importance.png      特征重要性水平条形图

%% ---------- 1) 测试集预测结果 RF_prediction_result.xlsx ----------
predTbl = table(keepIdxTest, Yte, pTest, predClass, ...
    'VariableNames', {'客户编号', '真实流失状态', '预测概率P', '预测类别'});
predFile = fullfile(outDir, 'RF_prediction_result.xlsx');
if isfile(predFile); delete(predFile); end
writetable(predTbl, predFile, 'Sheet', '预测结果', 'WriteMode', 'overwritesheet');

%% ---------- 2) 特征重要性排序表 RF_feature_importance.xlsx ----------
P = numel(vars);
[impSorted, order] = sort(importance, 'descend');     % 降序排序
varSorted = vars(order);
rank      = (1:P)';
impPct    = impSorted / sum(impSorted) * 100;         % 重要性占比(%)
impTbl = table(rank, varSorted, impSorted, impPct, ...
    'VariableNames', {'排名', '变量名称', '重要性', '重要性(%)'});
impFile = fullfile(outDir, 'RF_feature_importance.xlsx');
if isfile(impFile); delete(impFile); end
writetable(impTbl, impFile, 'Sheet', '特征重要性', 'WriteMode', 'overwritesheet');

fprintf('\n===== 随机森林特征重要性排序（由高到低） =====\n');
for i = 1:P
    fprintf('  %2d. %-12s  %.4f  (%.2f%%)\n', ...
        i, vars{order(i)}, importance(order(i)), impPct(i));
end

%% ---------- 3) 特征重要性水平条形图 feature_importance.png ----------
figure('Color', 'w', 'Position', [120 120 760 560]);
barh(impSorted);
set(gca, 'YDir', 'reverse');                          % 最重要的特征显示在最上方
yticks(1:P);
yticklabels(varSorted);
xlabel('特征重要性（节点分裂贡献累计 / OOB 置换重要性）');
title('随机森林特征重要性');
grid on; box on;
pngFile = fullfile(outDir, 'feature_importance.png');
saveas(gcf, pngFile);
close(gcf);

fprintf('\n已保存结果：\n  %s\n  %s\n  %s\n', predFile, impFile, pngFile);

end
