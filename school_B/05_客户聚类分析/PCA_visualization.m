function PCA_visualization(X_std, idx, titleStr, pngFile)
% PCA_VISUALIZATION 用 PCA 将高维聚类结果降维到二维并绘制散点图
%   聚类输入变量维度较高（方案 A 17 维 / 方案 B 16 维），无法直接绘图，
%   故先用主成分分析（PCA）提取前两个主成分 PC1、PC2 可视化。
%
%   步骤：
%    1) 中心化（数据已 Z-score，均值≈0，此处冗余保险）；
%    2) SVD 分解 X = U·S·V'，主成分得分 scores = X·V；
%    3) 取 PC1、PC2 绘制散点图，不同 Cluster 用不同颜色；
%    4) 坐标轴标注各主成分解释的方差比例，保存为 PNG。
%
%   输入：
%     X_std   —— N×D 标准化数据矩阵
%     idx     —— N×1 聚类标签（取值 1..K）
%     titleStr—— 图标题
%     pngFile —— 输出 PNG 文件名（含路径）

Xc = X_std - mean(X_std, 1);              % 中心化
[~, S, V] = svd(Xc, 'econ');              % 奇异值分解（PCA 的核心）
scores = Xc * V;                           % N×D 主成分得分
PC1 = scores(:, 1);
PC2 = scores(:, 2);

% 各主成分解释的方差比例
varRatio = diag(S).^2 / sum(diag(S).^2);

K = max(idx);
figure('Color', 'w', 'Position', [120 120 780 580]);
colors = lines(K);
hold on;
for k = 1:K
    m = (idx == k);
    scatter(PC1(m), PC2(m), 6, colors(k, :), 'filled');
end
hold off;

legend(arrayfun(@(k) sprintf('Cluster %d', k), 1:K, 'UniformOutput', false), ...
       'Location', 'best');
xlabel(sprintf('PC1（解释方差 %.2f%%）', varRatio(1) * 100));
ylabel(sprintf('PC2（解释方差 %.2f%%）', varRatio(2) * 100));
title(titleStr);
grid on;  box on;
saveas(gcf, pngFile);
fprintf('  已保存：%s\n', pngFile);

end
