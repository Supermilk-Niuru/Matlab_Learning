function draw_box_violin(saveDir, figName, yData, groupVec, varName, yLabel)
% DRAW_BOX_VIOLIN 绘制箱线图与小提琴图（按流失状态分组），保存 300 dpi PNG
%   箱线图与小提琴图均为自实现绘制，不依赖统计工具箱。
%
%   输入：
%     saveDir  —— 图片保存目录
%     figName  —— 文件名前缀（不含扩展名），生成 <figName>_boxplot.png 与 <figName>_violin.png
%     yData    —— 连续变量数值向量（允许含 NaN，统计时忽略）
%     groupVec —— 分组向量（0 = 未流失，1 = 流失）
%     varName  —— 变量名（用于图标题）
%     yLabel   —— 纵轴标签

groups    = [0 1];
grpLabels = {'未流失', '流失'};
colors    = {[0.35 0.70 0.40], [0.85 0.35 0.35]};

% ================= 图1：箱线图 =================
f1 = figure('Visible', 'off');
hold on;
for i = 1:2
    y = yData(groupVec == groups(i));
    y = y(~isnan(y));                    % 忽略 NaN（如总费用的缺失值）
    draw_box_chart(i, y, colors{i});
end
set(gca, 'XTick', 1:2, 'XTickLabel', grpLabels);
xlabel('是否流失');
ylabel(yLabel);
title([varName, ' 箱线图']);
grid on;
print(f1, fullfile(saveDir, [figName, '_boxplot.png']), '-dpng', '-r300');
close(f1);

% ================= 图2：小提琴图 =================
f2 = figure('Visible', 'off');
hold on;
for i = 1:2
    y = yData(groupVec == groups(i));
    y = y(~isnan(y));
    draw_violin_chart(i, y, colors{i});
end
set(gca, 'XTick', 1:2, 'XTickLabel', grpLabels);
xlabel('是否流失');
ylabel(yLabel);
title([varName, ' 小提琴图']);
grid on;
print(f2, fullfile(saveDir, [figName, '_violin.png']), '-dpng', '-r300');
close(f2);

fprintf('  已保存图片：%s_boxplot.png / %s_violin.png\n', ...
        fullfile(saveDir, figName), figName);

end

% ========================================================================
% 局部函数1：手绘箱线图（Tukey 箱须）
% ========================================================================
function draw_box_chart(gpos, y, faceColor)
% 在横轴位置 gpos 处绘制一个箱线图
%   箱体：Q1~Q3；中位线；须线：1.5×IQR 内最远点；超出者为离群点

    if isempty(y)
        return;
    end

    q    = quantile(y, [0.25 0.50 0.75]);
    iqr  = q(3) - q(1);
    loF  = q(1) - 1.5 * iqr;               % 下栅栏
    hiF  = q(3) + 1.5 * iqr;               % 上栅栏

    in   = y(y >= loF & y <= hiF);
    loW  = min(in);
    hiW  = max(in);
    out  = y(y < loF | y > hiF);

    w = 0.30;                              % 箱体半宽

    % 箱体
    rectangle('Position', [gpos - w, q(1), 2 * w, q(3) - q(1)], ...
              'EdgeColor', 'k', 'FaceColor', faceColor);
    % 中位线
    line([gpos - w, gpos + w], [q(2), q(2)], 'Color', 'k', 'LineWidth', 1.5);
    % 上下须
    line([gpos, gpos], [q(3), hiW], 'Color', 'k');
    line([gpos, gpos], [q(1), loW], 'Color', 'k');
    line([gpos - w/2, gpos + w/2], [hiW, hiW], 'Color', 'k');
    line([gpos - w/2, gpos + w/2], [loW, loW], 'Color', 'k');
    % 离群点
    if ~isempty(out)
        plot(gpos * ones(size(out)), out, 'k.', 'MarkerSize', 5);
    end

end

% ========================================================================
% 局部函数2：手绘小提琴图（高斯核密度估计）
% ========================================================================
function draw_violin_chart(gpos, y, faceColor)
% 以高斯核密度估计为基础绘制小提琴形状，并叠加中位线

    if isempty(y)
        return;
    end

    [f, xi] = kde_1d(y, 150);

    w = 0.40;                              % 小提琴最大半宽
    f = f / max(f) * w;

    % 左右对称的闭合多边形（底部→左缘→顶部→右缘→底部）
    px = [gpos - f;        gpos + f(end:-1:1)];
    py = [xi;              xi(end:-1:1)];
    patch(px, py, faceColor, 'FaceAlpha', 0.5, 'EdgeColor', 'k', 'LineWidth', 0.5);

    % 中位数短线
    md = median(y);
    line([gpos - 0.06, gpos + 0.06], [md, md], 'Color', 'k', 'LineWidth', 1.5);

end

% ========================================================================
% 局部函数3：一维高斯核密度估计（不依赖统计工具箱）
% ========================================================================
function [f, xi] = kde_1d(x, nPts)
% 高斯核 + Scott 带宽规则，对 NaN 由调用方先过滤
    x = x(:);
    n = numel(x);

    if n < 2
        xi = x;
        f  = 1;
        return;
    end

    bw = 1.06 * std(x) * n^(-1/5);         % Scott 带宽
    if ~isfinite(bw) || bw <= 0
        bw = max(eps, 0.1 * max(abs(x)));
    end

    xi = linspace(min(x), max(x), nPts)';
    f  = zeros(nPts, 1);
    const = 1 / (sqrt(2 * pi) * bw * n);
    for i = 1:nPts
        f(i) = const * sum(exp(-0.5 * ((xi(i) - x) / bw) .^ 2));
    end

end
