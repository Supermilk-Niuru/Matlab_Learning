function [headers, rawData, encoding] = read_raw_data(filePath)
% READ_RAW_DATA 任务1：读取原始 CSV 数据
%   自动兼容 GBK / UTF-8 编码，保留中文字段名称。
%
%   输入：
%     filePath —— B.csv 的完整路径
%   输出：
%     headers  —— 1×N 元胞数组，中文字段名
%     rawData  —— M×N 元胞数组，原始字符串数据（不做任何数值处理）
%     encoding —— 检测到的文件编码（'GBK' / 'UTF-8' / 'system'）

% ---------- 1) 按字节读取原始文件 ----------
% 使用 ISO-8859-1 逐字节映射方式读取，避免 MATLAB 按默认编码
% 预先解码导致中文乱码，编码判断留到下一步统一处理。
fid = fopen(filePath, 'r', 'n', 'ISO-8859-1');
if fid == -1
    error('[read_raw_data] 无法打开文件：%s', filePath);
end
rawBytes = fread(fid, '*uint8')';
fclose(fid);

% ---------- 2) 编码检测与解码 ----------
% 原始文件为 GBK 编码；同时兼容 UTF-8，保证跨平台可运行。
text      = decode_bytes(rawBytes);
encoding  = text.encodeName;

% ---------- 3) 按行 / 按逗号拆分 ----------
% 数据中不存在引号包裹字段，直接按逗号拆分即可；
% regexp 的 'split' 模式会保留空字段（如缺失的总费用）。
allLines = regexp(text.str, '[\r\n]+', 'split');
allLines = allLines(~cellfun('isempty', allLines));

nLines = numel(allLines);
nCols  = numel(regexp(allLines{1}, ',', 'split'));

headers = cell(1, nCols);
rawData = cell(nLines - 1, nCols);

for i = 1:nLines
    parts = regexp(allLines{i}, ',', 'split');
    if numel(parts) ~= nCols
        error(['[read_raw_data] 第 %d 行列数（%d）与表头（%d）不一致，' ...
               '请检查原始数据格式。'], i, numel(parts), nCols);
    end
    if i == 1
        headers = parts;
    else
        rawData(i - 1, :) = parts;
    end
end

% ---------- 4) 输出数据规模与字段列表 ----------
fprintf('-------- 任务1：读取数据 --------\n');
fprintf('原始数据行数：%d\n', size(rawData, 1));
fprintf('原始数据列数：%d\n', numel(headers));
fprintf('检测到文件编码：%s\n', encoding);
fprintf('字段名称：\n');
for i = 1:numel(headers)
    fprintf('  %2d. %s\n', i, headers{i});
end

% ---------- 5) 变量类型检查（数值型 / 类别型） ----------
% 判断依据：该列所有非空取值是否都能被解析为数值。
fprintf('\n变量类型检查：\n');
typeName = {'类别型', '数值型'};
for i = 1:numel(headers)
    col     = rawData(:, i);
    nonEmpty = col(~cellfun(@(x) isempty(strtrim(x)), col));
    isNumeric = ~isempty(nonEmpty) && ...
                all(cellfun(@(x) ~isnan(str2double(x)), nonEmpty));
    fprintf('  %s : %s\n', headers{i}, typeName{isNumeric + 1});
end
fprintf('\n');

end

% ========================================================================
% 局部函数：字节解码与编码检测
% ========================================================================
function out = decode_bytes(rawBytes)
% 依次尝试 GBK、UTF-8 解码，并以表头关键字 "客户编码" 验证解码是否成功。

    % 尝试 GBK（本数据实际为 GBK 编码）
    try
        s = native2unicode(rawBytes, 'GBK');
        if contains(s, '客户编码')
            out.str = s;
            out.encodeName = 'GBK';
            return;
        end
    catch
        % 当前 MATLAB 不支持 GBK 时继续尝试 UTF-8
    end

    % 尝试 UTF-8
    try
        s = native2unicode(rawBytes, 'UTF-8');
        if contains(s, '客户编码')
            out.str = s;
            out.encodeName = 'UTF-8';
            return;
        end
    catch
        % 继续回退
    end

    % 回退：使用系统默认编码，并给出警告
    warning(['[read_raw_data] 未能识别文件编码，已按系统默认编码读取，' ...
             '字段名可能出现乱码，请检查 B.csv 的编码格式。']);
    out.str = native2unicode(rawBytes);
    out.encodeName = 'system';

end
