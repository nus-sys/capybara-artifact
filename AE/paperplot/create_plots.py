#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pandas as pd
import matplotlib.ticker as tick
import numpy as np

import matplotlib as mpl
mpl.use("Agg")
from matplotlib import pyplot as plt
import csv
import io
import sys
import matplotlib.patches as mpatches
from mpl_toolkits.axes_grid1.inset_locator import inset_axes, mark_inset
import re

import math
from cycler import cycler
from brokenaxes import brokenaxes

DATA_PATH = "graphs/data"
DEFAULT_WIDTH = 6.4

SYS = 'Capybara'
BASELINE = 'LWRR'
SYS_C = 'xkcd:blue'
SYS_C2 = 'xkcd:dark blue'
COMPARE1_C = 'xkcd:grass green'
COMPARE1_C2 = 'xkcd:dark green'
BASELINE_C = 'xkcd:grey'
COMPARE2_C = 'xkcd:orange'
COMPARE3_C = 'xkcd:purple'

def lighten(c, amt=0.55):
    """Blend color c toward white by amt (0=original, 1=white).
    Used for bar fills so hatch patterns stay visible when printed."""
    r, g, b = mpl.colors.to_rgb(c)
    return (r + (1 - r) * amt, g + (1 - g) * amt, b + (1 - b) * amt)

C = [
    'xkcd:grass green',
    'xkcd:blue',
    'xkcd:purple',
    'xkcd:brick red',
    'xkcd:orange',
    'xkcd:teal',
    
    'xkcd:black',
    'xkcd:brown',
    'xkcd:grey',
    'xkcd:pink',
    'xkcd:cyan',
]
# C = ['royalblue', 
#      'darkorange', 
#      'orchid', 
#      'teal',
#      'forestgreen', 
#      'crimson', 
#      'mediumpurple', 
#      'steelblue', 
#      'tomato', 
#      'dodgerblue', 
#      'goldenrod', 
#      'slategray', 
#      ]


LS = [
    'solid',
    'dashed',
    'dotted',
    'dashdot',
    (0, (5, 10)),
]

M = [
    'o',
    's',
    '^',
    'v',
    'D'
]

# MS = [
#     1,
#     1,
#     3,
#     3,
#     1
# ]


