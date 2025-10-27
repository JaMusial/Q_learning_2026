function [wartosc_out] = f_skalowanie(max_wart_in, min_wart_in, max_wart_out, min_wart_out, wartosc_in)

%skalowanie
wartosc_out=(max_wart_out - min_wart_out)/(max_wart_in - min_wart_in)*(wartosc_in - min_wart_in) + min_wart_out;

%przebicie zakresu
if wartosc_out > max_wart_out
    wartosc_out=max_wart_out;
elseif wartosc_out < min_wart_out
    wartosc_out=min_wart_out;
end

end
