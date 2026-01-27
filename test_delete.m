clc
x=[20 0];
N=5;
for i=3:N
    x(end+1)=(x(i-2)+x(i-1))/2;
end

x
sum(x)