function draw_bar_pie(saveDir, figName, mode, labels, values, titleStr, varargin)
% DRAW_BAR_PIE 绘制条形图或饼图，并保存为 300 dpi 的 PNG 图片
%   条形图：类别 vs 数值，条顶标注数值。
%   饼图  ：扇区内部显示百分比（保留两位小数），类别名称通过图例显示。
%
%   输入：
%     saveDir  —— 图片保存目录
%     figName  —— 文件名（不含扩展名）
%     mode     —— 'bar' 绘制条形图；'pie' 绘制饼图
%     labels   —— 类别标签（元胞数组，字符）
%     values   —— 对应数值向量
%     titleStr —— 图标题
%     varargin —— bar 模式下依次为 {xlabelStr, ylabelStr}；pie 模式可省略
%
%   输出：保存 <saveDir>/<figName>.png

if strcmp(mode, 'bar')
    % ================= 条形图 =================
    if numel(varargin) < 2
        error('[draw_bar_pie] bar 模式需要提供 xlabel 与 ylabel。');
    end
    xlabelStr = varargin{1};
    ylabelStr = varargin{2};

    f = figure('Visible', 'off');
    bar(values, 0.6, 'FaceColor', [0.25 0.55 0.85]);

    set(gca, 'XTick', 1:numel(labels), 'XTickLabel', labels);
    % 类别较多或标签较长时旋转刻度标签，避免重叠
    if numel(labels) > 4 || any(cellfun('length', labels) > 6)
        set(gca, 'XTickLabelRotation', 30);
    end

    % 条顶数值标注
    if all(values == round(values))
        fmt = '%.0f';
    else
        fmt = '%.3f';
    end
    hold on;
    for i = 1:numel(values)
        text(i, values(i), sprintf(fmt, values(i)), ...
             'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 9);
    end
    ylim([0, max(values) * 1.15]);
    xlabel(xlabelStr);
    ylabel(ylabelStr);
    title(titleStr);
    grid on;

else
    % ================= 饼图 =================
    % 要求：扇区内部显示百分比（保留两位小数），类别名称通过图例显示
    f = figure('Visible', 'off');

    % 过滤数值为 0 的类别（pie 会忽略 0 扇区，若不剔除会导致索引错位）
    keep = values > 0;
    vals = values(keep);
    lbls = labels(keep);

    % 绘制饼图（不带标签，百分比文字随后自定义）
    h = pie(vals);

    % 在扇区内部显示百分比：percentage = value / sum(value) * 100，保留两位小数
    total = sum(vals);
    for i = 1:numel(vals)
        pct = vals(i) / total * 100;
        set(h(2 * i), 'String', sprintf('%.2f%%', pct));
    end

    % 类别名称通过图例显示（显式绑定 patch，避免百分比文字混入图例）
    patchHandles = h(1:2:end);
    lg = legend(patchHandles, lbls);
    set(lg, 'Location', 'best');          % 自动避开饼图区域，减少文字重叠
    if any(cellfun('length', lbls) > 12)  % 类别名较长时缩小图例字号
        set(lg, 'FontSize', 8);
    end

    title(titleStr);
end

% 保存（300 dpi）
pngFile = fullfile(saveDir, [figName, '.png']);
print(f, pngFile, '-dpng', '-r300');
close(f);
fprintf('  已保存图片：%s\n', pngFile);

end