def setup():
    """Called before every plot_ function"""

    def lcm(a, b):
        return abs(a*b) // math.gcd(a, b)

    def a(c1, c2):
        """Add cyclers with lcm."""
        l = lcm(len(c1), len(c2))
        c1 = c1 * (l//len(c1))
        c2 = c2 * (l//len(c2))
        return c1 + c2

    def add(*cyclers):
        s = None
        for c in cyclers:
            if s is None:
                s = c
            else:
                s = a(s, c)
        return s


    plt.rc('axes', prop_cycle=(add(cycler(color=C),
                                   cycler(linestyle=LS),
                                   cycler(marker=M))))
    plt.rc('lines', markersize=5)
    plt.rc('legend', handlelength=3, handleheight=1.5, labelspacing=0.25)
    plt.rcParams["font.family"] = "sans-serif"
    plt.rcParams["font.size"] = 10
    plt.rcParams['pdf.fonttype'] = 42
    plt.rcParams['ps.fonttype'] = 42
    # Make bar hatch patterns clearly visible in print: force dark bar outlines
    # (hatch is drawn in the edge color) and a slightly bolder hatch line.
    plt.rcParams['patch.edgecolor'] = 'black'
    plt.rcParams['patch.force_edgecolor'] = True
    plt.rcParams['hatch.linewidth'] = 0.7
    plt.rcParams['legend.fontsize'] = 'medium'
    # Increase tick label font size for better visibility
    plt.rcParams['xtick.labelsize'] = 12
    plt.rcParams['ytick.labelsize'] = 12
    # Increase axis label font size for better visibility
    plt.rcParams['axes.labelsize'] = 12



def set_zeros():
    """Sets lower bound of x and y axis to zero"""
    _, r = plt.xlim()
    plt.xlim(0, r)
    _, r = plt.ylim()
    plt.ylim(0, r)

def millions(x, pos):
    'The two args are the value and tick position'
    return str(int(x/1000000)) + '.' + str(int((x%1000000)/100000)) + 'M'

def millions_no_decimal_point(x, pos):
    'The two args are the value and tick position'
    return str(int(x/1000000)) + 'M'

def thousands(x, pos):
    'The two args are the value and tick position'
    return str(int(x/1000)) + 'K'

def milliseconds_to_seconds(x, pos):
    'The two args are the value and tick position'
    return str(int(x/1000)) + 's'

def percents(x, pos):
    'The two args are the value and tick position'
    return str(x) + '%'

def seq_failover(x, pos):
    'The two args are the value and tick position'
    return str(int(x))


################################################################################
# PLOTS START HERE
################################################################################
# def _redis_numsvr_lat_vs_tput():
#     fig = plt.figure(figsize=(DEFAULT_WIDTH, 3.5))
#     ax = fig.add_subplot()
#     data = pd.read_csv(f'{DATA_PATH}/redis_numsvr_lat_vs_tput.csv', header=None)
#     num_columns = len(data.columns)
#     column_names = [f'x{int(i/2)}' if i % 2 == 0 else f'y{int(i/2)}' for i in range(num_columns)]
#     data.columns = column_names
    
#     # Loop over each column and sort the data based on y-values
#     labels = ["1, 12, X", "1, 120, X", "1, 12, O", "1, 120, O",
#               "2, 12, X", "2, 120, X", "2, 12, O", "2, 120, O",
#               "3, 12, X", "3, 120, X", "3, 12, O", "3, 120, O",
#               "4, 12, X", "4, 120, X", "4, 12, O", "4, 120, O"]
    
#     for i in range(int(num_columns/2)):
#         column_x = f'x{i}'
#         column_y = f'y{i}'
#         # ax.plot(data[column_x], data[column_y], label=f"{i+1}", marker='o', color=C[i])
#         ax.plot(data[column_x], data[column_y], marker='o', color=C[int(i/4)], label=labels[i])

#     plt.ylabel("p99 Latency (μs)")
#     plt.xlabel("Throughput (reqs/s)")
#     plt.ylim([0, 700])
#     plt.legend(title="(# svr, # conn, is_MIG_enabled)", ncol=4, bbox_to_anchor=(-0.1,-0.6,1.1,0), loc="lower left", mode="expand")
#     plt.title("Server's MAX throughput")
#     set_zeros()

#     ax.xaxis.set_major_formatter(tick.FuncFormatter(thousands))

#     return fig

# def _numsvr_lat_vs_tput():
#     fig = plt.figure(figsize=(DEFAULT_WIDTH, 3.5))
#     ax = fig.add_subplot()
#     data = pd.read_csv(f'{DATA_PATH}/numsvr_lat_vs_tput.csv', header=None)
#     num_columns = len(data.columns)
#     column_names = [f'x{int(i/2)}' if i % 2 == 0 else f'y{int(i/2)}' for i in range(num_columns)]
#     data.columns = column_names
    
#     # Loop over each column and sort the data based on y-values
#     labels = ["1, 12, X", "1, 120, X", "1, 12, O", "1, 120, O",
#               "2, 12, X", "2, 120, X", "2, 12, O", "2, 120, O",
#               "3, 12, X", "3, 120, X", "3, 12, O", "3, 120, O",
#               "4, 12, X", "4, 120, X", "4, 12, O", "4, 120, O"]
    
#     for i in range(int(num_columns/2)):
#         column_x = f'x{i}'
#         column_y = f'y{i}'
#         # ax.plot(data[column_x], data[column_y], label=f"{i+1}", marker='o', color=C[i])
#         ax.plot(data[column_x], data[column_y], marker='o', color=C[int(i%4)], label=labels[i])

#     plt.ylabel("p99 Latency (μs)")
#     plt.xlabel("Throughput (reqs/s)")
#     plt.ylim([0, 150])
#     plt.legend(title="(# svr, # conn, is_MIG_enabled)", ncol=4, bbox_to_anchor=(-0.1,-0.6,1.1,0), loc="lower left", mode="expand")
#     plt.title("Server's MAX throughput")
#     set_zeros()

#     ax.xaxis.set_major_formatter(tick.FuncFormatter(thousands))

#     return fig


# def _1svr_lat_vs_tput():
#     fig = plt.figure(figsize=(DEFAULT_WIDTH, 3.5))
#     ax = fig.add_subplot()
#     data = pd.read_csv(f'{DATA_PATH}/1svr_lat_vs_tput.csv', header=None)
#     num_columns = len(data.columns)
#     column_names = [f'x{int(i/2)}' if i % 2 == 0 else f'y{int(i/2)}' for i in range(num_columns)]
#     data.columns = column_names
    
#     # Loop over each column and sort the data based on y-values
#     labels = ["1, 12, X", "1, 120, X", "1, 12, O", "1, 120, O"]
    
#     for i in range(int(num_columns/2)):
#         column_x = f'x{i}'
#         column_y = f'y{i}'
#         # ax.plot(data[column_x], data[column_y], label=f"{i+1}", marker='o', color=C[i])
#         ax.plot(data[column_x], data[column_y], marker='o', color=C[int(i%4)], label=labels[i])

#     plt.ylabel("p99 Latency (μs)")
#     plt.xlabel("Throughput (reqs/s)")
#     plt.ylim([0, 150])
#     plt.legend(title="(# svr, # conn, is_MIG_enabled)", ncol=2, loc="upper left")
#     plt.title("Server's MAX throughput")
#     set_zeros()

#     ax.xaxis.set_major_formatter(tick.FuncFormatter(thousands))

#     return fig

# def plot_1svr_sys_ovhd():
#     fig = plt.figure(figsize=(DEFAULT_WIDTH, 2.7))
#     ax = fig.add_subplot()
#     data = pd.read_csv(f'{DATA_PATH}/1svr_capybara_ovhd.csv', header=None)
#     num_columns = len(data.columns)
#     column_names = [f'x{int(i/2)}' if i % 2 == 0 else f'y{int(i/2)}' for i in range(num_columns)]
#     data.columns = column_names
    
#     # Loop over each column and sort the data based on y-values
#     labels = [
#                 "FE-Proxy (1 BE)", 
#                 "Prism (1 BE)", 
#                 "LWRR (1 BE)", 
#                 f"{SYS} (1 BE)",
#                 f"{SYS}-SW (1 BE)",
#                 "FE-Proxy (2 BEs)",
#                 "Prism (2 BEs)",
#                 "LWRR (2 BEs)",
#                 f"{SYS} (2 BEs)",
#                 f"{SYS}-SW (2 BEs)",
#                 "FE-Proxy (4 BEs)",
#                 "Prism (4 BEs)",
#                 "LWRR (4 BEs)",
#                 f"{SYS} (4 BEs)",
#                 f"{SYS}-SW (4 BEs)",
#               ]
    
#     for i in range(int(num_columns/2)):
#         column_x = f'x{i}'
#         column_y = f'y{i}'
#         # ax.plot(data[column_x], data[column_y], label=f"{i+1}", marker='o', color=C[i])
#         ax.plot(data[column_x], data[column_y], linestyle=LS[int(i/5)], marker=M[int(i/5)], label=labels[i], color=C[i%5])

#     plt.ylabel("p99 Latency (μs)")
#     plt.xlabel("Throughput (reqs/s)")
#     # plt.xlim([0, 1500000])
#     plt.ylim([0, 200])
#     # plt.legend(ncol=1, loc="upper left")
#     plt.legend(ncol=3, 
#            bbox_to_anchor=(-0.05, 1.02, 1.1, 0),  # Increase the third value for width
#            loc="lower left", 
#            mode="expand", 
#         #    borderpad=1.5,  # Optional: adjust padding inside the box
#            handletextpad=1,  # Space between legend handles and text
#         )  

#     set_zeros()

#     ax.xaxis.set_major_formatter(tick.FuncFormatter(millions))

#     return fig

def plot_server_scalability():
    fig = plt.figure(figsize=(DEFAULT_WIDTH, 2.3))
    ax = fig.add_subplot()

    # Load the data
    data = []
    with open(f'{DATA_PATH}/server_scalability.csv', 'r') as file:
        for line in file:
            row = list(map(int, line.strip().split(',')))
            data.append(row)

    # Data parsing
    data = np.array(data)  # Do not transpose
    x_labels = ['L7 Proxy', 'Prism', 'LWRR', f'{SYS}', f'{SYS}-SW']  # X-axis labels
    categories = ['1 Server', '2 Servers', '4 Servers']  # Categories (rows of the data)
    x = np.arange(len(x_labels))  # The label locations
    bar_width = 0.25  # Width of each bar

    # Patterns for the bars (simplified and less dense)
    patterns = ['-', '/', '\\']  # Use simpler hatch patterns


    # Plot each group (X=1, X=2, X=4)
    for i in range(data.shape[0]):
        ax.bar(
            x + i * bar_width, 
            data[i], 
            bar_width, 
            label=categories[i], 
            color=lighten(C[i % len(C)]),
            hatch=patterns[i % len(patterns)]  # Apply the hatch pattern cyclically
        )

    # Customization
    ax.set_ylabel('Throughput (reqs/s)')
    ax.set_xticks(x + bar_width * (data.shape[0] - 1) / 2)
    ax.set_xticklabels(x_labels)
    ax.yaxis.set_major_formatter(tick.FuncFormatter(millions))

    ax.legend(ncol=1, loc="upper left", fontsize='medium')

    plt.grid(axis='y', linestyle='--', linewidth=0.7)

    # Save and display
    plt.tight_layout()

    return fig
def plot_server_scalability_l7():
    fig, axes = plt.subplots(
        1, 2,  # 1 row, 2 columns
        figsize=(DEFAULT_WIDTH, 2.3),  # Make it wider since we have two plots
        sharey=True  # Share the Y-axis
    )

    filenames = [
        f'{DATA_PATH}/server_scalability_closedloop_l7.csv',
        f'{DATA_PATH}/server_scalability_openloop_l7.csv'
    ]
    titles = [
        "Closed-Loop",
        "Open-Loop"
    ]

    x_labels = ['L7 Proxy', 'Prism', f'{SYS}-L7']
    categories = ['1 Server', '2 Servers', '4 Servers']
    bar_width = 0.25
    patterns = ['-', '/', '\\']

    for ax, filename, title in zip(axes, filenames, titles):
        # Load the data
        data = []
        with open(filename, 'r') as file:
            for line in file:
                row = list(map(float, line.strip().split(',')))
                data.append(row)

        data = np.array(data)
        data = data[:, [0, 2, 3]]  # Skip Prism (Linux) column
        # Spread groups apart so the wider 'Capybara-L7' label has room and the
        # inter-label gaps look even (narrow 'Prism' sits between two long labels).
        group_spacing = 1.35
        x = np.arange(len(x_labels)) * group_spacing

        # Plot each group
        for i in range(data.shape[0]):
            ax.bar(
                x + i * bar_width,
                data[i],
                bar_width,
                label=categories[i],
                color=lighten(C[i % len(C)]),
                hatch=patterns[i % len(patterns)]
            )

        # Customize each subplot
        ax.set_title(title)
        ax.set_xticks(x + bar_width * (data.shape[0] - 1) / 2)
        ax.set_xticklabels(x_labels)
        ax.grid(axis='y', linestyle='--', linewidth=0.7)
        ax.tick_params(labelleft=True)

    # Common Y-axis label
    axes[0].set_ylabel('Throughput (Gbps)')
    # axes[0].yaxis.set_major_formatter(tick.FuncFormatter(millions))

    # Only one legend, place it above the figure
    fig.legend(
        categories,  # The labels (1 Server, 2 Servers, 4 Servers)
        loc="upper center",
        ncol=len(categories),  # Spread horizontally
        bbox_to_anchor=(0.5, 1.1),  # (x=50%, y=115% of figure height)
        fontsize='medium'
    )
    plt.tight_layout()
    return fig

def plot_server_scalability_l4():
    fig = plt.figure(figsize=(DEFAULT_WIDTH, 2.3))
    ax = fig.add_subplot()

    # Load the data
    data = []
    with open(f'{DATA_PATH}/server_scalability_openloop_l4.csv', 'r') as file:
        for line in file:
            row = list(map(float, line.strip().split(',')))
            data.append(row)

    # Data parsing
    data = np.array(data)
    data = data[:, 1:]  # Remove the first column (LWRR)

    x_labels = [f'{SYS}', f'{SYS}-SW']
    categories = ['1 Server', '2 Servers', '4 Servers', '8 Servers', '12 Servers']
    x = np.arange(len(x_labels))  # [0, 1]

    # Adjusted bar width (2/3 of previous)
    bar_width = 0.12

    # Adjust spacing to center bars correctly
    total_width = bar_width * data.shape[0]
    offset = (total_width - bar_width) / 2

    patterns = ['-', '/', '\\', 'o', '']

    # Plot bars
    for i in range(data.shape[0]):
        ax.bar(
            x - offset + i * bar_width,
            data[i],
            bar_width,
            label=categories[i],
            color=lighten(C[i % len(C)]),
            hatch=patterns[i % len(patterns)],
        )

    # Axis settings
    ax.set_ylabel('Throughput (reqs/s)')
    ax.set_xticks(x)
    ax.set_xticklabels(x_labels)
    ax.yaxis.set_major_formatter(tick.FuncFormatter(millions))

    ax.legend(ncol=1, loc="upper right", fontsize='medium')
    plt.grid(axis='y', linestyle='--', linewidth=0.7)

    plt.tight_layout()
    return fig



def plot_tput_vs_mig_freq():
    fig = plt.figure(figsize=(DEFAULT_WIDTH*1.15,2.5))
    ax = fig.add_subplot()
    data = pd.read_csv(f'{DATA_PATH}/tput_vs_mig_freq.csv', header=0, index_col=False)
    num_columns = len(data.columns)
    column_names = ['x0'] + [f'y{i}' for i in range(num_columns-1)]
    data.columns = column_names
    data['x0'] = data['x0'].replace(0, 0.1)
    labels = [
                "1",
                "8",
                "16",
                "32",
                "64",
                # "128 KB",
                ]
    for i in range(0, num_columns-2):
        # column_x = f'x{i}'
        column_y = f'y{i}'
        # ax.plot(data[column_x], data[column_y], label=f"{i+1}", marker='o', color=C[i])
        ax.plot(data['x0'], data[column_y], linestyle=LS[int(i%5)], marker=M[int(i%5)], label=labels[i], color=C[i%5])
    # for i in range(4):
    #     ax.plot(sample_data.x1, sample_data.y1, label="1",  color=C[0], marker=M[0])

    plt.ylabel("Throughput (Gbps)")
    plt.xlabel("Migrations per second")

    # Example data for the legend
    handles, labels = ax.get_legend_handles_labels()  # Get existing legend handles and labels

    # Add the title as the first "label" in the legend
    # handles = [plt.Line2D([0], [0], color='none')] + handles  # Empty line for the title
    # labels = ['DUP_ACK_THRESHOLD:'] + labels  # Add the title text

   # Manually add a fake "response size" entry
    handles = [plt.Line2D([0], [0], color='none')] + handles
    labels = ["Response Size (KB)"] + labels

    plt.legend(
        handles,
        labels,
        loc='upper center',
        # bbox_to_anchor=(0.5, 1.15),
        ncol=6,  # 5 labels + 1 fake title
        fontsize='medium',
        handlelength=3.3,
        handletextpad=0.7,
        columnspacing=1.0,
    )
    plt.ylim([0, 45])
    # plt.xlim([1, 1000])
    # plt.yticks(np.arange(0, 850001, 200000))
    ax.set_xscale('log')
    plt.xticks(
    [0.1, 1, 10, 100, 1000, 10000],  # Actual x tick positions
    ["0", "1", "10", "100", "1000", "10000"]  # Labels shown on the plot
    )
    

    plt.tight_layout()
    return fig



def plot_large_scale():
    fig = plt.figure(figsize=(DEFAULT_WIDTH, 2.3))
    ax = fig.add_subplot()

    # Load the data
    data = []
    with open(f'{DATA_PATH}/large_scale.csv', 'r') as file:
        for line in file:
            row = list(map(float, line.strip().split(',')))
            data.append(row)

    # Data parsing
    data = np.array(data)  # Do not transpose
    x_labels = ['1 KB', '4 KB', '8 KB', '16 KB', '20 KB']  # X-axis labels
    categories = ['LWRR', f'{SYS}', 'Uniform']  # Categories (rows of the data)
    x = np.arange(len(x_labels))  # The label locations
    bar_width = 0.25  # Width of each bar

    # Patterns for the bars (simplified and less dense)
    patterns = ['-', '/', '\\']  # Use simpler hatch patterns


    # Plot each group (X=1, X=2, X=4)
    for i in range(data.shape[0]):
        ax.bar(
            x + i * bar_width, 
            data[i], 
            bar_width, 
            label=categories[i], 
            color=lighten(C[i % len(C)]),
            hatch=patterns[i % len(patterns)]  # Apply the hatch pattern cyclically
        )

    # Customization
    ax.set_ylabel('Throughput (Gbps)')
    ax.set_xlabel('Response Size')
    ax.set_xticks(x + bar_width * (data.shape[0] - 1) / 2)
    ax.set_xticklabels(x_labels)
    # ax.set_ylim(0, 3000000)
    # ax.yaxis.set_major_formatter(tick.FuncFormatter(millions))

    ax.legend(ncol=1, loc="upper left", fontsize='medium')

    plt.grid(axis='y', linestyle='--', linewidth=0.7)


    # Save and display
    plt.tight_layout()

    return fig


# def _mig_latency():
#     fig = plt.figure(figsize=(3.5, 3.5))
#     ax = fig.add_subplot()

#     file_paths = [
#     f'{DATA_PATH}/20231129-121832.807496.mig_latency', #100K
#     f'{DATA_PATH}/20231129-121620.348018.mig_latency', #200K
#     f'{DATA_PATH}/20231129-121423.915029.mig_latency', #300K
#     # Add paths to the files here
#     ]

#     labels = ["100K", "200K", "300K"]
#     for i, file_path in enumerate(file_paths):
#         # Initialize an empty list to store data for the last column
#         column_data = []

#         # Read data from the current file
#         with open(file_path, 'r') as file:
#             for line in file:
#                 values = list(map(float, line.strip().split(',')))
#                 last_value = values[-2]  # Get the last value (last column)
#                 column_data.append(last_value)

#         # Plot CDF for the last column
#         sorted_col = sorted(column_data)
#         sorted_col = [x / 1000 for x in sorted_col]  # Divide values by 1000
#         cdf = np.arange(1, len(sorted_col) + 1) / len(sorted_col)
#         ax.plot(sorted_col, cdf, marker='o', label=labels[i])

#         # Set labels and title for the current subplot
#         ax.set_xlabel('Migration Delay (μs)')
#         ax.set_ylabel('CDF')
#         # ax.set_title(f'Total Migration Latency')
#         ax.grid()
#         ax.legend(title="PPS per server")


#     ax.set_xlim([0, 50])

#     # Set a common title for all subplots
#     # plt.suptitle("CDF for Last Column (4 Files)")

#     # Adjust spacing between subplots
#     plt.tight_layout()
    

#     return fig

# def _mig_latency_breakdown():
#     # Initialize empty lists to store data for each column from the first file
#     column_data1 = [[] for _ in range(11)]

#     # Read data from the first file
#     with open(f'{DATA_PATH}/20231129-121832.807496.mig_latency', 'r') as file1:
#         for line in file1:
#             values = list(map(float, line.strip().split(',')))
#             for i, value in enumerate(values):
#                 column_data1[i].append(value)

#     # Initialize empty lists to store data for each column from the second file
#     column_data2 = [[] for _ in range(11)]

#     # Read data from the second file
#     with open(f'{DATA_PATH}/20231129-121423.915029.mig_latency', 'r') as file2:
#         for line in file2:
#             values = list(map(float, line.strip().split(',')))
#             for i, value in enumerate(values):
#                 column_data2[i].append(value)

#     # Create subplots with two columns
#     fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(10, 5))

#     # Plot CDF for each column from the first file
#     for i, col_data in enumerate(column_data1):
#         sorted_col = sorted(col_data)
#         sorted_col = [x / 1000 for x in sorted_col]  # Divide values by 1000    
#         cdf = np.arange(1, len(sorted_col) + 1) / len(sorted_col)
#         ax1.plot(sorted_col, cdf, marker='o', label=f'Step {i + 1}' if i <= 9 else 'black_out')

#     # Plot CDF for each column from the second file
#     for i, col_data in enumerate(column_data2):
#         sorted_col = sorted(col_data)
#         sorted_col = [x / 1000 for x in sorted_col]  # Divide values by 1000
#         cdf = np.arange(1, len(sorted_col) + 1) / len(sorted_col)
#         ax2.plot(sorted_col, cdf, marker='o', label=f'Step {i + 1}' if i <= 9 else 'black_out')


#     # Set labels and title for the first graph
#     ax1.set_xlabel('Time (μs)')
#     ax1.set_ylabel('CDF')
#     ax1.set_title('100K PPS per server')
#     ax1.grid()
#     ax1.legend()

#     # Set labels and title for the second graph
#     ax2.set_xlabel('Time (μs)')
#     ax2.set_ylabel('CDF')
#     ax2.set_title('300K PPS per server')
#     ax2.grid()
#     ax2.legend()


#     ax1.set_xlim([0, 30])
#     ax2.set_xlim([0, 30])

#     # plt.suptitle("100 conns, MIG-per-30req")
#     # Adjust spacing between subplots
#     plt.tight_layout()
    

#     return fig


# def _mig_latency_vs_state():
#     fig = plt.figure(figsize=(3.5, 3.5))
#     ax = fig.add_subplot()

#     file_paths = [
#     f'{DATA_PATH}/20231128-113130.591058.mig_latency', 
#     f'{DATA_PATH}/20231128-113640.883873.mig_latency', 
#     # Add paths to the files here
#     ]

#     labels = ["6 KB", "60 KB"]
#     for i, file_path in enumerate(file_paths):
#         # Initialize an empty list to store data for the last column
#         column_data = []

#         # Read data from the current file
#         with open(file_path, 'r') as file:
#             for line in file:
#                 values = list(map(float, line.strip().split(',')))
#                 last_value = values[-1]  # Get the last value (last column)
#                 column_data.append(last_value)

#         # Plot CDF for the last column
#         sorted_col = sorted(column_data)
#         sorted_col = [x / 1000 for x in sorted_col]  # Divide values by 1000
#         cdf = np.arange(1, len(sorted_col) + 1) / len(sorted_col)
#         ax.plot(sorted_col, cdf, marker='o', label=labels[i])

#         # Set labels and title for the current subplot
#         ax.set_xlabel('Migration Delay (μs)')
#         ax.set_ylabel('CDF')
#         # ax.set_title(f'Total Migration Latency')
#         ax.grid()
#         ax.legend(title="PPS per server")


#     # ax.set_xlim([0, 50])

#     # Set a common title for all subplots
#     # plt.suptitle("CDF for Last Column (4 Files)")

#     # Adjust spacing between subplots
#     plt.tight_layout()
    

#     return fig

# def _mig_latency_vs_state_breakdown():
#     # Initialize empty lists to store data for each column from the first file
#     column_data1 = [[] for _ in range(10)]

#     # Read data from the first file
#     with open(f'{DATA_PATH}/20231128-113130.591058.mig_latency', 'r') as file1:
#         for line in file1:
#             values = list(map(float, line.strip().split(',')))
#             for i, value in enumerate(values):
#                 column_data1[i].append(value)

#     # Initialize empty lists to store data for each column from the second file
#     column_data2 = [[] for _ in range(10)]

#     # Read data from the second file
#     with open(f'{DATA_PATH}/20231128-113640.883873.mig_latency', 'r') as file2:
#         for line in file2:
#             values = list(map(float, line.strip().split(',')))
#             for i, value in enumerate(values):
#                 column_data2[i].append(value)

#     # Create subplots with two columns
#     fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(10, 5))

#     # Plot CDF for each column from the first file
#     for i, col_data in enumerate(column_data1):
#         sorted_col = sorted(col_data)
#         sorted_col = [x / 1000 for x in sorted_col]  # Divide values by 1000    
#         cdf = np.arange(1, len(sorted_col) + 1) / len(sorted_col)
#         ax1.plot(sorted_col, cdf, marker='o', label=f'Step {i + 1}' if i <= 9 else 'black_out')

#     # Plot CDF for each column from the second file
#     for i, col_data in enumerate(column_data2):
#         sorted_col = sorted(col_data)
#         sorted_col = [x / 1000 for x in sorted_col]  # Divide values by 1000
#         cdf = np.arange(1, len(sorted_col) + 1) / len(sorted_col)
#         ax2.plot(sorted_col, cdf, marker='o', label=f'Step {i + 1}' if i <= 9 else 'black_out')


#     # Set labels and title for the first graph
#     ax1.set_xlabel('Time (μs)')
#     ax1.set_ylabel('CDF')
#     ax1.set_title('100K PPS per server')
#     ax1.grid()
#     ax1.legend()

#     # Set labels and title for the second graph
#     ax2.set_xlabel('Time (μs)')
#     ax2.set_ylabel('CDF')
#     ax2.set_title('300K PPS per server')
#     ax2.grid()
#     ax2.legend()


#     # ax1.set_xlim([0, 30])
#     # ax2.set_xlim([0, 30])

#     # plt.suptitle("100 conns, MIG-per-30req")
#     # Adjust spacing between subplots
#     plt.tight_layout()
    

#     return fig

# def _mig_latency_vs_state_breakdown():
#     # Initialize empty lists to store data for each column from the first file
#     column_data1 = [[] for _ in range(10)]

#     # Read data from the first file
#     with open(f'{DATA_PATH}/20231128-113130.591058.mig_latency', 'r') as file1:
#         for line in file1:
#             values = list(map(float, line.strip().split(',')))
#             for i, value in enumerate(values):
#                 column_data1[i].append(value)

#     # Initialize empty lists to store data for each column from the second file
#     column_data2 = [[] for _ in range(10)]

#     # Read data from the second file
#     with open(f'{DATA_PATH}/20231128-113640.883873.mig_latency', 'r') as file2:
#         for line in file2:
#             values = list(map(float, line.strip().split(',')))
#             for i, value in enumerate(values):
#                 column_data2[i].append(value)

#     # Create subplots with two columns
#     fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(10, 5))

#     # Plot CDF for each column from the first file
#     for i, col_data in enumerate(column_data1):
#         sorted_col = sorted(col_data)
#         sorted_col = [x / 1000 for x in sorted_col]  # Divide values by 1000    
#         cdf = np.arange(1, len(sorted_col) + 1) / len(sorted_col)
#         ax1.plot(sorted_col, cdf, marker='o', label=f'Step {i + 1}' if i <= 9 else 'black_out')

#     # Plot CDF for each column from the second file
#     for i, col_data in enumerate(column_data2):
#         sorted_col = sorted(col_data)
#         sorted_col = [x / 1000 for x in sorted_col]  # Divide values by 1000
#         cdf = np.arange(1, len(sorted_col) + 1) / len(sorted_col)
#         ax2.plot(sorted_col, cdf, marker='o', label=f'Step {i + 1}' if i <= 9 else 'black_out')


#     # Set labels and title for the first graph
#     ax1.set_xlabel('Time (μs)')
#     ax1.set_ylabel('CDF')
#     ax1.set_title('100K PPS per server')
#     ax1.grid()
#     ax1.legend()

#     # Set labels and title for the second graph
#     ax2.set_xlabel('Time (μs)')
#     ax2.set_ylabel('CDF')
#     ax2.set_title('300K PPS per server')
#     ax2.grid()
#     ax2.legend()


#     # ax1.set_xlim([0, 30])
#     # ax2.set_xlim([0, 30])

#     # plt.suptitle("100 conns, MIG-per-30req")
#     # Adjust spacing between subplots
#     plt.tight_layout()
    

#     return fig

def plot_latency_vs_recv_qlen():
    # Initialize empty lists to store data for each column from the first file
    column_data1 = [[] for _ in range(2)]

    # Read data from the first file
    with open(f'{DATA_PATH}/20231208-110639.647168.99p_recv_qlen', 'r') as file1:
        for line in file1:
            values = list(map(float, line.strip().split(',')))
            for i, value in enumerate(values):
                column_data1[i].append(value)

    # Initialize empty lists to store data for each column from the second file
    column_data2 = [[] for _ in range(2)]

    # Read data from the second file
    with open(f'{DATA_PATH}/20231208-110041.206937.99p_recv_qlen', 'r') as file2:
        for line in file2:
            values = list(map(float, line.strip().split(',')))
            for i, value in enumerate(values):
                column_data2[i].append(value)

    # Create subplots with two columns
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(5, 5))

    # Plot CDF for each column from the first file
    # for i, col_data in enumerate(column_data1):
    ax1.scatter(column_data1[1], column_data1[0], marker='o')
    # for i, col_data in enumerate(column_data1):
    ax2.scatter(column_data2[1], column_data2[0], marker='o')


    # Set labels and title for the first graph
    ax1.set_xlabel('Global recv_queue length')
    ax1.set_ylabel('Latency (μs)')
    ax1.set_title('1 connection')
    ax1.grid()

    # Set labels and title for the second graph
    ax2.set_xlabel('Global recv_queue length')
    ax2.set_ylabel('Latency (μs)')
    ax2.set_title('100 connections')
    ax2.grid()
    
    plt.tight_layout()

    return fig


def plot_blocking_impact():
    fig = plt.figure(figsize=(DEFAULT_WIDTH, 2.3))
    ax = fig.add_subplot()

    data1 = pd.read_csv(f'{DATA_PATH}/20231127-104740.666874.latency_99p', header=None, names=["x0", "y0"])
    data2 = pd.read_csv(f'{DATA_PATH}/20231127-105035.174940.latency_99p', header=None, names=["x0", "y0"])
    # Calculate and subtract the offset for each file
    offset1 = data1["x0"].iloc[0]
    offset2 = data2["x0"].iloc[0]
    
    data1["x0"] -= offset1
    data2["x0"] -= offset2
    
    ax.plot(data1["x0"], data1["y0"], label=f"{SYS}-lossy", marker='o', color=COMPARE1_C)
    ax.plot(data2["x0"], data2["y0"], label=f"{SYS}", marker='x', color=SYS_C)

    plt.ylabel("10ms p99 Latency (μs)")
    plt.xlabel("Time (ms)")
    # plt.legend(ncol=2, loc="upper left", title="PPS, 99p latency (μs)")
    # plt.legend(title="XXX", ncol=2, bbox_to_anchor=(0, 1.3, 1, 0), loc="upper left", mode="expand")
    plt.legend(ncol=1, loc="upper right")
    return fig
    

def plot_perNreq_lat_vs_tput_50conn():
    fig = plt.figure(figsize=(DEFAULT_WIDTH, 3.5))
    ax = fig.add_subplot()
    data = pd.read_csv(f'{DATA_PATH}/perNreq_lat_vs_tput_50conn.csv', header=None)
    num_columns = len(data.columns)
    column_names = [f'x{int(i/2)}' if i % 2 == 0 else f'y{int(i/2)}' for i in range(num_columns)]
    data.columns = column_names
    
    # Loop over each column and sort the data based on y-values
    labels = [1, 5, 10, 30, 50, 100, 300, 500, 10000]
    for i in range(int(num_columns/2)):
        column_x = f'x{i}'
        column_y = f'y{i}'
        ax.plot(data[column_x], data[column_y], label=f"{str(labels[i])}", marker='o', color=C[i])

    plt.ylabel("p99 Latency (μs)")
    plt.xlabel("Throughput (reqs/s)")
    plt.legend(ncol=2, loc="upper left", title="N (mig per N req)")
    # plt.title("# connections: 1")
    set_zeros()

    ax.xaxis.set_major_formatter(tick.FuncFormatter(thousands))

    return fig
def plot_perNreq_lat_vs_tput_100conn():
    fig = plt.figure(figsize=(DEFAULT_WIDTH, 3.5))
    ax = fig.add_subplot()
    data = pd.read_csv(f'{DATA_PATH}/perNreq_lat_vs_tput_100conn.csv', header=None)
    num_columns = len(data.columns)
    column_names = [f'x{int(i/2)}' if i % 2 == 0 else f'y{int(i/2)}' for i in range(num_columns)]
    data.columns = column_names
    
    # Loop over each column and sort the data based on y-values
    labels = [1, 5, 10, 30, 50, 100, 300, 500, 10000]
    for i in range(int(num_columns/2)):
        column_x = f'x{i}'
        column_y = f'y{i}'
        ax.plot(data[column_x], data[column_y], label=f"{str(labels[i])}", marker='o', color=C[i])

    plt.ylabel("p99 Latency (μs)")
    plt.xlabel("Throughput (reqs/s)")
    plt.legend(ncol=2, loc="upper left", title="N (mig per N req)")
    # plt.title("# connections: 1")
    set_zeros()

    ax.xaxis.set_major_formatter(tick.FuncFormatter(thousands))

    return fig
def plot_perNreq_lat_vs_tput_1conn():
    fig = plt.figure(figsize=(DEFAULT_WIDTH, 3.5))
    ax = fig.add_subplot()
    data = pd.read_csv(f'{DATA_PATH}/perNreq_lat_vs_tput_1conn.csv', header=None)
    num_columns = len(data.columns)
    column_names = [f'x{int(i/2)}' if i % 2 == 0 else f'y{int(i/2)}' for i in range(num_columns)]
    data.columns = column_names
    
    # Loop over each column and sort the data based on y-values
    labels = [1, 5, 10, 30, 50, 100, 300, 500, 10000]
    for i in range(int(num_columns/2)):
        column_x = f'x{i}'
        column_y = f'y{i}'
        ax.plot(data[column_x], data[column_y], label=f"{str(labels[i])}", marker='o', color=C[i])

    plt.ylabel("p99 Latency (μs)")
    plt.xlabel("Throughput (reqs/s)")
    plt.legend(ncol=2, loc="upper left", title="N (mig per N req)")
    # plt.title("# connections: 1")
    set_zeros()

    ax.xaxis.set_major_formatter(tick.FuncFormatter(thousands))

    return fig



def plot_200kpps_recvQlen_vs_rxidx():
    fig = plt.figure(figsize=(DEFAULT_WIDTH, 3.5))
    ax = fig.add_subplot()
    data = pd.read_csv(f'{DATA_PATH}/200kpps_recvQlen_vs_rxidx.csv', header=None)
    num_columns = len(data.columns)
    column_names = [f'x{int(i/2)}' if i % 2 == 0 else f'y{int(i/2)}' for i in range(num_columns)]
    data.columns = column_names
    
    # Loop over each column and sort the data based on y-values
    labels = [
            "100 connections", 
            "1 connection"
              ]
    for i in range(int(num_columns/2)):
        column_x = f'x{i}'
        column_y = f'y{i}'
        ax.plot(data[column_x], data[column_y], label=f"{str(labels[i])}", marker='o', color=C[i])

    plt.ylabel("Total Receive Queue Length")
    plt.xlabel("Request Index")
    plt.legend(ncol=2, loc="upper left")
    # plt.ylim([0, 150])
    # plt.title("# connections: 1")
    set_zeros()

    ax.xaxis.set_major_formatter(tick.FuncFormatter(thousands))

    return fig

def plot_230kpps_recvQlen_vs_rxidx():
    fig = plt.figure(figsize=(DEFAULT_WIDTH, 3.5))
    ax = fig.add_subplot()
    data = pd.read_csv(f'{DATA_PATH}/230kpps_recvQlen_vs_rxidx.csv', header=None)
    num_columns = len(data.columns)
    column_names = [f'x{int(i/2)}' if i % 2 == 0 else f'y{int(i/2)}' for i in range(num_columns)]
    data.columns = column_names
    
    # Loop over each column and sort the data based on y-values
    labels = [
            "100 connections", 
            "1 connection",
              ]
    for i in range(int(num_columns/2)):
        column_x = f'x{i}'
        column_y = f'y{i}'
        ax.plot(data[column_x], data[column_y], label=f"{str(labels[i])}", marker='o', color=C[i])

    plt.ylabel("Total Receive Queue Length")
    plt.xlabel("Request Index")
    plt.legend(ncol=2, loc="upper left")
    # plt.ylim([0, 150])
    # plt.title("# connections: 1")
    set_zeros()

    ax.xaxis.set_major_formatter(tick.FuncFormatter(thousands))

    return fig

def plot_230kpps_latency_vs_time():
    fig = plt.figure(figsize=(DEFAULT_WIDTH, 3.5))
    ax = fig.add_subplot()
    data = pd.read_csv(f'{DATA_PATH}/230kpps_latency_vs_time.csv', header=None)
    num_columns = len(data.columns)
    column_names = [f'x{int(i/2)}' if i % 2 == 0 else f'y{int(i/2)}' for i in range(num_columns)]
    data.columns = column_names
    
    # Loop over each column and sort the data based on y-values
    labels = [
            "100 connections", 
            "1 connection",
              ]
    for i in range(int(num_columns/2)):
        column_x = f'x{i}'
        column_y = f'y{i}'
        ax.plot(data[column_x], data[column_y], label=f"{str(labels[i])}", marker='o', color=C[i])

    plt.ylabel("Latency (μs)")
    plt.xlabel("Time (ms)")
    plt.legend(ncol=2, loc="upper left")
    # plt.ylim([0, 150])
    # plt.title("# connections: 1")
    set_zeros()

    # ax.xaxis.set_major_formatter(tick.FuncFormatter(thousands))

    return fig


def plot_200kpps_latency_vs_time():
    fig = plt.figure(figsize=(DEFAULT_WIDTH, 3.5))
    ax = fig.add_subplot()
    data = pd.read_csv(f'{DATA_PATH}/200kpps_latency_vs_time.csv', header=None)
    num_columns = len(data.columns)
    column_names = [f'x{int(i/2)}' if i % 2 == 0 else f'y{int(i/2)}' for i in range(num_columns)]
    data.columns = column_names
    
    # Loop over each column and sort the data based on y-values
    labels = [
            "100 connections", 
            "1 connection",
              ]
    for i in range(int(num_columns/2)):
        column_x = f'x{i}'
        column_y = f'y{i}'
        ax.plot(data[column_x], data[column_y], label=f"{str(labels[i])}", marker='o', color=C[i])

    plt.ylabel("Latency (μs)")
    plt.xlabel("Time (ms)")
    plt.legend(ncol=2, loc="upper left")
    # plt.ylim([0, 150])
    # plt.title("# connections: 1")
    set_zeros()

    # ax.xaxis.set_major_formatter(tick.FuncFormatter(thousands))

    return fig


def plot_250kpps_redis_rqlen_vs_reqidx():
    fig = plt.figure(figsize=(DEFAULT_WIDTH, 3.5))
    ax = fig.add_subplot()
    data = pd.read_csv(f'{DATA_PATH}/250kpps_redis_rqlen_vs_reqidx.csv', header=None)
    num_columns = len(data.columns)
    column_names = [f'x{int(i/2)}' if i % 2 == 0 else f'y{int(i/2)}' for i in range(num_columns)]
    data.columns = column_names
    
    # Loop over each column and sort the data based on y-values
    labels = [
            "100 connections", 
            "1 connection",
              ]
    for i in range(int(num_columns/2)-1, -1, -1):
        column_x = f'x{i}'
        column_y = f'y{i}'
        ax.plot(data[column_x], data[column_y], label=f"{str(labels[i])}", marker='o', color=C[i])

    plt.ylabel("Total Receive Queue Length")
    plt.xlabel("Request Index")
    plt.legend(ncol=2, loc="upper left")
    # plt.ylim([0, 150])
    # plt.title("# connections: 1")
    set_zeros()

    ax.xaxis.set_major_formatter(tick.FuncFormatter(thousands))

    return fig

def plot_250kpps_redis_latency_vs_time():
    fig = plt.figure(figsize=(DEFAULT_WIDTH, 3.5))
    ax = fig.add_subplot()
    data = pd.read_csv(f'{DATA_PATH}/250kpps_redis_latency_vs_time.csv', header=None)
    num_columns = len(data.columns)
    column_names = [f'x{int(i/2)}' if i % 2 == 0 else f'y{int(i/2)}' for i in range(num_columns)]
    data.columns = column_names
    
    # Loop over each column and sort the data based on y-values
    labels = [
            "100 connections", 
            "1 connection",
              ]
    for i in range(int(num_columns/2)-1, -1, -1):
        column_x = f'x{i}'
        column_y = f'y{i}'
        ax.plot(data[column_x], data[column_y], label=f"{str(labels[i])}", marker='o', color=C[i])

    plt.ylabel("Latency (μs)")
    plt.xlabel("Time (ms)")
    plt.legend(ncol=2, loc="upper left")
    # plt.ylim([0, 150])
    # plt.title("# connections: 1")
    set_zeros()

    # ax.xaxis.set_major_formatter(tick.FuncFormatter(thousands))

    return fig

def plot_260kpps_redis_rqlen_vs_reqidx():
    fig = plt.figure(figsize=(DEFAULT_WIDTH, 3.5))
    ax = fig.add_subplot()
    data = pd.read_csv(f'{DATA_PATH}/260kpps_redis_rqlen_vs_reqidx.csv', header=None)
    num_columns = len(data.columns)
    column_names = [f'x{int(i/2)}' if i % 2 == 0 else f'y{int(i/2)}' for i in range(num_columns)]
    data.columns = column_names
    
    # Loop over each column and sort the data based on y-values
    labels = [
            "100 connections", 
            "1 connection",
              ]
    for i in range(int(num_columns/2)-1, -1, -1):
        column_x = f'x{i}'
        column_y = f'y{i}'
        ax.plot(data[column_x], data[column_y], label=f"{str(labels[i])}", marker='o', color=C[i])

    plt.ylabel("Total Receive Queue Length")
    plt.xlabel("Request Index")
    plt.legend(ncol=2, loc="upper left")
    # plt.ylim([0, 150])
    # plt.title("# connections: 1")
    set_zeros()

    ax.xaxis.set_major_formatter(tick.FuncFormatter(thousands))

    return fig

def plot_260kpps_redis_latency_vs_time():
    fig = plt.figure(figsize=(DEFAULT_WIDTH, 3.5))
    ax = fig.add_subplot()
    data = pd.read_csv(f'{DATA_PATH}/260kpps_redis_latency_vs_time.csv', header=None)
    num_columns = len(data.columns)
    column_names = [f'x{int(i/2)}' if i % 2 == 0 else f'y{int(i/2)}' for i in range(num_columns)]
    data.columns = column_names
    
    # Loop over each column and sort the data based on y-values
    labels = [
            "100 connections", 
            "1 connection",
              ]
    for i in range(int(num_columns/2)-1, -1, -1):
        column_x = f'x{i}'
        column_y = f'y{i}'
        ax.plot(data[column_x], data[column_y], label=f"{str(labels[i])}", marker='o', color=C[i])

    plt.ylabel("Latency (μs)")
    plt.xlabel("Time (ms)")
    plt.legend(ncol=2, loc="upper left")
    # plt.ylim([0, 150])
    # plt.title("# connections: 1")
    set_zeros()

    # ax.xaxis.set_major_formatter(tick.FuncFormatter(thousands))

    return fig


def plot_mig_lat_vs_time():
    fig = plt.figure(figsize=(DEFAULT_WIDTH, 3.5))
    ax = fig.add_subplot()
    
    data1 = pd.read_csv(f'{DATA_PATH}/nomig_lat_vs_time.csv', header=None, names=["x0", "y0"])
    data2 = pd.read_csv(f'{DATA_PATH}/recvQ30mig_lat_vs_time.csv', header=None, names=["x0", "y0"])
    data3 = pd.read_csv(f'{DATA_PATH}/recvQ50mig_lat_vs_time.csv', header=None, names=["x0", "y0"])
    
    
    ax.plot(data1["x0"], data1["y0"], label=f"W/o Migration", marker='o', color=C[0])
    ax.plot(data2["x0"], data2["y0"], label=f"Migration if rqlen > 30)", marker='o', color=C[1])
    # ax.plot(data3["x0"], data3["y0"], label=f"3", marker='o', color=C[2])
    

    plt.ylabel("Latency (μs)")
    plt.xlabel("Time")
    # plt.legend(ncol=2, loc="upper left", title="PPS, 99p latency (μs)")
    # plt.legend(title="XXX", ncol=2, bbox_to_anchor=(0, 1.3, 1, 0), loc="upper left", mode="expand")
    plt.legend(ncol=1, loc="upper left")
    
    plt.ylim([0, 1000])
    # plt.title("# connections: 1")
    set_zeros()

    ax.xaxis.set_major_formatter(tick.FuncFormatter(milliseconds_to_seconds))

    pps = ["150K", "170K", "190K", "210K", "230K", "250K"]
    ax.text(6200, 700, '(PPS)', ha='center', va='center', fontsize=10, color='black', weight='bold')
    for i in range(6):
        # Add transparent color bands
        ax.axvspan(i*1000, (i+1)*1000, facecolor=C[i], alpha=0.25)  # Add a gray band from 0 to 1000 on the x-axis
        # ax.axvspan(i*1000, 2000, facecolor='lightblue', alpha=0.5)  # Add a light blue band from 1000 to 2000 on the x-axis

        # Place text above the plot
        ax.text(i*1000 + 500, 700, pps[i], ha='center', va='center', fontsize=10, color='black', weight='bold')
        # ax.text(1500, 520, '2s', ha='center', va='center', fontsize=12, color='black')

    return fig

def plot_migovhd_lat_vs_time():
    fig = plt.figure(figsize=(DEFAULT_WIDTH, 3.5))
    ax = fig.add_subplot()
    
    data1 = pd.read_csv(f'{DATA_PATH}/150k_to_300k_100rqlen.csv', header=None, names=["x0", "y0"])
    data2 = pd.read_csv(f'{DATA_PATH}/150k_to_300k_100rqlen_10migovhd.csv', header=None, names=["x0", "y0"])
    
    
    ax.plot(data1["x0"], data1["y0"], label=f"Default migration (0 additional ovhd)", marker='o', color=C[0])
    ax.plot(data2["x0"], data2["y0"], label=f"Migration with 10 μs additional ovhd)", marker='o', color=C[1])
    # ax.plot(data3["x0"], data3["y0"], label=f"3", marker='o', color=C[2])
    

    plt.ylabel("Latency (μs)")
    plt.xlabel("Time")
    # plt.legend(ncol=2, loc="upper left", title="PPS, 99p latency (μs)")
    # plt.legend(title="XXX", ncol=2, bbox_to_anchor=(0, 1.3, 1, 0), loc="upper left", mode="expand")
    plt.legend(ncol=1, loc="upper left")
    
    # plt.ylim([0, 1000])
    # plt.title("# connections: 1")
    set_zeros()

    ax.xaxis.set_major_formatter(tick.FuncFormatter(milliseconds_to_seconds))

    # pps = ["150K", "170K", "190K", "210K", "230K", "250K"]
    # ax.text(6200, 700, '(PPS)', ha='center', va='center', fontsize=10, color='black', weight='bold')
    # Add transparent color bands
    ax.axvspan(0, 2000, facecolor=C[0], alpha=0.25)  # Add a gray band from 0 to 1000 on the x-axis
    ax.axvspan(2000, 5000, facecolor=C[2], alpha=0.25)  # Add a light blue band from 1000 to 2000 on the x-axis

    # Place text above the plot
    ax.text(1000, 50000, '150K', ha='center', va='center', fontsize=12, color='black', weight='bold')
    ax.text(3500, 50000, '300K', ha='center', va='center', fontsize=12, color='black', weight='bold')

    return fig

def plot_blocking_lat_vs_time():
    fig = plt.figure(figsize=(DEFAULT_WIDTH, 3.5))
    ax = fig.add_subplot()
    
    data1 = pd.read_csv(f'{DATA_PATH}/150k_to_300k_100rqlen_block.csv', header=None, names=["x0", "y0"])
    data2 = pd.read_csv(f'{DATA_PATH}/150k_to_300k_100rqlen_nonblock.csv', header=None, names=["x0", "y0"])
    
    # Calculate and subtract the offset for each file
    offset1 = data1["x0"].iloc[0]
    offset2 = data2["x0"].iloc[0]
    data1["x0"] -= 90
    data2["x0"] -= 90

    ax.plot(data2["x0"], data2["y0"], label=f"{SYS}", marker='o', color=C[0])
    
    ax.plot(data1["x0"], data1["y0"], label=f"{SYS}-lossy", marker='x', color=C[1])
    # ax.plot(data3["x0"], data3["y0"], label=f"3", marker='o', color=C[2])
    

    plt.ylabel("Latency (μs)")
    plt.xlabel("Time (ms)")
    # plt.legend(ncol=2, loc="upper left", title="PPS, 99p latency (μs)")
    # plt.legend(title="XXX", ncol=2, bbox_to_anchor=(0, 1.3, 1, 0), loc="upper left", mode="expand")
    plt.legend(ncol=1, loc="upper right")
    
    plt.xlim([1800, 2300])
    plt.ylim([0, 4250])
    # plt.title("# connections: 1")
    # set_zeros()

    # ax.xaxis.set_major_formatter(tick.FuncFormatter(milliseconds_to_seconds))

    # pps = ["150K", "170K", "190K", "210K", "230K", "250K"]
    # ax.text(6200, 700, '(PPS)', ha='center', va='center', fontsize=10, color='black', weight='bold')
    # Add transparent color bands
    ax.axvspan(0, 2000, facecolor=C[0], alpha=0.25)  # Add a gray band from 0 to 1000 on the x-axis
    ax.axvspan(2000, 5000, facecolor=C[2], alpha=0.25)  # Add a light blue band from 1000 to 2000 on the x-axis

    # Place text above the plot
    ax.text(1900, 2500, '150K', ha='center', va='center', fontsize=12, color='black', weight='bold')
    ax.text(2200, 2500, '300K', ha='center', va='center', fontsize=12, color='black', weight='bold')

    return fig

def plot_static_l4():
    fig, axes = plt.subplots(1, 3, figsize=(DEFAULT_WIDTH*2, 3), sharex=True)

    expt_ids = [
                '20240104-150139.312516', # Uniform
                '20240110-095004.231399', # Zipf-0.9
                '20240110-095225.291168', # Zipf-1.2
                ]
    # LOADSHIFTS = '700000:1000000,700000:1000000,700000:1000000,700000:1000000,700000:1000000'
    legends = [
                'Uniform',
                'Zipf-0.9',
                'Zipf-1.2', 
    ]

    for i in range(3):
        data1 = pd.read_csv(f'{DATA_PATH}/{expt_ids[i]}.latency_99p', header=None, names=["x0", "y0"])
        # data1 = pd.read_csv(f'{DATA_PATH}/{expt_ids[i]}.requests_vs_time', header=None, names=["x0", "y0"])
        
        # Calculate and subtract the offset for each file
        offset1 = data1["x0"].iloc[0]

        data1["x0"] -= offset1

        # Plot data1 on ax1
        axes[i].plot(data1["x0"]-10, data1["y0"], color=C[i])
        axes[i].set_ylim(0, 13000)
        if i == 0:     
            axes[i].set_ylabel("10ms p99 Latency (μs)", fontsize=13)
        axes[i].set_xlabel("Time (ms)", fontsize=13)
        axes[i].legend([f'{legends[i]}'], loc="upper right")
        
    # Adjust layout to prevent overlapping labels
    plt.tight_layout()

    return fig

# def _sys():
#     fig, axes = plt.subplots(1, 3, figsize=(DEFAULT_WIDTH*2, 3), sharex=True)

#     expt_ids = [
#                 '20240104-150317.262580', # Uniform
#                 '20240110-095418.827684', # Zipf-0.9
#                 '20240110-095555.259774', # Zipf-1.2
#                 ]
#     # LOADSHIFTS = '700000:1000000,700000:1000000,700000:1000000,700000:1000000,700000:1000000'
#     legends = [
#                 'Uniform',
#                 'Zipf-0.9',
#                 'Zipf-1.2', 
#     ]

#     for i in range(3):
#         data1 = pd.read_csv(f'{DATA_PATH}/{expt_ids[i]}.latency_99p', header=None, names=["x0", "y0"])
#         # data1 = pd.read_csv(f'{DATA_PATH}/{expt_ids[i]}.requests_vs_time', header=None, names=["x0", "y0"])
        
#         # Calculate and subtract the offset for each file
#         offset1 = data1["x0"].iloc[0]

#         data1["x0"] -= offset1

#         # Plot data1 on ax1
#         axes[i].plot(data1["x0"]-10, data1["y0"], color=C[i])
#         axes[i].set_ylim(0, 200000)
#         if i == 0:
#             axes[i].set_ylabel("10ms p99 Latency (μs)", fontsize=13)
#         axes[i].set_xlabel("Time (ms)", fontsize=13)
#         axes[i].legend([f'{legends[i]}'], loc="upper right")
        
#     # Adjust layout to prevent overlapping labels
#     plt.tight_layout()

#     return fig


# def _sys2():
#     fig, axes = plt.subplots(1, 3, figsize=(DEFAULT_WIDTH*2, 3), sharex=True)

#     expt_ids = [
#                 '20240111-110909.495191', # Uniform
#                 '20240111-111030.559270', # Zipf-0.9
#                 '20240111-111426.483584', # Zipf-1.2
#                 ]
#     # LOADSHIFTS = '700000:1000000,700000:1000000,700000:1000000,700000:1000000,700000:1000000'
#     legends = [
#                 'Zipf-0.9',
#                 'Zipf-1.2',
#                 'Zipf-1.2', 
#     ]

#     for i in range(3):
#         data1 = pd.read_csv(f'{DATA_PATH}/{expt_ids[i]}.latency_99p', header=None, names=["x0", "y0"])
#         # data1 = pd.read_csv(f'{DATA_PATH}/{expt_ids[i]}.requests_vs_time', header=None, names=["x0", "y0"])
        
#         # Calculate and subtract the offset for each file
#         offset1 = data1["x0"].iloc[0]

#         data1["x0"] -= offset1

#         # Plot data1 on ax1
#         if i == 0:
#             axes[i].plot(data1["x0"]-10, data1["y0"], color=C[1])
#         else:
#             axes[i].plot(data1["x0"]-10, data1["y0"], color=C[2])
#         axes[i].set_ylim(0, 200000)
#         if i == 0:
#             axes[i].set_ylabel("10ms p99 Latency (μs)", fontsize=13)
#         axes[i].set_xlabel("Time (ms)", fontsize=13)
#         axes[i].legend([f'{legends[i]}'], loc="upper right")
        
#     # Adjust layout to prevent overlapping labels
#     plt.tight_layout()

#     return fig


def plot_rolling_avg_window_size_1():
    fig, axes = plt.subplots(2, 4, figsize=(DEFAULT_WIDTH*2, 4), sharex=True)

    expt_ids = [
                '20240102-130600.855699', # no sys
                '20240102-130244.976004', # 2^0
                '20240102-130421.647613', # 2^7
                '20240102-130754.863618', # 2^15 
                ]
    # 300000:1000000,600000:100,300000:1000000
    legends = [
                f'W/o {SYS}',
                'Window = 2^0',
                'Window = 2^7',
                'Window = 2^15',

    ]
    for i in range(4):
        data1 = pd.read_csv(f'{DATA_PATH}/{expt_ids[i]}.latency_99p', header=None, names=["x0", "y0"])
        data2 = pd.read_csv(f'{DATA_PATH}/{expt_ids[i]}.requests_vs_time', header=None, names=["x0", "y0"])
        
        # Calculate and subtract the offset for each file
        offset1 = data1["x0"].iloc[0]
        offset2 = data2["x0"].iloc[0]

        data1["x0"] -= offset1
        data2["x0"] -= offset2

        # Plot data1 on ax1
        axes[0][i].plot(data1["x0"] - 950, data1["y0"], color=C[i], marker='')
        axes[0][i].set_ylim(0, 900)
        axes[0][i].legend([f'{legends[i]}'], loc="upper right")

        # Plot data1 on ax1
        axes[1][i].plot(data2["x0"] - 950, data2["y0"], color=C[i], marker='')
        
        axes[1][i].set_ylim(250, 700)
        # axes[1][i].legend([f'{legends[i]}'], loc="upper right")

        axes[1][i].set_xlabel("Time (ms)")

    axes[0][0].set_ylabel("1ms p99 Latency")
    axes[1][0].set_ylabel("Workload (req/ms)")
    # Adjust layout to prevent overlapping labels
    plt.tight_layout()

    # Set the x-axis limit for the entire figure
    plt.xlim([0, 150])

    return fig


def plot_rolling_avg_window_size_2():
    fig, axes = plt.subplots(2, 4, figsize=(DEFAULT_WIDTH*2, 4), sharex=True)

    expt_ids = [
                '20240101-122236.422995', # no sys
                '20240101-123825.271095', # 2^0
                '20240101-123143.971032', # 2^7
                '20240101-123445.095027', # 2^15
                # '20240101-121221.067164', # 2^20
                #'20240101-120332.510912', # 2^7
                ]
    # LOADSHIFTS = '500000:500000,700000:500000'
    legends = [
                f'W/o {SYS}',
                'Window = 2^0',
                'Window = 2^7',
                'Window = 2^15',

    ]

    for i in range(4):
        data1 = pd.read_csv(f'{DATA_PATH}/{expt_ids[i]}.latency_99p', header=None, names=["x0", "y0"])
        data2 = pd.read_csv(f'{DATA_PATH}/{expt_ids[i]}.requests_vs_time', header=None, names=["x0", "y0"])
        
        # Calculate and subtract the offset for each file
        offset1 = data1["x0"].iloc[0]
        offset2 = data2["x0"].iloc[0]

        data1["x0"] -= offset1
        data2["x0"] -= offset2

        # Plot data1 on ax1
        axes[0][i].plot(data1["x0"]-10, data1["y0"], color=C[i], marker='')
        axes[0][i].set_ylim(0, 6000)
        axes[0][i].legend([f'{legends[i]}'], loc="upper right")
        # if i == 0:
        #     axes[0][i].legend([f'{legends[i]}'], loc="upper left")
        
        # Plot data1 on ax1
        axes[1][i].plot(data2["x0"]-10, data2["y0"], color=C[i], marker='')
        
        axes[1][i].set_ylim(400, 850)
        # axes[1][i].legend([f'{legends[i]}'], loc="upper right")

        axes[1][i].set_xlabel("Time (ms)")

    axes[0][0].set_ylabel("1ms p99 Latency")
    axes[1][0].set_ylabel("Workload (req/ms)")
    # Adjust layout to prevent overlapping labels
    plt.tight_layout()

    # Set the x-axis limit for the entire figure
    plt.xlim([400, 800])

    return fig



def plot_http_latency_cdf():
    fig = plt.figure(figsize=(DEFAULT_WIDTH, 3.5))
    ax = fig.add_subplot()
    
    expt_ids = [ 
                '20240227-093038.463525',  
                '20240227-091402.231492', 
                '20240227-081315.731582',
                '20240227-081512.539719',
                ]
    # LOADSHIFTS = '500000:500000,700000:500000'
    labels = [
                f'{SYS} (80% Workload)',
                f'{SYS} (100% Workload)',
                'LWRR (80% Workload)',
                'LWRR (100% Workload)',
    ]
    line_styles = ['-', '--', '-.', ':']


    for i in range(4):
        data = pd.read_csv(f'{DATA_PATH}/{expt_ids[i]}.lat_cdf', header=None, names=["x0", "y0"])
        ax.plot(data['x0']/1000, data['y0'], line_styles[i], linewidth=3, label=f'{labels[i]}')
        
   
    plt.tight_layout()
    plt.ylim([0.9, 1.005])
    plt.ylabel("CDF")
    plt.xlabel("Latency (ms)")
    plt.grid(True, which='both', linestyle='--', linewidth=0.5)

    plt.legend(loc="lower right")


    return fig

def plot_http_workload_gap_cdf():
    fig = plt.figure(figsize=(DEFAULT_WIDTH, 3.5))
    ax = fig.add_subplot()
    
    expt_ids = [ 
                '20240227-093038.463525',  
                '20240227-091402.231492', 
                '20240227-081315.731582',
                '20240227-081512.539719',
                ]
    # LOADSHIFTS = '500000:500000,700000:500000'
    labels = [
                f'{SYS} (80% Workload)',
                f'{SYS} (100% Workload)',
                'LWRR (80% Workload)',
                'LWRR (100% Workload)',
    ]
    line_styles = ['-', '--', '-.', ':']


    for i in range(4):
        data = pd.read_csv(f'{DATA_PATH}/{expt_ids[i]}.workload_gap_cdf', header=None, names=["x0", "y0"])
        ax.plot(data['x0']*1000, data['y0'], line_styles[i], linewidth=3, label=f'{labels[i]}')
    
    ax.xaxis.set_major_formatter(tick.FuncFormatter(thousands))
   
    plt.tight_layout()
    # plt.ylim([0.9, 1.005])
    plt.ylabel("CDF")
    plt.xlabel("Workload Gap (PPS)")
    plt.grid(True, which='both', linestyle='--', linewidth=0.5)

    plt.legend(loc="lower right")


    return fig



def plot_redis_latency_cdf():
    fig = plt.figure(figsize=(DEFAULT_WIDTH, 2.3))
    ax = fig.add_subplot()
    plt.tight_layout()
    expt_ids = [ 
                '20240314-031720.063918',
                '20240314-065502.467400',  
                # '20240314-065353.148076', 
                
                # '20240314-054110.951432',
                ]
    # LOADSHIFTS = '500000:500000,700000:500000'
    labels = [
                'LWRR',
                f'{SYS}',
                # f'{SYS} (100% Workload)',
                # 'LWRR (100% Workload)',
    ]
    line_styles = ['-', '--', '-.', ':']


    for i in range(2):
        data = pd.read_csv(f'{DATA_PATH}/{expt_ids[i]}.lat_cdf', header=None, names=["x0", "y0"])
        ax.plot(data['x0'], data['y0'], line_styles[i], linewidth=3, label=f'{labels[i]}')
    
    ax.set_ylim([0.9, 1.005])
    ax.set_xlim([10, 20000])
    ax.set_ylabel("CDF")
    ax.set_xlabel("Latency (μs)")
    ax.grid(True, which='both', linestyle='--', linewidth=0.5)
    ax.legend(loc="lower right")
    ax.set_xscale('log')


    return fig

def plot_redis_workload_gap_cdf():
    fig = plt.figure(figsize=(DEFAULT_WIDTH, 3.5))
    ax = fig.add_subplot()
    
    expt_ids = [ 
                '20240314-065502.467400',  
                '20240314-065353.148076', 
                '20240314-031720.063918',
                '20240314-054110.951432',
                ]
    # LOADSHIFTS = '500000:500000,700000:500000'
    labels = [
                f'{SYS} (80% Workload)',
                f'{SYS} (100% Workload)',
                'LWRR (80% Workload)',
                'LWRR (100% Workload)',
    ]
    line_styles = ['-', '--', '-.', ':']


    for i in range(4):
        data = pd.read_csv(f'{DATA_PATH}/{expt_ids[i]}.workload_gap_cdf', header=None, names=["x0", "y0"])
        ax.plot(data['x0']*1000, data['y0'], line_styles[i], linewidth=3, label=f'{labels[i]}')
    
    ax.xaxis.set_major_formatter(tick.FuncFormatter(thousands))
   
    plt.tight_layout()
    # plt.ylim([0.9, 1.005])
    plt.ylabel("CDF")
    plt.xlabel("Workload Gap (PPS)")
    plt.grid(True, which='both', linestyle='--', linewidth=0.5)

    plt.legend(loc="lower right")


    return fig






def plot_micro_http_80p():
    fig, axes = plt.subplots(3, 2, figsize=(DEFAULT_WIDTH*1.7, 9))
    
    expt_ids = [ 
                '20240229-115625.820302',  
                '20240229-115725.071178', 
                ]
    for i in range(2):
        data_pps_be0 = pd.read_csv(f'{DATA_PATH}/{expt_ids[i]}.be0_pps_signal', header=None, names=["x0", "y0", "y1"])
        data_num_req = pd.read_csv(f'{DATA_PATH}/{expt_ids[i]}.sched_ms_req', header=None, names=["x0", "y0"])
        
        offset = data_num_req["x0"].iloc[0]
        data_num_req["x0"] -= offset
        data_pps_be0["x0"] -= data_pps_be0["x0"][0]
        
        axes[0][i].set_ylim(0, 1150000)
        x = data_pps_be0["x0"]/1000000
        y0 = data_pps_be0["y0"]*1000  
        y1 = data_pps_be0["y1"]*1000  
        

        axes[0][i].plot(data_num_req['x0']-5, data_num_req['y0']*1000, color='teal', marker='s', mfc='none', mec='teal', label='Total')
        axes[0][i].plot(x-5, abs(y1 - (y0 - y1)), color='darkorange', marker='s', mfc='none', mec='darkorange', label='Imbalance')
        
        axes[0][i].plot(x-5, y1, 
                    color='royalblue', marker='o', mfc='none', 
                    markersize=8, mec='royalblue', linestyle='-', linewidth=2,
                    alpha=0.8, label='Server 0')
        axes[0][i].plot(x-5, y0 - y1, 
                    color='xkcd:brick red', marker='^', mfc='none', 
                    markersize=8, mec='xkcd:brick red', linestyle='--', linewidth=2,
                    alpha=0.8, label='Server 1')
        
        axes[0][i].yaxis.set_major_formatter(tick.FuncFormatter(thousands))
        data_num_conn_10000 = pd.read_csv(f'{DATA_PATH}/{expt_ids[i]}.server_ms_num_conn_10000', header=None, names=["x0", "y0"])
        data_num_conn_10001 = pd.read_csv(f'{DATA_PATH}/{expt_ids[i]}.server_ms_num_conn_10001', header=None, names=["x0", "y0"])

        axes[1][i].plot(data_num_conn_10000['x0']-5, data_num_conn_10000['y0'], 
                color='royalblue', marker='o', mfc='none', 
                markersize=8, mec='royalblue', linestyle='-', linewidth=2,
                alpha=0.8, label='Server 0')

        axes[1][i].plot(data_num_conn_10001['x0']-5, data_num_conn_10001['y0'], 
                color='xkcd:brick red', marker='^', mfc='none', 
                markersize=8, mec='xkcd:brick red', linestyle='-', linewidth=2,
                alpha=0.8, label='Server 1')
        axes[1][i].set_ylim(48, 52)
            
        data_lat = pd.read_csv(f'{DATA_PATH}/{expt_ids[i]}.server_ms_avg_99p_lat', header=None, names=["x0", "y0", "y1", "y2"])
        axes[2][i].plot(data_lat['x0']-5, data_lat['y1'], color='teal', marker='s', mfc='none', mec='teal')
        
        axes[2][i].set_ylim(1, 30000)
        axes[2][i].set_yscale('log')
    axes[0][0].legend(loc="upper left", ncol=2)
    axes[1][0].legend(loc="upper left", ncol=2)
         
    axes[0][0].set_title("LWRR", fontweight='bold', fontsize=14)
    axes[0][1].set_title(f"{SYS}", fontweight='bold', fontsize=14)
    axes[0][0].set_ylabel("Workload (PPS)")
    axes[1][0].set_ylabel("# of Connections")
    axes[2][0].set_ylabel("p99 Latency (μs)")
    axes[2][0].set_xlabel("Time (ms)")
    axes[2][1].set_xlabel("Time (ms)")

    for ax_row in axes:
        for ax in ax_row:
            ax.set_xlim([0, 70])

    # plt.tight_layout()
    axes[0][0].axhline(y=450000, color='red', linestyle='-', linewidth=1)
    axes[0][1].axhline(y=450000, color='red', linestyle='-', linewidth=1)
    axes[0][0].text(x=3, y=460000, s='1 Server\nCapacity', color='red', verticalalignment='bottom')

    # axes[0][0].set_title(f"EXPT ID: {expt_ids}")
    plt.tight_layout()


    return fig

def plot_micro_http_100p():
    fig, axes = plt.subplots(3, 2, figsize=(DEFAULT_WIDTH*1.7, 9))
    
    expt_ids = ['20240229-120018.588133',
            '20240229-120049.923160']
    
    for i in range(2):
        data_pps_be0 = pd.read_csv(f'{DATA_PATH}/{expt_ids[i]}.be0_pps_signal', header=None, names=["x0", "y0", "y1"])
        data_num_req = pd.read_csv(f'{DATA_PATH}/{expt_ids[i]}.sched_ms_req', header=None, names=["x0", "y0"])
        
        offset = data_num_req["x0"].iloc[0]
        data_num_req["x0"] -= offset
        data_pps_be0["x0"] -= data_pps_be0["x0"][0]
        
        axes[0][i].set_ylim(0, 1150000)
        x = data_pps_be0["x0"]/1000000
        y0 = data_pps_be0["y0"]*1000  
        y1 = data_pps_be0["y1"]*1000  
        

        axes[0][i].plot(data_num_req['x0']-5, data_num_req['y0']*1000, color='teal', marker='s', mfc='none', mec='teal', label='Total')
        axes[0][i].plot(x-5, abs(y1 - (y0 - y1)), color='darkorange', marker='s', mfc='none', mec='darkorange', label='Imbalance')
        
        axes[0][i].plot(x-5, y1, 
                    color='royalblue', marker='o', mfc='none', 
                    markersize=8, mec='royalblue', linestyle='-', linewidth=2,
                    alpha=0.8, label='Server 0')
        axes[0][i].plot(x-5, y0 - y1, 
                    color='xkcd:brick red', marker='^', mfc='none', 
                    markersize=8, mec='xkcd:brick red', linestyle='--', linewidth=2,
                    alpha=0.8, label='Server 1')
        
        axes[0][i].yaxis.set_major_formatter(tick.FuncFormatter(thousands))
        
        data_num_conn_10000 = pd.read_csv(f'{DATA_PATH}/{expt_ids[i]}.server_ms_num_conn_10000', header=None, names=["x0", "y0"])
        data_num_conn_10001 = pd.read_csv(f'{DATA_PATH}/{expt_ids[i]}.server_ms_num_conn_10001', header=None, names=["x0", "y0"])

        axes[1][i].plot(data_num_conn_10000['x0']-5, data_num_conn_10000['y0'], 
                color='royalblue', marker='o', mfc='none', 
                markersize=8, mec='royalblue', linestyle='-', linewidth=2,
                alpha=0.8, label='Server 0')

        axes[1][i].plot(data_num_conn_10001['x0']-5, data_num_conn_10001['y0'], 
                color='xkcd:brick red', marker='^', mfc='none', 
                markersize=8, mec='xkcd:brick red', linestyle='-', linewidth=2,
                alpha=0.8, label='Server 1')
        axes[1][i].set_ylim(48, 52)
        
            
        data_lat = pd.read_csv(f'{DATA_PATH}/{expt_ids[i]}.server_ms_avg_99p_lat', header=None, names=["x0", "y0", "y1", "y2"])
        axes[2][i].plot(data_lat['x0']-5, data_lat['y1'], color='teal', marker='s', mfc='none', mec='teal')
        
        axes[2][i].set_ylim(1, 30000)
        axes[2][i].set_yscale('log')
        
    axes[0][0].set_title("LWRR", fontweight='bold', fontsize=14)
    axes[0][1].set_title(f"{SYS}", fontweight='bold', fontsize=14)
    axes[0][0].set_ylabel("Workload (PPS)")
    axes[1][0].set_ylabel("# of Connections")
    axes[2][0].set_ylabel("p99 Latency (μs)")
    axes[2][0].set_xlabel("Time (ms)")
    axes[2][1].set_xlabel("Time (ms)")

    for ax_row in axes:
        for ax in ax_row:
            ax.set_xlim([0, 70])

    # plt.tight_layout()
    axes[0][0].axhline(y=450000, color='red', linestyle='-', linewidth=1)
    axes[0][1].axhline(y=450000, color='red', linestyle='-', linewidth=1)
    # axes[0][0].set_title(f"EXPT ID: {expt_ids}")
    plt.tight_layout()


    return fig


def plot_tcp_porting_latency_linux_vs_sys():
    fig, (ax, ax2) = plt.subplots(2, 1, sharex=True, figsize=(0.5 * DEFAULT_WIDTH, 3.2),
                              gridspec_kw={'height_ratios': [1, 2]})  # Adjust height ratios here

    expt_ids = [ 
                '20240319-115124.303613', 
                '20240319-120511.007859',
                ]
    categories = ['Linux', f'{SYS}']
    values = np.array([[0.0, 0.0], [0.0, 0.0]])  
    min_values = np.array([[0.0, 0.0], [0.0, 0.0]])  
    max_values = np.array([[0.0, 0.0], [0.0, 0.0]])    
    for i in range(2):
        data = pd.read_csv(f'{DATA_PATH}/{expt_ids[i]}.mig_cpu_ovhd_avg_min_max_99p_stddev', header=None, names=[0, 1, 2])
        data /= 1000
        data = round(data, 1)
        # print(data)
        
        export_col = data[0]
        import_col = data[1]
        
        values[i][0] = export_col[0]
        values[i][1] = import_col[0]
        
        min_values[i][0] = export_col[1]
        min_values[i][1] = import_col[1]
        
        max_values[i][0] = export_col[2]
        max_values[i][1] = import_col[2]
        

    # Calculate the positive and negative errors relative to the values
    neg_errors = values - min_values  # Negative errors (distance to minimum)
    pos_errors = max_values - values  # Positive errors (distance to maximum)

    errors = np.array([
        [neg_errors[:, 0], neg_errors[:, 1]], 
        [pos_errors[:, 0], pos_errors[:, 1]]
        ])
    # print(errors)
    # print(values)
    # Width of a bar
    bar_width = 0.35

    # Positions of the bars
    ind = np.arange(len(categories))

    # print(values[:, 0], errors[:, 0])
    # Plotting bars for both subplots
    for a in [ax, ax2]:
        # Plotting bars for Type A
        bars_a = a.bar(ind - bar_width/2, values[:, 0], bar_width, label='TCP Export', yerr=errors[:, 0], capsize=5, color=lighten('skyblue'))
        # Plotting bars for Type B
        bars_b = a.bar(ind + bar_width/2, values[:, 1], bar_width, label='TCP Import', yerr=errors[:, 1], capsize=5, color=lighten('orange'))
        # Annotating bar values
        for bar in bars_a + bars_b:
            adjust_x = 0
            if bar.get_x() > 0.5:
                adjust_x = 0.07
            height = bar.get_height()
            a.annotate(f'{height:.1f}',
                    xy=(bar.get_x() + bar.get_width() / 2 - adjust_x, height/2),
                    xytext=(0, 3),  # 3 points vertical offset
                    textcoords="offset points",
                    ha='center', va='bottom', color='k', weight='bold')
                    #    bbox=dict(facecolor='white', edgecolor='none', alpha=0.5))
        

    # Set the y-axis limits for the bottom and top subplots
    ax.set_ylim(220, 275)  # For larger values
    ax2.set_ylim(0, 7)   # For smaller values

    # Hide the spines between ax and ax2
    ax.spines['bottom'].set_visible(False)
    ax2.spines['top'].set_visible(False)
    ax.xaxis.tick_top()
    ax.tick_params(labeltop=False)  # Don't show tick labels at the top
    ax2.xaxis.tick_bottom()

    # Adding diagonal lines to indicate the break in the y-axis
    d = .025  # Size of the diagonal lines
    kwargs = dict(transform=ax.transAxes, color='k', clip_on=False)
    ax.plot((-d, +d), (-d, +d*2.5), **kwargs, marker='', linestyle='-')        # Top-left diagonal
    ax.plot((1 - d, 1 + d), (-d, +d*2.5), **kwargs, marker='', linestyle='-')  # Top-right diagonal

    kwargs.update(transform=ax2.transAxes)  # Switching to the bottom axes
    ax2.plot((-d, +d), (1 - d, 1 + d), **kwargs, marker='', linestyle='-')  # Bottom-left diagonal
    ax2.plot((1 - d, 1 + d), (1 - d, 1 + d), **kwargs, marker='', linestyle='-')  # Bottom-right diagonal

    # Adding some text for labels, title, and custom x-axis tick labels, etc.
    ax2.set_xticks(ind)
    ax2.set_xticklabels(categories)
    # ax.set_title('Values by category and type with cut y-axis')

    # Place a legend on the upper subplot
    ax.legend(loc="upper right")

    # Creating a centralized y-axis label instead of two
    fig.text(-0.02, 0.5, 'Latency (μs)', va='center', rotation='vertical')

    ax.xaxis.set_ticks_position('none')  # This line removes the ticks from the top x-axis
    ax.grid(True, which='both', linestyle='--', linewidth=0.5)
    ax2.grid(True, which='both', linestyle='--', linewidth=0.5)
    plt.tight_layout()
    plt.subplots_adjust(hspace=0.05)  # Adjust the space between the two subplots

    return fig

# def plot_mig_delay_vs_state_size():
#     fig, ax = plt.subplots(figsize=(0.72 * DEFAULT_WIDTH, 3))
#     expt_ids = [
#             "20240318-093700.299930",
#             "20240320-123038.748153",
#             "20240320-122522.155786",
#             "20240318-093754.379579",
#         ]
#     categories = ["0", "16", "32", "64"]
#     # Custom colors for the bars
#     colors = ['orange', 'skyblue']
#     patterns = ['', '\\\\\\', '///', '++', 'oo', 'xx', '**']  # Different patterns for all columns

#     values = []

#     for expt_id in expt_ids:
#         # Construct the file path
#         file_path = f'{DATA_PATH}/{expt_id}.mig_delay_avg_min_max'
#         df = pd.read_csv(file_path, header=None)
#         step_values = [round((df.iloc[0, i]/1000), 1) for i in range(7)]
#         # print(step_values)

#         values.append(step_values)

#     n_bars = len(values[0])
#     ind = np.arange(len(expt_ids))
#     width = 0.6

#     # Custom legend handles for two categories
#     # legend_cpu_ovhd = []
#     # legend_net_latency = []
#     bottoms = np.zeros(len(values))
#     # Plotting
#     for i in range(n_bars):
#         group_values = [sublist[i] for sublist in values]
#         bar = ax.bar(ind, group_values, bottom=bottoms, hatch=patterns[i], width=width,
#                     color=colors[i % 2], label=f'Step {i+1}')
#         bottoms += np.array(group_values)

#         # Creating custom handles for legend
#         # if i % 2 == 0:
#         #     legend_cpu_ovhd.append(mpatches.Patch(facecolor=colors[i % 2], hatch=patterns[i], label=f'Step {i+1}'))
#         # else:
#         #     legend_net_latency.append(mpatches.Patch(facecolor=colors[i % 2], hatch=patterns[i], label=f'Step {i+1}'))

#     # Adding two separate legends
#     # legend1 = ax.legend(handles=legend_cpu_ovhd, title='CPU Overheads', loc='upper left')
#     # ax.add_artist(legend1)  # Add the first legend back after the second legend is created
#     # legend2 = ax.legend(handles=legend_net_latency, title='Network Latency', loc='upper center')
#     ax.set_xticks(ind)
#     ax.set_xticklabels(categories)

#     ax.set_ylabel('Migration Delay (μs)')
#     ax.set_xlabel('State Size (KB)')

#     plt.tight_layout()
#     return fig


def plot_state_size_vs_mig_latency():
    SHARE_Y = True
    fig, axes = plt.subplots(1, 2, figsize=(DEFAULT_WIDTH, 2.3), sharey=SHARE_Y)  # Two rows, one column, shared x-axis

    colors = ['firebrick', 'lightcoral', 'forestgreen',]
    hatch_patterns = ['/', '\\', 'x', '+', '|']  # Add diverse hatch patterns
    labels = [
        "Origin CPU",
        "Target CPU",
        "Network Latency",
        
    ]
    expt_ids = [
                "20241209-065306.927851", # 0KB
                "20241209-065221.131657", # 16KB
                "20241209-065144.964379", # 32KB
                "20241209-065056.347472", # 64KB
                "20241209-064919.683471", # 128KB
                ]
    categories = ["0", "16", "32", "64", "128"]
    # Custom colors for the bars
    values = []

    for expt_id in expt_ids:
        # Construct the file path
        file_path = f'{DATA_PATH}/{expt_id}.mig_delay_avg_minmax_stddev'
        df = pd.read_csv(file_path, header=None)
        step_values = [
            round((df.iloc[0, 0] + df.iloc[0, 4]) / 1000, 1),  # Combine entry [0] and [4]
            round((df.iloc[0, 2] + df.iloc[0, 6]) / 1000, 1),  # Combine entry [2] and [6]
            round((df.iloc[0, 1] + df.iloc[0, 3] + df.iloc[0, 5]) / 1000, 1)  # Combine entry [1], [3], [5]
        ]
        values.append(step_values)

    n_bars = len(values[0])
    ind = np.arange(len(expt_ids))
    width = 0.6

    # if SHARE_Y:
    #     axins = inset_axes(axes[0], width="20%", height="55%", loc='center',
    #                     bbox_to_anchor=(-0.27, 0, 1, 1), bbox_transform=axes[0].transAxes)
    # width = 30% of parent_bbox, height = 30%, located at upper left

    # Custom legend handles for two categories
    bottoms = np.zeros(len(values))
    # Plotting
    for i in range(n_bars):
        group_values = [sublist[i] for sublist in values]
        axes[0].bar(ind, group_values, bottom=bottoms, width=width, color=lighten(colors[i]), label=labels[i], hatch=hatch_patterns[i])
        # if SHARE_Y:
        #     axins.bar(ind, group_values, bottom=bottoms, width=width, color=colors[i], hatch=hatch_patterns[i])
        bottoms += np.array(group_values)
        
    axes[0].set_xticks(ind)
    axes[0].set_xticklabels(categories)
    axes[0].set_ylabel('Migration Latency (μs)')
    # axes[1].set_ylabel('Migration Delay (μs)')
    # Add a shared y-axis label
    # fig.text(
    #     -0.02,  # x-coordinate (horizontal position)
    #     0.5,   # y-coordinate (vertical position, 0.5 is the middle)
    #     'Migration Latency (μs)',  # Label text
    #     va='center',  # Vertical alignment
    #     rotation='vertical'  # Rotate the text vertically
    # )
    expt_ids = [
                "20241209-061450.984562", # 0KB
                "20241209-061609.116149", # 16KB
                "20241209-061703.735981", # 32KB
                "20241209-061739.852080", # 64KB
                "20241209-062125.039885", # 128KB
                ]
    values = []
    for expt_id in expt_ids:
        # Construct the file path
        file_path = f'{DATA_PATH}/{expt_id}.mig_delay_avg_minmax_stddev'
        df = pd.read_csv(file_path, header=None)
        step_values = [
            round((df.iloc[0, 0] + df.iloc[0, 4]) / 1000, 1),  # Combine entry [0] and [4]
            round((df.iloc[0, 2] + df.iloc[0, 6]) / 1000, 1),  # Combine entry [2] and [6]
            round((df.iloc[0, 1] + df.iloc[0, 3] + df.iloc[0, 5]) / 1000, 1)  # Combine entry [1], [3], [5]
        ]
        values.append(step_values)

    n_bars = len(values[0])
    ind = np.arange(len(expt_ids))
    width = 0.6

    bottoms = np.zeros(len(values))

    for i in range(n_bars):
        group_values = [sublist[i] for sublist in values]
        axes[1].bar(ind, group_values, bottom=bottoms, width=width, color=lighten(colors[i]), hatch=hatch_patterns[i])
        bottoms += np.array(group_values)


    axes[0].set_xticks(ind)
    axes[0].set_xticklabels(categories)
    axes[1].set_xticks(ind)
    axes[1].set_xticklabels(categories)
    axes[0].set_xlabel('Additional State Size (KB)')
    axes[1].set_xlabel('Additional State Size (KB)')
    if SHARE_Y:
        axes[0].set_ylim([0, 65])
        axes[1].set_ylim([0, 65] )

    # x1, x2, y1, y2 = -0.4, 0.4, 0, 12  # Specify the limits of your zoomed area

    # if SHARE_Y:
    #     axins.set_xlim(x1, x2)
    #     axins.set_ylim(y1, y2)
    #     axins.set_xticklabels('')
    #     # axins.set_yticks(np.arange(0, 0.61, 0.3))
    #     # axins.set_yticklabels('')
    #     axins.set_xticks([])

    #     # Draw lines connecting the main plot and the inset
    #     mark_inset(axes[0], axins, loc1=2, loc2=4, fc="none", ec="0.7")

    axes[0].grid(axis='y', linestyle='--', alpha=0.7)
    axes[1].grid(axis='y', linestyle='--', alpha=0.7)

    # Add labels "TCP" and "TLS" to the upper-right corners
    axes[0].text(
        0.17, 0.93,  # Position: near the upper-right corner
        "TCP",  # Text
        transform=axes[0].transAxes,  # Use axes-relative coordinates
        ha='right', va='top',  # Align text
        bbox=dict(facecolor='white', edgecolor='black', alpha=0.8),  # White box
        fontsize=10, fontweight='bold'  # Font size and weight
    )

    axes[1].text(
        0.32, 0.93,  # Position: near the upper-right corner
        "TCP+TLS",  # Text
        transform=axes[1].transAxes,  # Use axes-relative coordinates
        ha='right', va='top',  # Align text
        bbox=dict(facecolor='white', edgecolor='black', alpha=0.8),  # White box
        fontsize=10, fontweight='bold'  # Font size and weight
    )

    # Add a shared legend for both plots
    legend = fig.legend(
        # labels,  # Use the labels for the combined steps
        loc="upper center",  # Place the legend at the top-center of the figure
        bbox_to_anchor=(0.5, 1.1),  # Adjust the position: center horizontally, slightly above the plots
        ncol=3,  # Number of columns in the legend
        frameon=True,  # Add a frame around the legend
        # title="Migration Steps"  # Optional: Add a title to the legend
    )

    # Adjust spacing between subplots
    # plt.subplots_adjust(hspace=-1.5)  # Reduce the vertical spacing between subplots
    plt.tight_layout()


    return fig

def plot_blocking_vs_non_blocking():
    fig = plt.figure(figsize=(DEFAULT_WIDTH, 2.3))
    ax = fig.add_subplot()
    data = pd.read_csv(f'{DATA_PATH}/blocking_vs_non_blocking.csv', header=None)
    num_columns = len(data.columns)
    column_names = [f'x{int(i/2)}' if i % 2 == 0 else f'y{int(i/2)}' for i in range(num_columns)]
    data.columns = column_names
    
    # Loop over each column and sort the data based on y-values
    labels = [f"{SYS}-Drop", f"{SYS}", "W/o migration" ]
    
    INCLUDE_WO_MIGRATION = False
    for i in range(int(num_columns/2)):
        if not INCLUDE_WO_MIGRATION and i == labels.index("W/o migration"):
            continue
        column_x = f'x{i}'
        column_y = f'y{i}'
        # ax.plot(data[column_x], data[column_y], label=f"{i+1}", marker='o', color=C[i])
        ax.plot(data[column_x], data[column_y], marker='o', color=C[int(i%4)], label=labels[i], markevery=0.1)

    plt.ylabel("p99 Latency (μs)")
    plt.xlabel("Throughput (reqs/s)")
    plt.ylim([0, 1500])
    plt.legend(ncol=1, loc="upper center")
    # plt.title("Server's MAX throughput")
    set_zeros()

    ax.xaxis.set_major_formatter(tick.FuncFormatter(thousands))

    return fig

def plot_staticl4_vs_sys_step():
    fig, axes = plt.subplots(2, 3, figsize=(DEFAULT_WIDTH*2.3, 5))
    
    expt_ids = ['20240326-055550.727540',
                '20240404-090058.707324',
                '20240326-055436.331924',]
    for i in range(3):
        data_pps_be0 = pd.read_csv(f'{DATA_PATH}/{expt_ids[i]}.be0_pps_signal', header=None, names=["x0", "y0", "y1"])
        data_num_req = pd.read_csv(f'{DATA_PATH}/{expt_ids[i]}.sched_ms_req', header=None, names=["x0", "y0"])
        
        offset = data_num_req["x0"].iloc[0]
        data_num_req["x0"] -= offset
        data_pps_be0["x0"] -= data_pps_be0["x0"][0]
        
        axes[0][i].set_ylim(0, 1000000)
        x = data_pps_be0["x0"]/1000000
        y0 = data_pps_be0["y0"]*1000  
        y1 = data_pps_be0["y1"]*1000  
        

        axes[0][i].plot(x-10, y1, 
                color='blue', marker='o', mfc='none', 
                markersize=8, mec='blue', linestyle='-', linewidth=3,
                alpha=0.8, label='Server 0', markevery=0.1)
        axes[0][i].plot(x-10, y0 - y1, 
                    color='xkcd:brick red', marker='^', mfc='none', 
                    markersize=8, mec='xkcd:brick red', linestyle='-', linewidth=3,
                    alpha=0.8, label='Server 1', markevery=0.1)
        axes[0][i].plot(data_num_req['x0']-10, data_num_req['y0']*1000, color='teal', linestyle="--", label='Total', marker='', linewidth=3)
        # axes[0][i].plot(x-10, abs(y1 - (y0 - y1)), color='orange', linestyle="--", label='Imbalance', marker='')
        
        axes[0][i].yaxis.set_major_formatter(tick.FuncFormatter(thousands))
        data_num_conn_10000 = pd.read_csv(f'{DATA_PATH}/{expt_ids[i]}.server_ms_num_conn_10000', header=None, names=["x0", "y0"])
        data_num_conn_10001 = pd.read_csv(f'{DATA_PATH}/{expt_ids[i]}.server_ms_num_conn_10001', header=None, names=["x0", "y0"])

        # axes[1][i].plot(data_num_conn_10000['x0']-10, data_num_conn_10000['y0'], 
        #     color='blue', marker='o', mfc='none', 
        #     markersize=8, mec='blue', linestyle='-', linewidth=2,
        #         alpha=0.8, label='Server 0')

        # axes[1][i].plot(data_num_conn_10001['x0']-10, data_num_conn_10001['y0'], 
        #     color='xkcd:brick red', marker='^', mfc='none', 
        #     markersize=8, mec='xkcd:brick red', linestyle='-', linewidth=2,
        #         alpha=0.8, label='Server 1')
        # axes[1][i].set_ylim(47.5, 52.5)
            
        data_lat = pd.read_csv(f'{DATA_PATH}/{expt_ids[i]}.server_ms_avg_99p_lat', header=None, names=["x0", "y0", "y1", "y2"])
        axes[1][i].plot(data_lat['x0']-10, data_lat['y1'], color='teal', marker='', mfc='none', mec='teal', linewidth=3)
        
        axes[1][i].set_ylim(1, 30000)
        axes[1][i].set_yscale('log')
    axes[0][0].legend(loc="upper left", ncol=2)
    # axes[1][0].legend(loc="upper left", ncol=2)
            
    axes[0][0].set_title("LWRR", fontweight='bold', fontsize=14)
    axes[0][1].set_title(f"{SYS}-Reactive", fontweight='bold', fontsize=14)
    axes[0][2].set_title(f"{SYS}", fontweight='bold', fontsize=14)

    axes[0][0].set_ylabel("Workload (reqs/s)")
    # axes[1][0].set_ylabel("# of Connections")
    axes[1][0].set_ylabel("p99 Latency (μs)")

    axes[1][0].set_xlabel("Time (ms)")
    axes[1][1].set_xlabel("Time (ms)")
    axes[1][2].set_xlabel("Time (ms)")

    for ax_row in axes:
        for ax in ax_row:
            ax.set_xlim([0, 100])

    # plt.tight_layout()
    axes[0][0].axhline(y=450000, color='red', linestyle='--', linewidth=1)
    axes[0][1].axhline(y=450000, color='red', linestyle='--', linewidth=1)
    axes[0][2].axhline(y=450000, color='red', linestyle='--', linewidth=1)
    
    axes[0][0].text(x=3, y=460000, s='Single Server\nCapacity', color='red', verticalalignment='bottom')

    # axes[0][0].set_title(f"EXPT ID: {expt_ids}")
    plt.tight_layout()


    return fig

def plot_main_eval_http_latency_cdf():
    fig = plt.figure(figsize=(DEFAULT_WIDTH, 2.3))
    ax = fig.add_subplot()
    plt.tight_layout()
    expt_ids = [ 
                '20240402-015155.555232',  
                '20240402-014907.807561',
                '20240402-013717.931975', 
                ]
    labels = [
                'LWRR',
                f'{SYS}-Reactive',
                f'{SYS}-Proactive',
    ]
    line_styles = ['-', '--', '-.', ':']

    # axins = inset_axes(ax, width="25%", height="30%", loc='center', 
    #                bbox_to_anchor=(-0.1, -0.2, 1.1, 1.1), bbox_transform=ax.transAxes)  # width = 30% of parent_bbox, height = 30%, located at upper left

    for i in range(3):
        data = pd.read_csv(f'{DATA_PATH}/{expt_ids[i]}.lat_cdf', header=None, names=["x0", "y0"])
        ax.plot(data['x0'], data['y0'], line_styles[i], linewidth=3, label=f'{labels[i]}')
        # axins.plot(data['x0']/1000, data['y0'], line_styles[i], linewidth=3, label=f'{labels[i]}')
   
    # x1, x2, y1, y2 = -0.1, 2.1, 0.995, 1.0005  # Specify the limits of your zoomed area

    # axins.set_xlim(x1, x2)
    # axins.set_ylim(y1, y2)
    # axins.set_xticks([0, 1, 2])
    # axins.set_xticklabels(['0', '1', '2'])
    # mark_inset(ax, axins, loc1=1, loc2=3, fc="none", ec="0.5")

    ax.set_ylim([0.9, 1.005])
    ax.set_xlim([10, 17000])
    ax.set_ylabel("CDF")
    ax.set_xlabel("Latency (μs)")
    ax.grid(True, which='both', linestyle='--', linewidth=0.5)
    ax.legend(loc="lower right")
    ax.set_xscale('log')

    return fig

def plot_main_eval_http_workload_gap_cdf():
    fig = plt.figure(figsize=(DEFAULT_WIDTH, 3.5))
    ax = fig.add_subplot()
    
    expt_ids = [ 
                '20240402-015155.555232',  
                '20240402-014907.807561',
                '20240402-013717.931975', 
                ]
    labels = [
                'LWRR',
                f'{SYS}-Reactive',
                f'{SYS}-Proactive',
    ]
    line_styles = ['-', '--', '-.', ':']


    for i in range(3):
        data = pd.read_csv(f'{DATA_PATH}/{expt_ids[i]}.workload_gap_cdf', header=None, names=["x0", "y0"])
        ax.plot(data['x0']*1000, data['y0'], line_styles[i], linewidth=3, label=f'{labels[i]}')
    
    ax.xaxis.set_major_formatter(tick.FuncFormatter(thousands))
   
    plt.tight_layout()
    # plt.ylim([0.9, 1.005])
    plt.ylabel("CDF")
    plt.xlabel("Workload Gap (PPS)")
    plt.grid(True, which='both', linestyle='--', linewidth=0.5)

    plt.legend(loc="lower right")


    return fig



def plot_main_eval_redis_latency_cdf():
    fig = plt.figure(figsize=(DEFAULT_WIDTH, 3.5))
    ax = fig.add_subplot()
    plt.tight_layout()

    expt_ids = [ 
                '20240402-131624.467460',  
                '20240402-131501.722961',
                '20240402-130554.226903',
                ]
    labels = [
                'LWRR',
                f'{SYS}-Reactive',
                f'{SYS}-Proactive',
    ]
    line_styles = ['-', '--', '-.', ':']

    axins = inset_axes(ax, width="25%", height="30%", loc='center', 
                   bbox_to_anchor=(0, 0, 1, 1), bbox_transform=ax.transAxes)  # width = 30% of parent_bbox, height = 30%, located at upper left
    for i in range(3):
        data = pd.read_csv(f'{DATA_PATH}/{expt_ids[i]}.lat_cdf', header=None, names=["x0", "y0"])
        ax.plot(data['x0']/1000, data['y0'], line_styles[i], linewidth=3, label=f'{labels[i]}')
        axins.plot(data['x0']/1000, data['y0'], line_styles[i], linewidth=3, label=f'{labels[i]}')
    
    x1, x2, y1, y2 = -0.1, 2.1, 0.995, 1.0005  # Specify the limits of your zoomed area

    axins.set_xlim(x1, x2)
    axins.set_ylim(y1, y2)
    axins.set_xticks([0, 2])
    axins.set_xticklabels(['0', '2'])
    mark_inset(ax, axins, loc1=1, loc2=3, fc="none", ec="0.5")
   
    ax.set_ylim([0.9, 1.005])
    ax.set_ylabel("CDF")
    ax.set_xlabel("Latency (ms)")
    ax.grid(True, which='both', linestyle='--', linewidth=0.5)

    ax.legend(loc="lower right")

    

    return fig

def plot_main_eval_redis_workload_gap_cdf():
    fig = plt.figure(figsize=(DEFAULT_WIDTH, 3.5))
    ax = fig.add_subplot()
    
    expt_ids = [ 
                '20240402-131624.467460',  
                '20240402-131501.722961',
                '20240402-130554.226903',
                ]
    labels = [
                'LWRR',
                f'{SYS}-Reactive',
                f'{SYS}-Proactive',
    ]
    line_styles = ['-', '--', '-.', ':']


    for i in range(3):
        data = pd.read_csv(f'{DATA_PATH}/{expt_ids[i]}.workload_gap_cdf', header=None, names=["x0", "y0"])
        ax.plot(data['x0']*1000, data['y0'], line_styles[i], linewidth=3, label=f'{labels[i]}')
    
    ax.xaxis.set_major_formatter(tick.FuncFormatter(thousands))
   
    plt.tight_layout()
    # plt.ylim([0.9, 1.005])
    plt.ylabel("CDF")
    plt.xlabel("Workload Gap (PPS)")
    plt.grid(True, which='both', linestyle='--', linewidth=0.5)

    plt.legend(loc="lower right")


    return fig



def plot_four_servers_latency_cdf():
    fig = plt.figure(figsize=(DEFAULT_WIDTH, 2.3))
    ax = fig.add_subplot()
    plt.tight_layout()
    expt_ids = [ 
            '20240410-143658.499102',  
            '20240410-143027.447397', 
            '20240410-140807.263885',
            ]
    labels = [
                'LWRR',
                f'{SYS} (round-robin)',
                f'{SYS} (load-aware)',
    ]
    line_styles = ['-', '--', '-.', ':']
    # axins = inset_axes(ax, width="25%", height="30%", loc='center', 
    #                 bbox_to_anchor=(-0.1, -0.2, 1.1, 1.1), bbox_transform=ax.transAxes)  # width = 30% of parent_bbox, height = 30%, located at upper left

    for i in range(3):
        data = pd.read_csv(f'{DATA_PATH}/{expt_ids[i]}.lat_cdf', header=None, names=["x0", "y0"])
        ax.plot(data['x0'], data['y0'], line_styles[i], linewidth=3, label=f'{labels[i]}')
        # axins.plot(data['x0'], data['y0'], line_styles[i], linewidth=3, label=f'{labels[i]}')
        
    # x1, x2, y1, y2 = -0.1, 4.1, 0.995, 1.0005  # Specify the limits of your zoomed area

    # axins.set_xlim(x1, x2)
    # axins.set_ylim(y1, y2)
    # axins.set_xticks([0, 2, 4])
    # axins.set_xticklabels(['0', '2', '4'])
    # mark_inset(ax, axins, loc1=1, loc2=3, fc="none", ec="0.5")

    ax.set_ylim([0.9, 1.005])
    ax.set_xlim([10, 17000])
    ax.set_ylabel("CDF")
    ax.set_xlabel("Latency (μs)")
    ax.grid(True, which='both', linestyle='--', linewidth=0.5)

    ax.legend(loc="lower right")

    ax.set_xscale('log')


    return fig


def plot_motivation():
    DATA = """
        2,641838,891819,1141016
        4,1141930,1639709,2433754
        6,1440533,2186639,3772325
        8,1788690,2633514,5063924
        10,1887703,2881083,6262021
        12,2036920,3378777,7560197
        """.strip()
    x, y1, y2, y3 = [], [], [], []
    reader = csv.reader(io.StringIO(DATA))
    for row in reader:
        if not row: 
            continue
        a, b, c, d = map(float, row)
        x.append(a); y1.append(b); y2.append(c); y3.append(d)

    fig, ax = plt.subplots(figsize=(DEFAULT_WIDTH, 2.6))
    n = len(x)
    indices = range(n)

    total_bar_width = 0.8
    bar_w = total_bar_width / 3
    patterns = ['-', '/', '\\'] 
    ax.bar([i - bar_w for i in indices], y1, width=bar_w, label='Zipf-1.2', color=lighten(C[0]), hatch=patterns[0])
    ax.bar([i for i in indices], y2, width=bar_w, label='Zipf-0.9', color=lighten(C[1]), hatch=patterns[1])
    ax.bar([i + bar_w for i in indices], y3, width=bar_w, label='Uniform', color=lighten(C[2]), hatch=patterns[2])

    ax.set_xticks(list(indices))
    ax.set_xticklabels([str(int(v)) for v in x])

    ax.set_xlabel('Number of Servers')
    ax.set_ylabel('Throughput (reqs/s)')
    ax.yaxis.set_major_formatter(tick.FuncFormatter(millions))
    
    ax.legend()
    ax.grid(axis='y', linestyle='--', alpha=0.3)
    plt.tight_layout()
    return fig


def plot_redis_maintenance():
    fig = plt.figure(figsize=(DEFAULT_WIDTH, 2.3))
    ax = fig.add_subplot()
    file_paths = [
                
                f"{DATA_PATH}/20241209-060541.580037.client",
                f"{DATA_PATH}/20241210-021058.772580.client",
    ]

    labels = [
                f'Without {SYS}',
                f'With {SYS}',
                
    ]
    markers = [
        '^', 'o' 
    ]
    # line_styles = ['-', '--', '-.', ':']
    for i, file_path in enumerate(file_paths):
        # Initialize lists to store x and y values
        x_values = []
        y_values = []


        # Read the file and process the lines
        with open(file_path, "r") as file:
            line_number = 1
            for line in file:
                if line.startswith("***GET"):
                    # Split the line by comma and extract the second value
                    parts = line.strip().split(",")
                    if len(parts) > 1:
                        y_value = float(parts[1])  # Convert the second column to a float
                        y_values.append(y_value)
                        if i == 0:
                            x_values.append(line_number*20 - 5020)
                        else:
                            x_values.append(line_number*20 - 5020)
                        line_number += 1
        # Plot the data with the file path as the label
        ax.plot(x_values, y_values, marker=markers[i], mfc='none', 
                    markersize=8, linestyle="-", label=f'{labels[i]}')

    # Add labels, title, and legend
    ax.set_xlabel('Time (ms)')
    ax.set_ylabel('Throughput (reqs/s)')
    # ax.set_xlim([10, 210])
    ax.set_ylim([0, 250000])

    # ax.grid(True, linestyle='--', alpha=0.7)
    ax.legend(loc="lower right")
    ax.set_xlim(-150,410)

    ax.yaxis.set_major_formatter(tick.FuncFormatter(thousands))
    # Display the plot
    # plt.xscale('log')
    
    
    # Add vertical dotted line and annotation
    ax.axvline(x=0, color='gray', linestyle='--', linewidth=1.5)
    # ax.annotate(
    #     "Server Shutdown",
    #     xy=(0, 0),
    #     xytext=(-50, 50000),  # Adjust position of text
    #     textcoords='offset points',
    #     arrowprops=dict(facecolor='black', arrowstyle='->'),
    #     fontsize=10,
    #     ha='center'
    # )
    
    plt.tight_layout()

    return fig


def plot_main_eval_p99():
    """
    Bar plot comparing Baseline vs Capybara 99p latency across different workload distributions.
    Two subplots: (a) All flows, (b) Short flows only.
    """
    # Column order: Baseline (Uniform, 0.9, 1.0, 1.2), Capybara (Uniform, 0.9, 1.0, 1.2)
    col_names = ['B_Uniform', 'B_0.9', 'B_1.0', 'B_1.2', 'C_Uniform', 'C_0.9', 'C_1.0', 'C_1.2']

    # Read both CSV files (no header)
    df_all = pd.read_csv(f'{DATA_PATH}/main_eval.csv', header=None, names=col_names)
    df_short = pd.read_csv(f'{DATA_PATH}/main_eval_shortflow.csv', header=None, names=col_names)

    # X-axis labels
    x_labels = ['Uniform', 'Zipf-0.9', 'Zipf-1.0', 'Zipf-1.2']

    # Column names for baseline and capybara
    baseline_cols = ['B_Uniform', 'B_0.9', 'B_1.0', 'B_1.2']
    capybara_cols = ['C_Uniform', 'C_0.9', 'C_1.0', 'C_1.2']

    # Calculate means for all flows
    baseline_means_all = [df_all[col].mean() for col in baseline_cols]
    capybara_means_all = [df_all[col].mean() for col in capybara_cols]

    # Calculate means for short flows
    baseline_means_short = [df_short[col].mean() for col in baseline_cols]
    capybara_means_short = [df_short[col].mean() for col in capybara_cols]

    # Find global max for consistent y-axis
    all_values = baseline_means_all + capybara_means_all + baseline_means_short + capybara_means_short
    y_max = max(all_values) * 1.3  # 30% headroom

    # Create figure with two subplots (single column layout)
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(DEFAULT_WIDTH, 2.5))

    x = np.arange(len(x_labels))
    bar_width = 0.35

    # Subplot 1: All flows
    ax1.bar(x - bar_width/2, baseline_means_all, bar_width,
            label=BASELINE, color=lighten(COMPARE1_C), hatch='/')
    ax1.bar(x + bar_width/2, capybara_means_all, bar_width,
            label=f'{SYS}', color=lighten(SYS_C), hatch='\\')
    ax1.set_yscale('log')
    ax1.set_ylim(10, y_max)
    ax1.set_ylabel('p99 Latency (μs)')
    ax1.set_xticks(x)
    ax1.set_xticklabels(x_labels, fontsize=10)
    ax1.set_xlabel('Workload Distribution')
    ax1.set_title('(a) All Flows')
    ax1.yaxis.grid(True, which='both', linestyle='--', alpha=0.4)
    ax1.set_axisbelow(True)

    # Subplot 2: Short flows only
    ax2.bar(x - bar_width/2, baseline_means_short, bar_width,
            label=BASELINE, color=lighten(COMPARE1_C), hatch='/')
    ax2.bar(x + bar_width/2, capybara_means_short, bar_width,
            label=f'{SYS}', color=lighten(SYS_C), hatch='\\')
    ax2.set_yscale('log')
    ax2.set_ylim(10, y_max)
    ax2.set_xticks(x)
    ax2.set_xticklabels(x_labels, fontsize=10)
    ax2.set_xlabel('Workload Distribution')
    ax2.set_title('(b) Short Flows Only')
    ax2.yaxis.grid(True, which='both', linestyle='--', alpha=0.4)
    ax2.set_axisbelow(True)

    # Legend at top center, outside the plot
    handles, labels = ax1.get_legend_handles_labels()
    fig.legend(handles, labels, loc='upper center', ncol=2, fontsize=10,
               bbox_to_anchor=(0.5, 1.02))

    plt.tight_layout(rect=[0, 0, 1, 0.92])
    return fig


