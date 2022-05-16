#  FCCM Demo 2022: On-Line Training from Streaming Data with Concept Drift on FPGA
## Introduction
In dynamic environments, the inputs to machine learning models may exhibit statistical changes over time, through what is called concept drift. Incremental training can allow machine learning models to adapt to changing conditions by continuously updating network parameters. In the context of FPGA-based accelerators however, online incremental learning is challenging due to resource and communication constraints, as well as the absence of labelled training data.

As an example, in this demo we consider gradual rotation and other manipulations on MNIST digits

## This Demo
In this demo, we present an FPGA-based implementation of an online training accelerator to dynamically track concept drift as inference is performed. It is online, meaning training is performed on streaming data, on chip (no data transfer required to an off-chip accelerator), simultaneous to inference, and lightweight (implemented on a Cyclone V chip) with minimal resources.

## How to use
### Requirements:
- Quartus II 18.1
- Intel FPGA Monitor Program
- Python 3
- DE1-Soc board

### Files included:
- ./hw/*sv: verilog source files 
- ./mem_files/*hex: MNIST inputs (original and with concept drift)
- ./output_files/demo_sys.sof: Current .sof file
- ./scripts/*: Scripts for running the demo GUI.

### Instructions for running the demo:
- Program ./hw/output_files/demo_sys.sof to the DE1 (with Quartus Programmer or Monitor Program)
- Load MNIST inputs to SDRAM with the Monitor Program. For example:
    - ins_10k_o.hex to address 9000000 (delimiter "," and value size 2)
    - ins_10k_rot_o.hex to address 9EFDE40
    - ins_10k_zoom_o.hex to address ADFBC80
- Run the GUI (python3 plotter.py)
