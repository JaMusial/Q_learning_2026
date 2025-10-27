function [stany, akcje, no_of_states, no_of_actions, state_doc, action_doc] =...
    f_generuj_stany_v2(precision, oczekiwana_ilosc_stanow,gorne_ograniczenie, Te, Kp, dt)
format long
gorne_ograniczenie=gorne_ograniczenie/(Kp*dt);
ilosc_akcji=floor(oczekiwana_ilosc_stanow/2);
tttest = precision*2/Te;
akcje=[0 precision*2/Te];

% p=log(Te) / log(model_kompensatora(1)) - model_kompensatora(2);

if Te<1 && 0
    a =   -0.007316;
    b =     -0.5023;
    c =    -0.05268;
else
    a =    -0.01264;
    b =     -0.3163;
    c =    -0.04744;
end
p=a*Te^b+c;
p=0;
q=(gorne_ograniczenie/(precision*2/Te))^(1/(ilosc_akcji-1))+p;

for i=3:ilosc_akcji
    akcje(end+1)=(precision*2/Te)*q^(i-1);
%     akcje(end+1)=(akcje(end)-akcje(end-1))*q+akcje(end);
end

for i=1:length(akcje)-1
    stany(i)=(akcje(i+1)+akcje(i))/2;
end

stany=[flip(stany), -stany];
akcje=[flip(akcje), -akcje(2:end)];

no_of_states=length(stany);
no_of_actions=length(akcje);
state_doc=floor(no_of_states/2)+1;
action_doc=floor(no_of_actions/2)+1;



%model_kompensatora = [3.00e+15 0.07733];
%p=0.006730797912770 niezależne od parametrów