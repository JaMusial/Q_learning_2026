function [val_action, num_action] = f_best_action_in_state(table,state, nr_stanu_doc)

rozm=size(table);
[val_action,num_action]=max(table(state,:));
same_states=sum(table(state,:)==val_action);
% if same_states>1
%     random=randi([1, same_states], [1, 1]);
%     iter=0;
%     for i=1:rozm(2)
%         if table(state,i) == val_action
%             iter=iter+1;
%             if iter == random
%                 num_action=i;
%             end
%         end
%     end
% end
odleglosc_min=9999;
if same_states>1
    for i=1:rozm(2)
        if table(state,i) == val_action
            odleglosc=abs(nr_stanu_doc-i);
            if odleglosc<odleglosc_min
                num_action=i;
                odleglosc_min=odleglosc;
            end
        end
    end
end

end