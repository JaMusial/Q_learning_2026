function [output, updated_buffer] = f_bufor(input, buffer)
% F_BUFOR - FIFO buffer implementation for dead time compensation
%
% Description:
%   Implements a First-In-First-Out (FIFO) buffer for simulating dead time
%   in control systems. The buffer shifts all elements left, discards the
%   oldest value (returns it as output), and appends the new input at the end.
%
% Syntax:
%   [output, updated_buffer] = f_bufor(input, buffer)
%
% Inputs:
%   input          - Scalar value to add to the buffer
%   buffer         - Current buffer state [1 x n] where n = ceil(T0/dt)
%
% Outputs:
%   output         - Oldest value from buffer (delayed by n*dt seconds)
%   updated_buffer - Updated buffer with new input appended [1 x n]
%
% Example:
%   % Create buffer for T0 = 2s with dt = 0.1s
%   T0 = 2;
%   dt = 0.1;
%   buffer = zeros(1, round(T0/dt));  % [0 0 0 ... 0] (20 elements)
%
%   % Add value 5 to buffer
%   [delayed_value, buffer] = f_bufor(5, buffer);
%   % delayed_value = 0 (oldest value)
%   % buffer = [0 0 0 ... 0 5] (shifted left, 5 added at end)
%
% Operation:
%   Buffer state evolution with T0/dt = 3:
%   Initial:     [0, 0, 0]
%   Add 5:       [0, 0, 5]  → output = 0
%   Add 7:       [0, 5, 7]  → output = 0
%   Add 9:       [5, 7, 9]  → output = 0
%   Add 11:      [7, 9, 11] → output = 5  (now delayed value appears)
%
% Notes:
%   - Buffer length determines dead time: T0 = length(buffer) * dt
%   - First n calls return zeros (filling phase)
%   - After filling, output = input delayed by T0 seconds
%   - Used for both control signal delay (u) and state/action buffering
%
% See also:
%   m_inicjalizacja (buffer initialization)
%   m_regulator_Q (buffer usage in dead time compensation)
%
% Author: Jakub Musiał
% Silesian University of Technology
% Department of Automatic Control and Robotics

% Input validation
if ~isscalar(input)
    error('f_bufor:InvalidInput', 'Input must be a scalar value.');
end

if ~isvector(buffer)
    error('f_bufor:InvalidBuffer', 'Buffer must be a vector.');
end

if isempty(buffer)
    error('f_bufor:EmptyBuffer', 'Buffer cannot be empty.');
end

% FIFO operation: shift left, add new value at end
output = buffer(1);                    % Return oldest value (first element)
updated_buffer = [buffer(2:end), input];  % Shift left and append input

end
