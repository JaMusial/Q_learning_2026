x=[1];
N=10;
wek=[];

for i=1:N
    if (x(end)-3)~=0
    x(end+1)=(nthroot(x(end),3)+2)/(x(end)-3)
    else
        disp('vlad');
        return 
    end
end

y=-50:0.01:50;
for i=-50:0.01:50
    wek(end+1)=(nthroot(-i,3)+2)/(i-3);
end

plot(y,x)