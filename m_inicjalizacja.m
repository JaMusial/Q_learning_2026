%% parametry symulacji
gif_on=0;
poj_iteracja_uczenia=0;
max_epoki=5000;
oczekiwana_ilosc_probek_stabulizacji=20;
reakcja_na_T0 = 0;
%4000
maksymalna_ilosc_iteracji_uczenia=4000;
uczenie_obciazeniowe=1;
zakres_losowania_zakl_obc=0.5;
uczenie_zmiana_SP=0;
zakres_losowania_zmian_SP=1;
ilosc_probek_sterowanie_reczne=5;
dist_on=0;

probkowanie_norma_macierzy=100;
czas_eksp_wer=600;   %podzieln na 3

max_powtorzen_losowania_RD=10;

%% parametry regulatora PI

typ='PI  ';
dt_PID=0.1;
Kp=1;
Ti=20;
Td=0;
Tn=0;


%% parametry regulatora Q

%inicjalizacja
dt=0.1;
ograniczenie_sterowania_dol=0;
ograniczenie_sterowania_gora=100;
dokladnosc_gen_stanu=0.5;
oczekiwana_ilosc_stanow=100;
f_rzutujaca_on=0;

%działanie
Te_bazowe=2;
nagroda=1;
alfa=0.1;
gamma=0.99;
eps_ini=0.3;
RD=5;
max_powtorzen_losowania=10;
kQ=Kp;

%procent realizacji trajektorii
ilosc_probek_procent_realizacjii = 50/dt;
przesuniecie_okno_procent_realizacji = ilosc_probek_procent_realizacjii/4;
rozmiar_okna_sredniej_realizacji=5;

%% parametry eksperyment testowy

%% parametry obiektu
% nr_modelu=1;
% 1 - inercja I rzedu
% 2 - inercja I rzedu z opoznieniem
% 3 - inercja II rzedu
% 4 - inercja II rzedu z opoznieniem
% 5 - inercja III rzedu
% 6 - ipneumatyczna
% 7 - oscylacyjny II rzedu testowany dla T=[5 2 1]

SP_ini=50;
k=1;
T0=0;
% k=0.7925;  %zapytaj jacka
dodatkowe_probki_reka=5;

% T=[5 2]; nr_modelu=3; Ks=tf(1,[5 1])*tf(1,[2 1]);
 % T=[4 4]; Ks=tf(1,[4 1])*tf(1,[4 1]);  nr_modelu=3;
% T=[5 0.5]; nr_modelu=3;
% T=[6]; nr_modelu=1;
% T=[6]; T0=2.5; nr_modelu=2;
% T=[5 2 1]; nr_modelu=7;   %oscylacyjny
% T=[4 4 4]; nr_modelu=5; Ks=tf(1,[T(1) 1])*tf(1,[T(2) 1])*tf(1,[T(3) 1]);  %inercja 3 rzedu
% T=[2 2 2]; nr_modelu = 6; %pneumatyczna
T=[2.34 1.55 9.38]; nr_modelu=8; Ks=tf(0.994,[T(1) 1])*tf(0.968,[T(2) 1])*tf(0.4,[T(3) 1]); %k=0.994*0.968*0.4; % %inercja 3 rzedu pneumatyczny

if T0~=0
    bufor_T0=zeros(1,round(T0/dt));
    bufor_T0_PID=zeros(1,round(T0/dt));
    bufor_state=zeros(1,round(T0/dt));
    bufor_wyb_akcja=zeros(1,round(T0/dt));
    bufor_R=zeros(1,round(T0/dt));
    bufor_uczenie=zeros(1,round(T0/dt));
    bufor_old_state=zeros(1,round(T0/dt));
end

%% skalowanie
proc_max_e=100;
proc_min_e=-100;
proc_max_y=100;
proc_min_y=0;
proc_max_u=100;
proc_min_u=0;

wart_max_e=1;
wart_min_e=-1;
wart_max_y=1;
wart_min_y=0;
wart_max_u=2;
wart_min_u=0;

%% zmienne pomocnicze
pozwolenie_na_uczenia=1;
flaga_rysuj_gif=1;
epoka=1;
z=0;
dopuszczalny_uchyb=f_skalowanie(proc_max_e,proc_min_e,wart_max_e,wart_min_e,dokladnosc_gen_stanu);
max_macierzy_Q=[1];
e=0;
y=0;
delta_y=0;
u=0;
e_PID=0;
y_PID=0;
u_PID=0;
zapis_logi_PID=0;
reset_logi=0;
maxS=0;
Q_update=0;
iter=1;
stan_ustalony_probka=0;
pierwszy_wykres_weryfikacyjny=0;
licz_wskazniki=0;
flaga_zmiana_Te=1;
okno_norma=[100 100 100 100];
koszt_sterowania=0;
koszt_sterowania_wek=[0];
koszt_sterowania_flaga=0;
eks_wer=0;
proc_realizacji_traj=[0];
realizacja_traj_epoka=[];
wek_okno_realizacji=zeros(1,100);
proc_realizacji_w_oknie=0;
war_wek=[];
war_wek_u=[];
war_wek_delta_u=[];
war_okno=[];
war_okno_u=[];
war_okno_delta_u=[];
war_okno_iterator=0;
probkowanie_var_iter=0;
proc_realizacji_w_oknie_wek=[];
pole_wek=[];
pole=0;
test_wek=[];
t_pos=0;
t_neg=0;
licz_pole=0;
idle_index_wek=[];
visioli_index_wek=[];
area_index_wek=[];
pierwsze_zakl=0;
wek_Te=[];
okno_procent_realizacji=[];
wek_proc_realizacji=[];
srednia_okno_proc_realizacji=[];
filtr_mnk=[];
wsp_mnk=[];
filtr_mnk_mean=[0 0 0];
a_mnk_mean=[0 0 0 0 0 0 0 0];
b_mnk_mean=[100 100 100 100 100 100 100 100];
%% zmienne diagnostyczne
inf_zakonczono_epoke_max_iter=0;
inf_zakonczono_epoke_stabil=0;
czas_uczenia_calkowity=0;
inf_zakonczono_epoke_stabil_old=0;
inf_zakonczono_epoke_max_iter_old=0;
%% bufory