function evaluate_model(Y, p, outDir)
% EVALUATE_MODEL 模型评价：混淆矩阵 / 评价指标 / ROC 曲线与 AUC
%   判定规则：P >= 0.5 判为流失（正类=1，流失），否则判为未流失（负类=0）。
%   混淆矩阵（以"流失"为正类）：
%       TP：实际流失、预测流失    FP：实际未流失、预测流失（误判）
%       FN：实际流失、预测未流失（漏判）  TN：实际未流失、预测未流失
%   评价指标：
%       Accuracy  = (TP+TN)/(TP+TN+FP+FN)
%       Precision = TP/(TP+FP)
%       Recall    = TP/(TP+FN)
%       F1        = 2·Precision·Recall/(Precision+Recall)
%
%   输出文件（保存在 outDir）：
%       model_evaluation.xlsx  Sheet1 混淆矩阵，Sheet2 评价指标（含 AUC）
%       ROC_curve.png          ROC 曲线图
%
%   ROC/AUC 手动实现（不依赖任何工具箱）：按预测概率降序排序，逐样本
%   累积计算真阳性率 TPR、假阳性率 FPR，梯形法则计算曲线下面积 AUC。

if nargin < 3, outDir = pwd; end

%% ---------- 1) 混淆矩阵（阈值 0.5） ----------
predClass = double(p >= 0.5);
TP = sum(predClass == 1 & Y == 1);
FP = sum(predClass == 1 & Y == 0);
FN = sum(predClass == 0 & Y == 1);
TN = sum(predClass == 0 & Y == 0);

fprintf('\n===== 混淆矩阵（阈值 P>=0.5） =====\n');
fprintf('TP = %4d    FP = %4d\n', TP, FP);
fprintf('FN = %4d    TN = %4d\n', FN, TN);

%% ---------- 2) 评价指标 ----------
n = numel(Y);
Accuracy  = (TP + TN) / (TP + TN + FP + FN);
if (TP + FP) > 0
    Precision = TP / (TP + FP);
else
    Precision = NaN;
end
if (TP + FN) > 0
    Recall = TP / (TP + FN);
else
    Recall = NaN;
end
if ~isnan(Precision) && ~isnan(Recall) && (Precision + Recall) > 0
    F1 = 2 * Precision * Recall / (Precision + Recall);
else
    F1 = NaN;
end

fprintf('\n===== 模型评价 =====\n');
fprintf('Accuracy  = %.4f\n', Accuracy);
fprintf('Precision = %.4f\n', Precision);
fprintf('Recall    = %.4f\n', Recall);
fprintf('F1-score  = %.4f\n', F1);

%% ---------- 3) ROC 曲线与 AUC（手动实现） ----------
% 按预测概率降序排序，从阈值最高（全部判负）到最低（全部判正）累积
[~, idx] = sort(p, 'descend');
ys = Y(idx);
nPos = sum(ys == 1);
nNeg = sum(ys == 0);

tp = cumsum(ys);                       % 累积真阳性
fp = cumsum(1 - ys);                   % 累积假阳性
TPR = [0; tp / nPos];                  % 起点 (0,0)，终点 (1,1)
FPR = [0; fp / nNeg];
AUC = trapz(FPR, TPR);                 % 梯形法则求曲线下面积

fprintf('AUC       = %.4f\n', AUC);

%% ---------- 4) 保存 model_evaluation.xlsx（混淆矩阵 + 指标） ----------
rowLbl = {'预测为流失'; '预测为未流失'};
confTbl = table(rowLbl, [TP; FN], [FP; TN], ...
    'VariableNames', {'预测\实际', '实际为流失', '实际为未流失'});
metricNames = {'准确率 Accuracy'; '精确率 Precision'; '召回率 Recall'; ...
               'F1-score'; 'AUC'; '样本数 N'};
metricVals  = [Accuracy; Precision; Recall; F1; AUC; n];
evalTbl = table(metricNames, metricVals, 'VariableNames', {'指标', '数值'});

evalFile = fullfile(outDir, 'model_evaluation.xlsx');
if isfile(evalFile); delete(evalFile); end
writetable(confTbl, evalFile, 'Sheet', '混淆矩阵', 'WriteMode', 'overwritesheet');
writetable(evalTbl, evalFile, 'Sheet', '评价指标', 'WriteMode', 'overwritesheet');

%% ---------- 5) 绘制并保存 ROC 曲线 ----------
figure('Color', 'w', 'Position', [120 120 720 560]);
plot(FPR, TPR, '-r', 'LineWidth', 1.6); hold on;
plot([0 1], [0 1], '--k', 'LineWidth', 1);   % 随机基准对角线
hold off;
xlabel('假阳性率 FPR（1-特异度）');
ylabel('真阳性率 TPR（灵敏度）');
title('Logistic 流失判定模型 ROC 曲线');
legend(sprintf('ROC (AUC = %.4f)', AUC), '随机基准', 'Location', 'southeast');
grid on; box on;
rocFile = fullfile(outDir, 'ROC_curve.png');
saveas(gcf, rocFile);
close(gcf);

fprintf('\n已保存评价结果：\n  %s\n  %s\n', evalFile, rocFile);

end
