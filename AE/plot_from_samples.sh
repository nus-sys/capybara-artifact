#!/bin/bash
# Regenerate every figure from the shipped sample data — NO experiment, NO
# cluster, ~seconds. Each figure is rendered by the paper's own plotting code
# (same fonts/colors/layout, this data only) for side-by-side comparison with
# the paper. Output: sample-figures/figN_reproduction.{png,pdf}.
#
# usage: bash plot_from_samples.sh          # all six
#        bash plot_from_samples.sh 7 10      # a subset
set -u
K=$(cd "$(dirname "$0")" && pwd)
S=$K/sample-data
O=$K/sample-figures
P=$K/paperplot/paper_style.py
mkdir -p $O
FIGS="${*:-7 8 9 10 11 14}"

for f in $FIGS; do
  echo "=== fig$f (from sample-data) ==="
  case $f in
    7)  python3 $P fig7 $S/fig7/fig7_results.txt $O/fig7_reproduction ;;
    8)  CAPYBARA_DATA=$S/fig8 python3 $P fig8 fig8LWRR-run1 fig8REACT-run1 fig8CAPY-run1 $O/fig8_reproduction ;;
    9)  CAPYBARA_DATA=$S/fig9 python3 $P fig9 fig9LWRR-run1 fig9CAPY-run1 $O/fig9_reproduction ;;
    10) python3 $P fig10 $S/fig10/fig10_results_mss8960.txt $O/fig10_reproduction ;;
    11) python3 $P fig11 $S/fig11/results_closed_capy.txt $S/fig11/results_closed_prismstar.txt $S/fig11/results_closed_proxy.txt $O/fig11_reproduction ;;
    14) python3 $P fig14 $S/fig14 $S/fig14/paper_ref $O/fig14_reproduction ;;
    *)  echo "unknown figure: $f" ;;
  esac
done
echo
echo "figures written to: $O/"
ls $O/*.png 2>/dev/null
