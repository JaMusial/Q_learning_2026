function stan = f_find_state(e, table)
% f_find_state  — drop-in replacement preserving original loop semantics,
% vectorized where possible but matching original ascending/descending rules.
%
% Returns integer stan in 1:(numel(table)+1).

if 0
    n = numel(table);
    if n == 0
        stan = 1;
        return
    end

    % Default
    stan = 1;

    % ORIGINAL branching rule: "if table(1) < 0 then ascending branch"
    if table(1) < 0
        % Ascending: original semantics ->
        %   if e > table(end) -> stan = n+1
        %   else stan = first i such that e <= table(i)
        if e > table(end)
            stan = n + 1;
            return
        end
        idx = find(e <= table, 1, 'first');
        if isempty(idx)
            stan = n + 1;
        else
            stan = idx;
        end

    else
        % Descending: original semantics ->
        %   if e < table(end) -> stan = n+1
        %   elseif e > table(1) -> stan = 1
        %   else find the first i where e > table(i) and set stan = i
        if e < table(end)
            stan = n + 1;
            return
        end
        if e > table(1)
            stan = 1;
            return
        end

        % find first index i such that e > table(i)
        idx = find(e > table, 1, 'first');
        if isempty(idx)
            % e <= table(i) for all i -> stan = n+1 (matches original loop behavior)
            stan = n + 1;
        else
            % original loop would have ended with stan = (idx-1)+1 = idx
            stan = idx;
        end
    end

    % safety clamp
    stan = max(1, min(n + 1, floor(stan)));

else
    %Funkcja znajduje aktualny numer stany w ktorym znajduje sie regulator na
    %podstawie wartosci uchybu

    stan=1;

    %wartoci w tabli ida rosnaco
    if table(1)<0

        if e>table(end)
            stan=length(table)+1;
        else
            for i=1:length(table)
                if e<=table(i)
                    stan=i;
                    break;
                end
            end
        end
        %wartosci w tabli ida malejaco
    else

        if e<table(end)
            stan=length(table)+1;
        elseif e > table(1)
            stan=1;
        else
            for i=1:length(table)

                if e<=table(i)
                    stan=i+1;
                else
                    break;
                end
            end
        end

    end


end
end
