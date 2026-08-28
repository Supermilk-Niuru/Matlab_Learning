function save_processed_data(outTable, encRules)
% SAVE_PROCESSED_DATA 任务6：保存处理结果
%   输出文件：
%     1. B_processed.csv  —— 预处理后的标准化数据（全部为数值变量，
%                            可直接被后续机器学习 / 数学模型程序读取）
%     2. encoding_rule.xlsx —— 所有类别变量的编码规则，方便后续模型解释
%   其中 encoding_rule.xlsx 包含以下 Sheet：
%       Readme          —— 处理说明与关键决策
%       Binary_vars     —— 二分类字段的 是/否/未开通* → 0/1 规则
%       Gender          —— 性别编码
%       Internet_service—— 互联网服务类型编码
%       Contract_type   —— 合同类型编码
%       Payment_method  —— 支付方式编码
%
%   输入：
%     outTable —— 预处理完成后的数值表（表头为中文字段名）
%     encRules —— 多分类变量编码规则结构体（由 encode_categorical_vars 返回）

fprintf('-------- 任务6：保存结果 --------\n');

% ========== 1) 保存 B_processed.csv ==========
csvFile = fullfile(pwd, 'B_processed.csv');
writetable(outTable, csvFile);
fprintf('已保存：%s\n', csvFile);
fprintf('        数据规模：%d 行 × %d 列，全部为数值变量，可直接读取建模。\n', ...
        size(outTable, 1), size(outTable, 2));

% ========== 2) 保存 encoding_rule.xlsx ==========
xlsFile = fullfile(pwd, 'encoding_rule.xlsx');

% 删除旧文件，避免残留上一次运行的 Sheet
if isfile(xlsFile)
    delete(xlsFile);
end

% ---- 2.1 Readme 说明页 ----
readmeLines = {
    '电信客户流失分析 —— 数据预处理编码规则说明'
    ['生成时间：' char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'))]
    '原始数据：B.csv'
    '输出数据：B_processed.csv（数值格式，可直接用于建模）'
    ''
    '【字段顺序】删除"客户编码"后，其余字段保持原始顺序不变。'
    ''
    '【二分类字段】是→1，否→0；出现"未开通电话服务/互联网服务"时'
    '作为独立类别编码为 2（仅代表独立类别，不代表大小关系）。'
    '完整规则见 Binary_vars 页。'
    ''
    '【特殊说明】'
    '"是否开通多条线路"出现"未开通电话服务"，'
    '"是否开通在线安全/在线备份/设备保护/技术支持/电视流媒体/电影流媒体"'
    '出现"未开通互联网服务"。本次修正将其由"视同否→0"改为独立类别编码 2，'
    '以保留 No phone service / No internet service 的业务含义。'
    '是否有电话/互联网本身仍由"是否开通电话服务"和"互联网服务类型"承载。'
    ''
    '【缺失值】"总费用"存在 11 个空值（对应在网时长=0 的新客户），'
    '保留为 NaN，未填充、未删除，留待后续建模阶段决策。'
    ''
    '【数值字段】"在网时长（月）""月费用""总费用"保持原值，'
    '未做标准化、归一化、对数转换或离散化。'
    ''
    '【编码约定】多分类编码仅为类别编号，不代表大小关系。'
    '【删除字段】"客户编码"为唯一身份标识，不参与建模，已删除。'
    };
readmeTbl = table(readmeLines(:));
readmeTbl.Properties.VariableNames = {'说明'};
writetable(readmeTbl, xlsFile, 'Sheet', 'Readme', 'WriteMode', 'overwritesheet');

% ---- 2.2 Binary_vars 二分类字段规则页 ----
binRuleTbl = make_binary_rule_table();
writetable(binRuleTbl, xlsFile, 'Sheet', 'Binary_vars', 'WriteMode', 'append');

% ---- 2.3 多分类字段规则页（每字段一个 Sheet）----
ruleNames = fieldnames(encRules);
for k = 1:numel(ruleNames)
    writetable(encRules.(ruleNames{k}), xlsFile, ...
               'Sheet', ruleNames{k}, 'WriteMode', 'append');
end

fprintf('已保存：%s\n', xlsFile);
fprintf('        Sheet：%s\n', strjoin([{'Readme', 'Binary_vars'}, ruleNames'], ', '));

end

% ========================================================================
% 局部函数：生成二分类字段编码规则表
% ========================================================================
function tbl = make_binary_rule_table()
% 生成 字段 | 原始类别 | 编码 的完整规则表，
% 仅列出各字段实际可能出现的类别（未开通* 只出现在对应的字段中）。

    fields_ = {
        '是否为老年人'; '是否有伴侣'; '是否有家属'; '是否开通电话服务';
        '是否开通多条线路'; '是否开通在线安全'; '是否开通在线备份';
        '是否开通设备保护'; '是否开通技术支持'; '是否开通电视流媒体';
        '是否开通电影流媒体'; '是否使用电子账单'; '是否流失'
        };

    % 仅这些字段会出现"未开通电话服务"/"未开通互联网服务"
    extraMap = containers.Map();
    extraMap('是否开通多条线路')  = '未开通电话服务';
    extraMap('是否开通在线安全')  = '未开通互联网服务';
    extraMap('是否开通在线备份')  = '未开通互联网服务';
    extraMap('是否开通设备保护')  = '未开通互联网服务';
    extraMap('是否开通技术支持')  = '未开通互联网服务';
    extraMap('是否开通电视流媒体') = '未开通互联网服务';
    extraMap('是否开通电影流媒体') = '未开通互联网服务';

    fn = {};   % 字段
    ca = {};   % 原始类别
    co = [];   % 编码

    for i = 1:numel(fields_)
        f = fields_{i};
        fn{end + 1, 1} = f; ca{end + 1, 1} = '是'; co(end + 1, 1) = 1; %#ok<AGROW>
        fn{end + 1, 1} = f; ca{end + 1, 1} = '否'; co(end + 1, 1) = 0; %#ok<AGROW>
        if isKey(extraMap, f)
            fn{end + 1, 1} = f; ca{end + 1, 1} = extraMap(f); co(end + 1, 1) = 2; %#ok<AGROW>
        end
    end

    tbl = table(fn, ca, co);
    tbl.Properties.VariableNames = {'字段', '原始类别', '编码'};

end
