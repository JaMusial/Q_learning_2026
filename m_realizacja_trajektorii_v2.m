%bufor pełny
if length(okno_procent_realizacji) >= ilosc_probek_procent_realizacjii
    proc_realizacji=sum(okno_procent_realizacji)/ilosc_probek_procent_realizacjii;
    % okno_procent_realizacji = okno_procent_realizacji(przesuniecie_okno_procent_realizacji : end);
    okno_procent_realizacji=[];
    wek_proc_realizacji(end+1)=proc_realizacji;

    [filtr_mnk(end+1), wsp_mnk(:,end+1)]=f_rec_mnk(proc_realizacji,dt,10);
    wek_Te(end+1)=Te;
    flaga_zmiana_Te=1;
    filtr_mnk_mean=filtr_mnk_mean(2:end); filtr_mnk_mean(end+1)=filtr_mnk(end);
    a_mnk_mean=a_mnk_mean(2:end); a_mnk_mean(end+1)=wsp_mnk(1,end);
    b_mnk_mean=b_mnk_mean(2:end); b_mnk_mean(end+1)=wsp_mnk(2,end);
%bufor niepełny    
else
    if abs(e) >= abs(dopuszczalny_uchyb)
        okno_procent_realizacji(end+1)=R;
    end
end