def plot_connection_scalability():
    DATA = """
        144,2397182.27,2396968.84,2398267.71
        1440,2395879.55,2387818.27,2395172.47
        2880,2386851.75,2386944.98,2384508.39
        7200,2369345.08,2366314.46,2366678.65
        14400,2330352.85,2346682.37,2341655.5
        28800,2299310.13,2298482.28,2296571.31
        43200,2261746.04,2259827.41,2259678.23
        57600,2225685.44,2226560.42,2225530.38
        72000,2194804.78,2195784.71,2072022.62
        115200,2068473.22,2070144.35,1531549.29
        158400,1919954.35,1911140.97,1160908.85
        193536,1742992.5,1746512.82,970191.26
    """

    x, y1, y2, y3 = [], [], [], []
    reader = csv.reader(io.StringIO(DATA.strip()))
    for row in reader:
        if not row:
            continue
        a, b, c, d = map(float, row)
        x.append(a); y1.append(b); y2.append(c); y3.append(d)

    fig = plt.figure(figsize=(DEFAULT_WIDTH, 2.3))
    ax = fig.add_subplot()

    ax.plot(x, y1, color='blue', marker='X', markersize=9, label='Demikernel', linestyle='-', linewidth=3)
    ax.plot(x, y2, color='red', marker='o', markersize=6, label=f'{SYS}-Switch',
            linestyle=(0, (8, 2)), linewidth=2)
    ax.plot(x, y3, color='green', marker='^', markersize=6, label=f'{SYS}',
            linestyle='-.', linewidth=1)

    ax.set_xlabel('Number of Connections')
    ax.set_ylabel('Throughput (reqs/s)')
    ax.grid(True, which='both', linestyle='--', alpha=0.4)
    ax.legend(loc='best')

    ax.set_xscale('log')
    ax.set_xticks([100, 1000, 10000, 100000, 200000])
    ax.set_xticklabels(["100", "1K", "10K", "100K", "200K"])

    ax.set_xlim(100, 300000)
    ax.set_ylim(1, 2700000)
    ax.yaxis.set_major_formatter(tick.FuncFormatter(millions))

    plt.tight_layout()
    return fig

################################################################################

# from multiprocessing import Pool
import argparse
import sys

def generate_graph(graph_name):
    print(graph_name)
    if not graph_name.startswith('plot_'):
        graph_name = 'plot_' + graph_name
    setup()
    fig = getattr(sys.modules[__name__], graph_name)()
    fig.savefig('graphs/%s.pdf' % graph_name.replace('plot_', ''), bbox_inches='tight')
    plt.close()

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('plots', nargs='*', type=str,
                        help="space-separated list of plot_X functions to run "
                             "(with or without 'plot_')")
    args = parser.parse_args()

    plots = args.plots
    if not plots:
        plots = [m for m in dir(sys.modules[__name__]) if m.startswith('plot_')]

    # with Pool() as p:
    #     list(p.imap_unordered(generate_graph, plots))

    # print("plot_sim_congestion")
    # plot_sim_congestion()
    
    for p in plots:
        generate_graph(p)


if __name__ == '__main__':
    main()
