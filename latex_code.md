LATEX TABLE CODE
========================================================

\begin{table}[htbp]
\centering
\caption{Performance metrics comparison for different dead time compensation strategies}
\label{tab:dead_time_compensation}
\resizebox{\textwidth}{!}{%
\begin{tabular}{ll|ccc|ccc|ccc}
\hline
 &  & \multicolumn{3}{c|}{T0=0.5} & \multicolumn{3}{c|}{T0=2} & \multicolumn{3}{c}{T0=4} \\
Controller & Scenario & Metric & Full & Over & Under & Full & Over & Under & Full & Over & Under \\
\hline
\multirow{6}{*}{PI} & SP change & IAE & 634.875 & --- & --- & 635.206 & --- & --- & 635.600 & --- & --- \\
 &  &  & $\Delta U_{max}$ & 30.150 & --- & --- & 30.150 & --- & --- & 30.150 & --- & --- \\
 &  &  & Max overshoot & 0.000 & --- & --- & 0.000 & --- & --- & 0.000 & --- & --- \\
 &  & d=-0.3 & IAE & 301.139 & --- & --- & 300.994 & --- & --- & 300.820 & --- & --- \\
 &  &  & $\Delta U_{max}$ & 0.299 & --- & --- & 0.299 & --- & --- & 0.299 & --- & --- \\
 &  &  & Max overshoot & 6.764 & --- & --- & 7.680 & --- & --- & 9.619 & --- & --- \\
\hline
\multirow{6}{*}{QaL} & SP change & IAE & 271.538 & 268.464 & 294.790 & 340.253 & 344.112 & 343.028 & 526.749 & 547.948 & 490.445 \\
 &  &  & $\Delta U_{max}$ & 29.169 & 29.169 & 29.169 & 29.169 & 29.169 & 29.169 & 29.169 & 29.169 & 29.169 \\
 &  &  & Max overshoot & 0.000 & 0.000 & 0.363 & 0.000 & 0.122 & 0.000 & 0.000 & 2.028 & 0.428 \\
 &  & d=-0.3 & IAE & 71.339 & 83.552 & 89.302 & 135.390 & 113.555 & 125.586 & 237.452 & 437.182 & 198.739 \\
 &  &  & $\Delta U_{max}$ & 0.444 & 0.421 & 0.383 & 0.535 & 0.761 & 0.804 & 0.314 & 0.341 & 0.312 \\
 &  &  & Max overshoot & 4.528 & 5.419 & 4.956 & 7.804 & 6.573 & 8.493 & 9.775 & 10.308 & 9.155 \\
\hline
\end{tabular}%
}
\end{table}