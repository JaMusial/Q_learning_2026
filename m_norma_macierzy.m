if exist('norma_macierzy','var') == 1

    norma_macierzy(end+1)=sum(sum((abs(Q_2d-Q_2d_old))));
    norma_macierzy2(end+1)=(sum(sum((abs(Q_2d-Q_2d_old)).^2)))^(1/2);
    norma_macierzy2_roznica(end+1)=(sum(sum((abs(Q_2d)).^2)))^(1/2)-(sum(sum((abs(Q_2d_old)).^2)))^(1/2);
    norma_macierzy4(end+1)=(sum(sum((abs(Q_2d-Q_2d_old)).^4)))^(1/4);
    norma_macierzy4_roznica(end+1)=(sum(sum((abs(Q_2d)).^4)))^(1/4)-(sum(sum((abs(Q_2d_old)).^4)))^(1/4);
    norma_macierzy8(end+1)=(sum(sum((abs(Q_2d-Q_2d_old)).^8)))^(1/8);
    norma_macierzy16(end+1)=(sum(sum((abs(Q_2d-Q_2d_old)).^16)))^(1/16);
    norma_macierzy32(end+1)=(sum(sum((abs(Q_2d-Q_2d_old)).^32)))^(1/32);

    for iter_norma=1:length(okno_norma)-1
        okno_norma(iter_norma)=okno_norma(iter_norma+1);
    end
    okno_norma(end)=norma_macierzy2_roznica(end);

else

    norma_macierzy=[];
    norma_macierzy2=[];
    norma_macierzy4=[];
    norma_macierzy2_roznica=[];
    norma_macierzy4_roznica=[];
    norma_macierzy8=[];
    norma_macierzy16=[];
    norma_macierzy32=[];

    norma_macierzy(end+1)=sum(sum((abs(Q_2d-Q_2d_old))));
    norma_macierzy2(end+1)=(sum(sum((abs(Q_2d-Q_2d_old)).^2)))^(1/2);
    norma_macierzy2_roznica(end+1)=(sum(sum((abs(Q_2d)).^2)))^(1/2)-(sum(sum((abs(Q_2d_old)).^2)))^(1/2);
    norma_macierzy4(end+1)=(sum(sum((abs(Q_2d-Q_2d_old)).^4)))^(1/4);
    norma_macierzy4_roznica(end+1)=(sum(sum((abs(Q_2d)).^4)))^(1/4)-(sum(sum((abs(Q_2d_old)).^4)))^(1/4);
    norma_macierzy8(end+1)=(sum(sum((abs(Q_2d-Q_2d_old)).^8)))^(1/8);
    norma_macierzy16(end+1)=(sum(sum((abs(Q_2d-Q_2d_old)).^16)))^(1/16);
    norma_macierzy32(end+1)=(sum(sum((abs(Q_2d-Q_2d_old)).^32)))^(1/32);

end

Q_2d_old=Q_2d;