#!/bin/bash
# Stage certified reference inputs into the kit as shippable sample data, so a
# reviewer can regenerate every figure WITHOUT running any experiment (and
# without touching the cluster). Run as inho on node7.
set -e
K=/homes/sigcomm26ae/capybara-AE-runs
D=/homes/inho/capybara-data
S=$K/sample-data
mkdir -p $S/fig7 $S/fig8 $S/fig9 $S/fig10 $S/fig11 $S/fig14 $S/fig14/paper_ref

# fig7: sweep results file
cp $K/fig7/fig7_results.txt $S/fig7/

# fig8: per-experiment record files the plotter reads (3 conditions)
for c in LWRR REACT CAPY; do
  for suf in be0_pps_signal sched_ms_req server_ms_avg_99p_lat \
             server_ms_num_conn_10000 server_ms_num_conn_10001; do
    [ -f $D/fig8${c}-run1.$suf ] && cp $D/fig8${c}-run1.$suf $S/fig8/ || true
  done
done

# fig9: CDF traces (paper fn plots these two curves in the paper's style)
cp $D/fig9LWRR-run1.lat_cdf $D/fig9CAPY-run1.lat_cdf $S/fig9/

# fig10: sweep results file
cp $K/fig10/fig10_results_mss8960.txt $S/fig10/

# fig11: closed-loop peak files
cp $K/fig11/results_closed_capy.txt $K/fig11/results_closed_prismstar.txt \
   $K/fig11/results_closed_proxy.txt $S/fig11/

# fig14: our sweep summaries + paper reference
cp $D/miglattcp2-*-sweep.mig_delay_avg_minmax_stddev $S/fig14/
cp $D/miglattls*-sweep.mig_delay_avg_minmax_stddev $S/fig14/
cp $K/fig14/paper_ref/*.mig_delay_avg_minmax_stddev $S/fig14/paper_ref/

echo "sample-data staged:"
for f in 7 8 9 10 11 14; do echo "  fig$f: $(ls $S/fig$f | grep -v paper_ref | wc -l) files"; done
