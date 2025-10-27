if gif_on==1 && flaga_rysuj_gif==1

    flaga_rysuj_gif=0;

    clear cc
    [aa, bb]=max(Q_2d,[],2);
    for i=1:99
        cc(i)=i;
    end

    mat=[];
    for i=1:99
        for j=1:99
            if bb(i)==j
                mat(i,j)=1;
            end
        end
    end
    mat=flip(mat);
    figure(456)
    [r, c] = size(mat);                          % Get the matrix size
    imagesc((1:c)+0.5, (1:r)+0.5, mat);          % Plot the image
    colormap(gray);                              % Use a gray colormap
    axis equal                                   % Make axes grid sizes equal
    set(gca, 'XTick', 1:(c+1), 'YTick', 1:(r+1), ...  % Change some axes properties
        'XLim', [1 c+1], 'YLim', [1 r+1], ...
        'GridLineStyle', '-', 'XGrid', 'on', 'YGrid', 'on');
    alpha scaled
    yticklabels({100:-1:1})
    xlabel('akcje')
    ylabel('stany')
    title(epoka)


    gif('nowa_metoda.gif');
    figure(456)
    gif

elseif gif_on==1 && flaga_rysuj_gif==0

        clear cc
        [aa, bb]=max(Q_2d,[],2);
        for i=1:99
            cc(i)=i;
        end

        mat=[];
        for i=1:99
            for j=1:99
                if bb(i)==j
                    mat(i,j)=1;
                end
            end
        end
        mat=flip(mat);
        figure(456)
        [r, c] = size(mat);                          % Get the matrix size
        imagesc((1:c)+0.5, (1:r)+0.5, mat);          % Plot the image
        colormap(gray);                              % Use a gray colormap
        axis equal                                   % Make axes grid sizes equal
        set(gca, 'XTick', 1:(c+1), 'YTick', 1:(r+1), ...  % Change some axes properties
            'XLim', [1 c+1], 'YLim', [1 r+1], ...
            'GridLineStyle', '-', 'XGrid', 'on', 'YGrid', 'on');
        alpha scaled
        yticklabels({100:-1:1})
        xlabel('akcje')
        ylabel('stany')
        title(epoka)

end