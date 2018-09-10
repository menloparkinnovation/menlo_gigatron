# menlo_gigatron
A System Verilog/FPGA implementation of the Gigatron project from https://gigatron.io/

# Building
Acquire a Terasic DE10-Nano FPGA development board from http://www.terasic.com.tw/cgi-bin/page/archive.pl?Language=English&CategoryNo=205&No=1046

It is about $130 retail, lower prices for education.

Other boards will work, but would need tweaking of the boards default "Shell" project that defines the resources of the board, and the specific version of the FPGA.

A Cyclone V SoC FPGA is used which as 41K logic elements and 5Mbits of block RAMS. It also has two 800Mhz ARM A9 processors with 1GB of RAM, and a couple of embedded Linux ports for both text mode and GUI. The SoC's are not currently used by this project at this time, but in the future will be used to manage downloads to the Gigatron and provide for an "EPROM emulator" for development.

Since its written in System Verilog, it could be ported to other FPGA's such as Xilinx.

The DE10-Nano user manual has instructions for installing the Altera/Intel Quartus II development software for the FPGA, which is available for free for educational and maker use. This software is required to compile your own FPGA bitstream from the Verilog sources.

# Running
The project implements an HDMI monitor interface with HDMI audio. The Gigatron's 4 bit VGA output and 4 bit sound is converted to 8 bit Truecolor at 640x480 on the monitor, with 16 bit I2S LPCM sound at 48Khz. The logic to do this actually exceeds the Gigatrons logic conumption by multiple times.

The Famicom game controller is connected with direct wires to the Arduino I/O pins on the DE10-Nano. The FPGA I/O ports have been configured to operate without the pull up or 68 ohm series resistors. I used a screw type DB9 male adapter and an Arduino "screw shield" for prototyping.

# Arduino IO Wiring
ARDUINO DIO2 - DB9 Pin 2 famicom_data (input)
ARDUINO DIO3 - DB9 Pin 4 famicom_pulse (output)
ARDUINO DIO4 - DB9 Pin 3 famicom_latch (output)
ARDUINO 5V   - DB9 Pin 6
ARDUINO GND  - DB9 Pin 8

# Future Work
Future work will provide an interface from the SoC's to the Gigatron to allow for development and debugging. This will include an emulation of the Arduino based loader for loading GTL programs into RAM, an EPROM emulator to allow Gigatron ROM development, and an ICE interface to read/write Gigatron registers and RAM, start/stop, etc. This would be available over character mode or VNC Linux running on the ARM SoC's.

The VGA framebuffer will be made available to the Linux, so an integration with a GUI Linux could be done within an X windows system with an application, and a merging of the Gigatron VGA handler in the project and the FPGA implementation of the Linux framebuffer.

# Gigatron Extensions
This provides a great platform for Gigatron extensions and experimentation. Additional registers, addressing modes, etc. I have thought of adding an extended addressing unit to it to allow it to access system memory outside of the Gigatron RAM so it can act as a soft processor. But this is challenged by having to manipulate 32 bit (or 64 bit addresses within a PCI bus) which involve many Gigatron processor load cycles. One solution would be to extend the register and instruction widths, but core Gigatron compatibility is still required. So we are back at 8080 -> 8086 -> 80286 -> 80386 -> ... all over again. One of the most fun aspects of the Gigatron project itself :-)

# Why did I do this?
I have an interest in FPGA based domain specific soft processors for my other project menlo_cnc which is an FPGA based CNC machine tool controller. Right now it operates similar to Gigatron as a simple microcoded hardware machine, but I want to add real time complex calculations such as curves onto the FPGA, and find that the interface to the ARM SoC's to be too slow. The Gigatron was used a learning experience in the implementation of a soft processor from scratch that could run existing software and tool chains, and do something useful and cool as well, such as play games.

I am a radio ham as well, and look forward to building an FPGA/SoC based implementation of a small portable SDR ham radio similar to, but an improvement on the excellent Elecraft KX3 (which I own). So I am interested in FPGA/SoC DSP techniques which is a leading area of SDR (Software Defined Radio).

On the professional side I am interested in Cloud applications of FPGA's at both the hyper-scale infrastructure, and Cloud applications such as "Big Data" and "AI". FPGA's have already revolutionized HFT (High Frequency Trading), and are emerging as a platform for drug discovery, etc. Soft processors on FPGA's are a solution to the slowing down of Moores law, which will have industry wide impact on the costs of computation. I anticipate future FPGA's to be tightly integrated with processors and to have complex programmable logic blocks similar to GPU's and DSP chips which allow a specific application domain to code its algorithms into the structure of the processor, with task specific data and operations as the "software".








