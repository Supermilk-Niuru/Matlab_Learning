function catResult = analyze_categorical_churn(data, singleDir)
% ANALYZE_CATEGORICAL_CHURN 步骤二：分类变量单因素流失分析
%   对每个分类变量按类别 k 分组，统计：
%     客户数量 Nk、流失数量 Ck、流失率 Rk = Ck / Nk
%   并为每个变量绘制：
%     流失率条形图（横轴类别，纵轴流失率）与客户数量比例饼图。
%
%   输入：
%     data      —— B_processed 数据表
%     singleDir —— 单因素流失分析图片保存文件夹
%   输出：
%     catResult —— N×2 元胞数组 {Excel_Sheet名, 统计表}，供保存 Excel 使用

% ---------------- 分析变量清单（与 B_processed.csv 一致） ----------------
varList = {
    '性别'
    '是否为老年人'
    '是否有伴侣'
    '是否有家属'
    '是否开通电话服务'
    '是否开通多条线路'
    '互联网服务类型'
    '是否开通在线安全'
    '是否开通在线备份'
    '是否开通设备保护'
    '是否开通技术支持'
    '是否开通电视流媒体'
    '是否开通电影流媒体'
    '合同类型'
    '是否使用电子账单'
    '支付方式'
    };

% 各变量对应 Excel Sheet 名（<英文名>_Churn，参照示例 Contract_Churn）
sheetName = {
    'Gender_Churn'
    'SeniorCitizen_Churn'
    'Partner_Churn'
    'Dependents_Churn'
    'PhoneService_Churn'
    'MultipleLines_Churn'
    'InternetService_Churn'
    'OnlineSecurity_Churn'
    'OnlineBackup_Churn'
    'DeviceProtection_Churn'
    'TechSupport_Churn'
    'StreamingTV_Churn'
    'StreamingMovies_Churn'
    'Contract_Churn'
    'PaperlessBilling_Churn'
    'PaymentMethod_Churn'
    };

% 各变量类别标签（编码→原始类别名，与 encoding_rule.xlsx 一致）
labelsMap = containers.Map();
labelsMap('性别')            = struct('codes', [0 1],     'labels', {{'女', '男'}});
labelsMap('是否为老年人')      = struct('codes', [0 1],     'labels', {{'否', '是'}});
labelsMap('是否有伴侣')        = struct('codes', [0 1],     'labels', {{'否', '是'}});
labelsMap('是否有家属')        = struct('codes', [0 1],     'labels', {{'否', '是'}});
labelsMap('是否开通电话服务')   = struct('codes', [0 1],     'labels', {{'否', '是'}});
labelsMap('是否开通多条线路')   = struct('codes', [0 1 2],   'labels', {{'否', '是', '未开通电话服务'}});
labelsMap('互联网服务类型')     = struct('codes', [0 1 2],   'labels', {{'无', 'DSL', 'Fiber optic'}});
labelsMap('是否开通在线安全')   = struct('codes', [0 1 2],   'labels', {{'否', '是', '未开通互联网服务'}});
labelsMap('是否开通在线备份')   = struct('codes', [0 1 2],   'labels', {{'否', '是', '未开通互联网服务'}});
labelsMap('是否开通设备保护')   = struct('codes', [0 1 2],   'labels', {{'否', '是', '未开通互联网服务'}});
labelsMap('是否开通技术支持')   = struct('codes', [0 1 2],   'labels', {{'否', '是', '未开通互联网服务'}});
labelsMap('是否开通电视流媒体') = struct('codes', [0 1 2],   'labels', {{'否', '是', '未开通互联网服务'}});
labelsMap('是否开通电影流媒体') = struct('codes', [0 1 2],   'labels', {{'否', '是', '未开通互联网服务'}});
labelsMap('合同类型')          = struct('codes', [0 1 2],   'labels', {{'Month-to-month', 'One year', 'Two year'}});
labelsMap('是否使用电子账单')   = struct('codes', [0 1],     'labels', {{'否', '是'}});
labelsMap('支付方式')          = struct('codes', [1 2 3 4], 'labels', {{'Bank transfer (automatic)', 'Credit card (automatic)', 'Electronic check', 'Mailed check'}});

churnCol = data.('是否流失');
N = numel(varList);
catResult = cell(N, 2);

fprintf('-------- 步骤二：分类变量单因素流失分析 --------\n');

for i = 1:N
    vname = varList{i};

    % 字段存在性检查
    if ~ismember(vname, data.Properties.VariableNames)
        error('[analyze_categorical_churn] 数据中不存在字段 "%s"。', vname);
    end
    col = data.(vname);

    codes   = unique(col);                     % 该变量实际出现的类别编码
    nCat    = numel(codes);
    Nk = zeros(nCat, 1);   % 客户数量
    Ck = zeros(nCat, 1);   % 流失数量
    Rk = zeros(nCat, 1);   % 流失率

    for c = 1:nCat
        mask = (col == codes(c));
        Nk(c) = sum(mask);
        Ck(c) = sum(mask & (churnCol == 1));
        Rk(c) = Ck(c) / Nk(c);
    end

    % 类别标签（编码→原始类别名；未映射的编码回退为数字本身）
    meta = labelsMap(vname);
    [~, loc] = ismember(codes, meta.codes);
    catLabels = cell(nCat, 1);
    for c = 1:nCat
        if loc(c) > 0
            catLabels{c} = meta.labels{loc(c)};
        else
            catLabels{c} = num2str(codes(c));
        end
    end

    % 控制台输出
    fprintf('  %s：\n', vname);
    for c = 1:nCat
        fprintf('    类别 %-16s：客户 %d，流失 %d，流失率 %.3f\n', ...
                catLabels{c}, Nk(c), Ck(c), Rk(c));
    end

    % 图片1：流失率条形图（横轴=类别，纵轴=流失率）
    draw_bar_pie(singleDir, [vname, '_bar'], 'bar', ...
                 catLabels, Rk, [vname, '：各类别流失率'], vname, '流失率');
    % 图片2：客户数量比例饼图
    draw_bar_pie(singleDir, [vname, '_pie'], 'pie', ...
                 catLabels, Nk, [vname, '：客户数量分布']);

    % Excel 统计表
    t = table(catLabels, Nk, Ck, Rk, ...
              'VariableNames', {'类别', '客户数量', '流失数量', '流失率'});
    catResult{i, 1} = sheetName{i};
    catResult{i, 2} = t;
end

fprintf('\n');

end
