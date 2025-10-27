function [proc, wektor] = f_okno_procent_realizacji_traj(wektor, okno, procent)

for i=1:okno-1
    wektor(i)=wektor(i+1);
end
wektor(okno)=procent;
proc=mean(wektor(1:okno));

end