#!/usr/bin/env python3
"""Fig 11 reproduction plot: L7 server scalability, closed- and open-loop,
our measured peaks beside the paper's data (graphs/data/server_scalability_
{closed,open}loop_l7.csv columns 0/2/3). Same layout as the paper's
plot_server_scalability_l7."""
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

SYSTEMS = ["L7 Proxy", "Prism", "Capybara-L7"]
CATS = ["1 Server", "2 Servers", "4 Servers"]

# Gbps. None = not measured (documented limitation).
OURS_CLOSED = [
    [18.40, 18.32, 18.00],   # proxy (wrk peaks)
    [30.48, 59.28, 93.04],   # prism-star
    [28.00, 39.84, 92.88],   # capy-proxy
]
PAPER_CLOSED = [
    [15.68, 16.24, 16.16],
    [24.72, 46.88, 91.36],
    [24.72, 47.20, 90.88],
]
OURS_OPEN = [
    [12.82, None, None],     # proxy (multi-BE open: see README)
    [0.104, 0.013, 0.063],   # prism-star: collapse
    [17.89, 34.99, 64.07],   # capy-proxy
]
PAPER_OPEN = [
    [12.99, 13.69, 13.87],
    [0.088, 0.101, 0.091],
    [17.87, 34.15, 65.20],
]

C_OURS = ["#9ecae1", "#4292c6", "#08519c"]   # blues by server count
C_PAPER = "#bdbdbd"

fig, axes = plt.subplots(1, 2, figsize=(9.2, 3.0), sharey=True)
titles = ["Closed-Loop", "Open-Loop"]
group_spacing = 1.5
bw = 0.18

for ax, ours, paper, title in zip(
        axes, [OURS_CLOSED, OURS_OPEN], [PAPER_CLOSED, PAPER_OPEN], titles):
    x = np.arange(len(SYSTEMS)) * group_spacing
    for i in range(3):  # server counts
        ov = [row[i] if row[i] is not None else 0 for row in ours]
        pv = [row[i] for row in paper]
        xo = x + (i - 1) * 2.2 * bw - bw / 2
        xp = xo + bw
        ax.bar(xo, ov, bw, color=C_OURS[i],
               label=f"{CATS[i]} (ours)" if title == "Closed-Loop" else None)
        ax.bar(xp, pv, bw, color=C_PAPER, hatch="//", edgecolor="white",
               label=f"{CATS[i]} (paper)" if (title == "Closed-Loop" and i == 2) else None)
        for xi, v, missing in zip(xo, ov, [row[i] is None for row in ours]):
            if missing:
                ax.text(xi + bw / 2, 1.5, "n/m", ha="center", fontsize=7, rotation=90, color="#666666")
    ax.set_title(title)
    ax.set_xticks(x)
    ax.set_xticklabels(SYSTEMS, fontsize=9)
    ax.grid(axis="y", linestyle="--", linewidth=0.6, alpha=0.6)

axes[0].set_ylabel("Throughput (Gbps)")
handles = [plt.Rectangle((0, 0), 1, 1, color=C_OURS[i]) for i in range(3)] + \
          [plt.Rectangle((0, 0), 1, 1, facecolor=C_PAPER, hatch="//", edgecolor="white")]
fig.legend(handles, CATS + ["paper"], loc="upper center", ncol=4, fontsize=9,
           bbox_to_anchor=(0.5, 1.06), frameon=False)
fig.suptitle("Fig. 11 reproduction — colored: ours, gray hatched: paper", y=-0.04, fontsize=8)
fig.tight_layout(rect=(0, 0, 1, 0.94))
for ext in ("png", "pdf"):
    fig.savefig(f"fig11_reproduction.{ext}", dpi=200, bbox_inches="tight")
print("saved fig11_reproduction.png/pdf")
