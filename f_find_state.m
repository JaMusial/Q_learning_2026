function stan = f_find_state(e, table)

%Funkcja znajduje aktualny numer stany w ktorym znajduje sie regulator na
%podstawie wartosci uchybu

stan=1;

%wartoci w tabli ida rosnaco
if table(1)<0
    
    if e>table(end)
        stan=length(table)+1;
    else
        for i=1:length(table)
            if e<=table(i)
                stan=i;
                break;
            end
        end
    end
%wartosci w tabli ida malejaco
else
    
    if e<table(end)
        stan=length(table)+1;
    elseif e > table(1)
        stan=1;
    else
        for i=1:length(table)

            if e<=table(i)
                stan=i+1;
            else
                break;
            end
        end
    end
    
end


end