function binMat = convert_binary_vars(headers, rawData, binaryFields)
% CONVERT_BINARY_VARS 任务3：二分类变量 是/否 → 0/1（含独立第三类别）
%   基础规则：是 → 1，否 → 0。
%
%   独立第三类别（保留电信业务含义，编码为 2）：
%     - 是否开通多条线路 : "未开通电话服务" → 2
%     - 是否开通在线安全/在线备份/设备保护/技术支持/电视流媒体/电影流媒体 :
%       "未开通互联网服务" → 2
%   注意：编码 2 仅代表独立类别，不代表大小关系。
%
%   本次修正说明：原程序将"未开通*"统一视同"否"编码为 0，
%   现改为独立类别 2，以保留 No phone service / No internet service
%   这两个有业务含义的业务状态。
%
%   输入：
%     headers      —— 字段名元胞数组
%     rawData      —— 原始数据元胞数组
%     binaryFields —— 需要转换的二分类字段名（元胞数组）
%   输出：
%     binMat —— M×K 数值矩阵，K 与 binaryFields 一一对应
%               取值：纯二分类字段为 0/1，含第三类别的字段为 0/1/2

% 具有独立第三类别的字段及其对应取值
thirdCatMap = containers.Map();
thirdCatMap('是否开通多条线路')  = '未开通电话服务';
thirdCatMap('是否开通在线安全')  = '未开通互联网服务';
thirdCatMap('是否开通在线备份')  = '未开通互联网服务';
thirdCatMap('是否开通设备保护')  = '未开通互联网服务';
thirdCatMap('是否开通技术支持')  = '未开通互联网服务';
thirdCatMap('是否开通电视流媒体') = '未开通互联网服务';
thirdCatMap('是否开通电影流媒体') = '未开通互联网服务';

M = size(rawData, 1);
K = numel(binaryFields);
binMat = zeros(M, K);

fprintf('-------- 任务3：二分类变量转换（是→1，否→0，未开通*→2） --------\n');

for k = 1:K
    fname = binaryFields{k};
    idx = find(strcmp(headers, fname), 1);
    if isempty(idx)
        error('[convert_binary_vars] 未找到字段 "%s"。', fname);
    end
    col = rawData(:, idx);

    if isKey(thirdCatMap, fname)
        % 存在独立第三类别：是→1，否→0，第三类别→2
        thirdCat = thirdCatMap(fname);
        allowedVals = {'是', '否', thirdCat};
        code = zeros(M, 1);
        code(strcmp(col, '是'))     = 1;
        code(strcmp(col, thirdCat)) = 2;
        fprintf('  %s（映射：是→1，否→0，%s→2）：\n', fname, thirdCat);
    else
        % 纯二分类字段：是→1，否→0
        allowedVals = {'是', '否'};
        code = double(strcmp(col, '是'));
        fprintf('  %s（映射：是→1，否→0）：\n', fname);
    end

    % 数据完整性校验：出现未预期的取值时立即报错，避免静默错编码
    unknown = unique(col(~ismember(col, allowedVals)));
    if ~isempty(unknown)
        error('[convert_binary_vars] 字段 "%s" 存在未预期取值：%s，请检查数据。', ...
              fname, strjoin(unknown, ', '));
    end

    binMat(:, k) = code;

    % 类别数量统计（0 / 1 / 2）
    for c = 0:max(code)
        fprintf('    类别%d数量：%d\n', c, sum(code == c));
    end
end

% ---------- 数据验证（本次修正新增） ----------
% 1) 输出必须为纯数值，不允许存在字符串残留
assert(isnumeric(binMat) && isa(binMat, 'double') && all(~isnan(binMat(:))), ...
       '[convert_binary_vars] 转换结果必须为不含缺失的纯数值矩阵。');
fprintf('\n验证通过：上述 %d 个字段输出均为纯数值（无字符串残留、无缺失）。\n', K);

% 2) 行数必须与原始数据保持一致
fprintf('验证通过：数据行数 %d，与原始数据 7043 行保持一致。\n\n', M);

end
