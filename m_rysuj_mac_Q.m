%% m_rysuj_mac_Q - Visualize Q-matrix policy as heatmap
%
% Generates visualization of learned Q-matrix policy showing the best action
% for each state. Can create animated GIF to show learning progression.
%
% Features:
%   - Dynamic sizing based on actual Q-matrix dimensions
%   - Theme-neutral visualization
%   - Optional GIF animation of learning process
%   - Proper matrix initialization (no garbage values)
%
% Global variables used:
%   gif_on              - Enable/disable GIF generation
%   flaga_rysuj_gif     - Flag for first GIF frame
%   Q_2d                - Q-learning matrix [states × actions]
%   epoka               - Current epoch number
%
% Author: Jakub Musiał
% Modified: 2025-11-19

if gif_on == 1
    % GIF animation mode enabled
    visualize_q_matrix_gif();
end

%% ========================================================================
%  HELPER FUNCTIONS
%  ========================================================================

function visualize_q_matrix_gif()
    % Visualize Q-matrix and add frame to GIF animation

    global gif_on flaga_rysuj_gif Q_2d epoka

    % Get actual Q-matrix dimensions (dynamic, not hard-coded)
    [n_states, n_actions] = size(Q_2d);

    % Find best action for each state
    [~, best_action_idx] = max(Q_2d, [], 2);  % max along actions dimension

    % Create binary policy matrix (1 where best action, 0 elsewhere)
    policy_matrix = zeros(n_states, n_actions);
    for i = 1:n_states
        policy_matrix(i, best_action_idx(i)) = 1;
    end

    % Flip vertically for better visualization (state 1 at top)
    policy_matrix = flipud(policy_matrix);

    % Create or update figure
    fig = figure(456);
    set(fig, 'Position', [100, 100, 800, 700]);

    % Display policy matrix as heatmap
    [r, c] = size(policy_matrix);
    imagesc((1:c)+0.5, (1:r)+0.5, policy_matrix);
    colormap(gray);
    axis equal;

    % Configure axes
    set(gca, 'XTick', 1:(c+1), 'YTick', 1:(r+1), ...
        'XLim', [1 c+1], 'YLim', [1 r+1], ...
        'GridLineStyle', '-', 'XGrid', 'on', 'YGrid', 'on');

    % Set alpha for transparency
    alpha scaled;

    % Create y-axis labels (flipped: n_states at top, 1 at bottom)
    if n_states <= 100
        % Show all labels if reasonable number of states
        ytick_labels = cellstr(num2str((n_states:-1:1)'));
        set(gca, 'YTickLabel', ytick_labels);
    else
        % Show subset of labels for large state spaces
        tick_positions = round(linspace(1, r, min(20, r)));
        set(gca, 'YTick', tick_positions);
        ytick_labels = cellstr(num2str((n_states:-1:1)'));
        set(gca, 'YTickLabel', ytick_labels(tick_positions));
    end

    % Labels and title
    xlabel('Actions');
    ylabel('States');
    title(sprintf('Q-Matrix Policy - Epoch %d', epoka));

    % Add colorbar for reference
    cb = colorbar;
    cb.Label.String = 'Best Action';
    cb.Ticks = [0 1];
    cb.TickLabels = {'Other', 'Best'};

    % GIF handling
    if flaga_rysuj_gif == 1
        % First frame - create new GIF
        flaga_rysuj_gif = 0;
        gif('q_matrix_evolution.gif');
        figure(456);
        gif;
    else
        % Subsequent frames - append to existing GIF
        figure(456);
        gif;
    end
end

end
