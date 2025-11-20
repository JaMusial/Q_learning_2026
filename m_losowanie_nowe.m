[Q_value,wyb_akcja]=f_best_action_in_state(Q_2d, stan, nr_akcji_doc);

if wyb_akcja_above < wyb_akcja_under
    min_losowanie = wyb_akcja_under - RD;
    max_losowanie = wyb_akcja_above + RD;
else
    min_losowanie = wyb_akcja_above - RD;
    max_losowanie = wyb_akcja_under + RD;
end

if max_losowanie > min_losowanie
wyb_akcja3=randi([min_losowanie, max_losowanie], [1, 1]);
else
wyb_akcja3=randi([max_losowanie, min_losowanie], [1, 1]);
end
if wyb_akcja3~=nr_akcji_doc && wyb_akcja3 ~= wyb_akcja &&...
    ((wyb_akcja > nr_akcji_doc && stan > nr_stanu_doc) ||...
    (wyb_akcja < nr_akcji_doc && stan < nr_stanu_doc))
    ponowne_losowanie=0;
    wyb_akcja=wyb_akcja3;
else
    ponowne_losowanie=ponowne_losowanie+1;
end