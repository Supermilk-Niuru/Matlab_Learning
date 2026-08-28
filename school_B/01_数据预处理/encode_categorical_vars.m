function [catMat, encRules] = encode_categorical_vars(headers, rawData, catFields)
% ENCODE_CATEGORICAL_VARS 任务4：多分类变量数字编码
%   建立"原始类别 → 编码"映射，并生成编码规则表（供 encoding_rule.xlsx 使用）。
%
%   映射规则：
%     性别           :  女 → 0，男 → 1
%     互联网服务类型 :  无 → 0，DSL → 1，Fiber optic → 2
%     合同类型       :  Month-to-month → 0，One year → 1，Two year → 2
%     支付方式       :  类别按字母序依次编号 1、2、3、4
%
%   注意：编码仅代表类别编号，不代表大小关系。
%
%   输入：
%     headers   —— 字段名元胞数组
%     rawData   —— 原始数据元胞数组
%     catFields —— 需要编码的多分类字段名（元胞数组）
%   输出：
%     catMat   —— M×K 数值矩阵，K 与 catFields 一一对应
%     encRules —— 结构体，每个字段一张编码规则表
%                 （字段：原始类别 | 编码），供保存 xlsx 使用

% 固定映射表：中文键 → {类别元胞, 对应编码}
fixedMaps = containers.Map();
fixedMaps('性别')         = struct('cats', {{'女', '男'}}, 'codes', [0 1]);
fixedMaps('互联网服务类型') = struct('cats', {{'无', 'DSL', 'Fiber optic'}}, 'codes', [0 1 2]);
fixedMaps('合同类型')       = struct('cats', {{'Month-to-month', 'One year', 'Two year'}}, 'codes', [0 1 2]);

% 编码规则在结构体 encRules 中的字段名（对应 xlsx 的 Sheet 名）
ruleFieldName = containers.Map();
ruleFieldName('性别')         = 'Gender';
ruleFieldName('互联网服务类型') = 'Internet_service';
ruleFieldName('合同类型')       = 'Contract_type';
ruleFieldName('支付方式')       = 'Payment_method';

M = size(rawData, 1);
K = numel(catFields);
catMat = zeros(M, K);
encRules = struct();

fprintf('-------- 任务4：多分类变量编码 --------\n');

for k = 1:K
    fname = catFields{k};
    idx = find(strcmp(headers, fname), 1);
    if isempty(idx)
        error('[encode_categorical_vars] 未找到字段 "%s"。', fname);
    end
    col = rawData(:, idx);

    if isKey(fixedMaps, fname)
        % 任务规定的固定映射
        cats  = fixedMaps(fname).cats;
        codes = fixedMaps(fname).codes;
    else
        % 其余字段（如支付方式）：按字母序对唯一类别依次编号 1、2、3……
        cats  = unique(col);
        codes = 1:numel(cats);
    end

    % 数据完整性校验：所有取值必须已包含在映射中
    unknown = unique(col(~ismember(col, cats)));
    if ~isempty(unknown)
        error('[encode_categorical_vars] 字段 "%s" 存在未在映射中的取值：%s，请检查数据。', ...
              fname, strjoin(unknown, ', '));
    end

    % 完成编码
    [~, loc] = ismember(col, cats);       % loc 为各取值在 cats 中的位置
    catMat(:, k) = codes(loc);

    % 生成编码规则表：原始类别 | 编码
    ruleTbl = table(cats(:), codes(:));
    ruleTbl.Properties.VariableNames = {'原始类别', '编码'};
    encRules.(ruleFieldName(fname)) = ruleTbl;

    % 打印映射关系
    fprintf('  %s 编码规则：\n', fname);
    for j = 1:numel(cats)
        fprintf('      %s → %d\n', cats{j}, codes(j));
    end
end

fprintf('共编码 %d 个多分类字段。\n\n', K);

end
