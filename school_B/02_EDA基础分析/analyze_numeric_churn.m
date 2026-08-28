function numericTbl = analyze_numeric_churn(data, numericDir)
% ANALYZE_NUMERIC_CHURN 步骤三：连续变量流失差异分析
%   对连续变量（在网时长（月）、月费用、总费用）按是否流失分组，
%   计算均值、中位数、标准差、最大值、最小值，并绘制箱线图与小提琴图。
%
%   缺失值处理：统计时忽略 NaN（总费用存在 11 个 NaN），不修改原数据。
%
%   输入：
%     data       —— B_processed 数据表
%     numericDir —— 连续因素分析图片保存文件夹
%   输出：
%     numericTbl —— 变量 | 状态 | 均值 | 中位数 | 标准差 | 最大值 | 最小值 统计表

numVars    = {'在网时长（月）', '月费用', '总费用'};
groups     = [0 1];
grpLabels  = {'未流失', '流失'};
churnCol   = data.('是否流失');

fprintf('-------- 步骤三：连续变量流失差异分析 --------\n');

nRows = numel(numVars) * 2;
varCell = cell(nRows, 1);
stCell  = cell(nRows, 1);
valMat  = zeros(nRows, 5);     % 均值 中位数 标准差 最大值 最小值

r = 0;
for k = 1:numel(numVars)
    vname = numVars{k};

    if ~ismember(vname, data.Properties.VariableNames)
        error('[analyze_numeric_churn] 数据中不存在字段 "%s"。', vname);
    end
    col = data.(vname);

    fprintf('  %s：\n', vname);
    for g = 1:2
        y = col(churnCol == groups(g));
        y = y(~isnan(y));                    % 统计时忽略 NaN

        mu = mean(y); md = median(y); sd = std(y);
        mx = max(y);  mn = min(y);

        r = r + 1;
        varCell{r} = vname;
        stCell{r}  = grpLabels{g};
        valMat(r, :) = [mu, md, sd, mx, mn];

        fprintf('    %-4s：均值 %8.2f，中位数 %8.2f，标准差 %8.2f，最大值 %8.2f，最小值 %8.2f（样本数 %d）\n', ...
                grpLabels{g}, mu, md, sd, mx, mn, numel(y));
    end

    % 箱线图 + 小提琴图
    draw_box_violin(numericDir, vname, col, churnCol, vname, vname);
end

% Excel 统计表
numericTbl = table(varCell, stCell, ...
                   valMat(:, 1), valMat(:, 2), valMat(:, 3), valMat(:, 4), valMat(:, 5), ...
                   'VariableNames', {'变量', '状态', '均值', '中位数', '标准差', '最大值', '最小值'});

fprintf('\n');

end
