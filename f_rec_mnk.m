function [x_filtrated,wsp] = f_rec_mnk(x,dt,T)
    %funkcja realizująca filtracje rekurencyjne mnk
    persistent i theta eps phi
    if isempty(i)
        i = 1; 
        theta=[0; dt; dt^2];
        eps=[0; 0; 0];
        phi=[1; 1; 1];
    end
    i = i + 1;
    
    alfa=1-(dt/T);
    %alfa = 0.99
    K=[1-alfa; (1-alfa)/dt; (1-alfa)/dt^2;];
    
    eps(1,i)=x-phi(1)*theta(1,i-1);
    theta(1,i)=theta(1,i-1)+K(1)*eps(1,i);
    wsp(1)=theta(1,i);
    

    eps(2,i)=x-theta(1,i)-phi(2)*theta(2,i-1);
    theta(2,i)=theta(2,i-1)+K(2)*eps(2,i);
    wsp(2) = theta(2,i);

    eps(3,i)=x - theta(2,i)*dt - theta(1,i) - phi(3) *theta(3,i-1);
    theta(3,i)=theta(3,i-1)+K(3)*eps(3,i);
    wsp(3) = theta(3,i);

    x_filtrated = theta(1,i) + theta(2,i)*dt + theta(3,i)*dt^2;
    wsp=wsp';
end

