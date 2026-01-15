function f_export_debug_json(data_struct, filename, debug_logging_enabled)
%% f_export_debug_json - Export debug logging structure to JSON file
%
% PURPOSE:
%   Automatically exports debug logging data to JSON file when debug logging is enabled.
%   Deletes old file first to prevent stale data accumulation.
%
% INPUTS:
%   data_struct            - Structure to export (e.g., logi, logi_before_learning)
%   filename              - Output filename (e.g., 'logi_debug.json')
%   debug_logging_enabled - Flag from config.m (1=export, 0=skip)
%
% OUTPUTS:
%   JSON file written to current directory (if debug_logging_enabled)
%
% NOTES:
%   - Only exports if debug_logging_enabled == 1
%   - Deletes existing file first (prevents confusion with old data)
%   - Uses pretty-print JSON format for readability
%   - Reports file size and location to console
%
% EXAMPLE:
%   f_export_debug_json(logi_before_learning, 'logi_before_learning.json', debug_logging)
%
%% =====================================================================

% Early return if debug logging disabled
if ~debug_logging_enabled
    return;
end

% Check if data structure exists and is not empty
if ~exist('data_struct', 'var') || isempty(data_struct)
    fprintf('DEBUG: Skipping JSON export - data structure is empty\n');
    return;
end

% Delete old file if it exists
if exist(filename, 'file')
    delete(filename);
    fprintf('DEBUG: Deleted old file: %s\n', filename);
end

% Export to JSON with pretty-print format
try
    % Convert structure to JSON string
    json_str = jsonencode(data_struct);

    % Write to file
    fid = fopen(filename, 'w');
    if fid == -1
        error('Failed to open file: %s', filename);
    end
    fprintf(fid, '%s', json_str);
    fclose(fid);

    % Report success with file info
    file_info = dir(filename);
    file_size_mb = file_info.bytes / (1024 * 1024);
    fprintf('DEBUG: Exported debug data to %s (%.2f MB)\n', filename, file_size_mb);

catch ME
    fprintf('WARNING: Failed to export debug JSON: %s\n', ME.message);
end

end
