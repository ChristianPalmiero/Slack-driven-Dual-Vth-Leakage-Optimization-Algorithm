# Slack-driven-Dual-Vth-Leakage-Optimization-Algorithm
## Introduction
A TCL command to be integrated within Design Compiler that performs a Slack-driven Dual-Vth post synthesis optimization based on the Logic Synthesis Flow using Synopsys.<br />
![alt tag](https://github.com/ChristianPalmiero/Slack-driven-Dual-Vth-Leakage-Optimization-Algorithm/blob/master/1.png)
![alt tag](https://github.com/ChristianPalmiero/Slack-driven-Dual-Vth-Leakage-Optimization-Algorithm/blob/master/2.png)
## Target library and timing constraints
The technology library has been provided by STMicroelectronics @ 65nm. 
<br /> The clock period has been set to 3.0 ns.
## Command
Such a command reduces leakage power by means of dual-Vth assignment while forcing the number of quasi-critical paths below a user-defined constraint.
<br />
Main arguments of the command are:
- arrivalTime: the actual timing constraint the circuit has to satisfy after dual-Vth assignment [ns];
- criticalPaths: the total number of timing paths that fall within a given slack window after the dual-Vth
assignment [integer];
- slackWin: is the slack window for critical paths [ns];

The command returns the list resList containing the following 4 items:
- power-savings: % of leakage reduction w.r.t. the initial configuration;
- execution-time: difference between starting-time and end-time [seconds];
- lvt: % of LVT gates;
- hvt: % of HVT gates;

## Example
![alt tag](https://github.com/ChristianPalmiero/Slack-driven-Dual-Vth-Leakage-Optimization-Algorithm/blob/master/img.png)

## Details
See the [Report](Report.pdf) in order to catch more information about the implementation details.
<br />See the [dualVth_Group_13.tcl](dualVth_Group_13.tcl) file in order to see the script.
