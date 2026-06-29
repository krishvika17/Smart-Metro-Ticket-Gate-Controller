# Smart Metro Ticket Gate Controller

> **FSM-based Verilog HDL implementation of an automated metro ticket
> gate controller with Vivado synthesis and GTKWave verification.**

------------------------------------------------------------------------

## Project Overview

The **Smart Metro Ticket Gate Controller** is a Finite State Machine
(FSM) based digital design implemented in **Verilog HDL**. It simulates
the operation of an automated metro entry gate by managing ticket
validation, gate control, passenger detection, timeout handling,
emergency override, and maintenance mode. The design is fully
synthesizable and verified using **Vivado**, **Icarus Verilog**, and
**GTKWave**.

------------------------------------------------------------------------

## Features

-   FSM-based metro ticket gate controller
-   Valid and invalid ticket handling
-   Automatic gate opening and closing
-   Passenger detection and entry counting
-   Timeout-based gate closure
-   Emergency override mode
-   Maintenance lockout mode
-   Fully synthesizable RTL
-   Verified using Vivado and GTKWave

------------------------------------------------------------------------

## FSM Workflow

### Normal Operation

``` text
IDLE → CARD_DETECTED → VALIDATE → OPEN_GATE → WAIT_FOR_PASSENGER → CLOSE_GATE → IDLE
```

### Invalid Ticket

``` text
IDLE → CARD_DETECTED → VALIDATE → INVALID_TICKET → IDLE
```

### Emergency

``` text
Any State → EMERGENCY → IDLE
```

### Maintenance

``` text
Any State → MAINTENANCE → IDLE
```

------------------------------------------------------------------------

## FSM State Encoding

    Value State                Description
  ------- -------------------- -------------------------------------
        0 IDLE                 Waiting for ticket
        1 CARD_DETECTED        Card detected
        2 VALIDATE             Ticket validation
        3 OPEN_GATE            Opens gate for a valid ticket
        4 WAIT_FOR_PASSENGER   Waits for passenger crossing
        5 CLOSE_GATE           Closes the gate and returns to IDLE
        6 INVALID_TICKET       Invalid ticket; alarm activated
        7 EMERGENCY            Emergency override
        8 MAINTENANCE          Maintenance mode

> **Note:** GTKWave displays the numeric encoding of the FSM state
> register.

------------------------------------------------------------------------

## Inputs

  Signal                Description
  --------------------- -----------------------------
  `clk`                 System clock
  `reset`               Synchronous reset
  `card_detected`       Detects ticket presentation
  `ticket_valid`        Indicates ticket validity
  `passenger_crossed`   Passenger crossing signal
  `timeout`             Gate timeout signal
  `emergency`           Emergency override
  `maintenance`         Maintenance mode

## Outputs

  Signal               Description
  -------------------- ---------------------------------------
  `gate_open`          Controls gate operation
  `alarm`              Indicates invalid ticket or emergency
  `display[3:0]`       Encoded controller status
  `entry_count[7:0]`   Counts successful passenger entries

------------------------------------------------------------------------

## Project Structure

``` text
Smart_Metro_Ticket_Gate_Controller/
│── metro_ticket_gate.v
│── metro_ticket_gate_tb.v
│── README.md
│── docs/
│    ├── State_Diagram.png
│    ├── RTL_Schematic.png
│    ├── Valid_Ticket_Waveform.png
│    ├── Invalid_Ticket_Waveform.png
│    └── Emergency_Maintenance_Waveform.png
```

------------------------------------------------------------------------

## RTL Architecture

-   **FSM State Register** -- Stores the current state.
-   **Next-State Logic** -- Computes the next state.
-   **Output Logic** -- Controls gate, alarm and display.
-   **Entry Counter** -- Counts successful passenger entries.

------------------------------------------------------------------------

## Simulation Results

### FSM State Diagram

![State Diagram](docs/State_Diagram.png)

### RTL Schematic

![RTL Schematic](docs/RTL_Schematic.png)

### Valid Ticket Transaction

![Valid Ticket](docs/Valid_Ticket_Waveform.png)

### Invalid Ticket Transaction

![Invalid Ticket](docs/Invalid_Ticket_Waveform.png)

### Emergency & Maintenance Modes

![Emergency and Maintenance](docs/Emergency_Maintenance_Waveform.png)

------------------------------------------------------------------------

## Tools Used

  Tool             Purpose
  ---------------- ------------------------
  Verilog HDL      RTL Design
  Vivado           Synthesis & Simulation
  Icarus Verilog   Simulation
  GTKWave          Waveform Analysis

------------------------------------------------------------------------

## How to Run

``` bash
iverilog -o metro_gate metro_ticket_gate.v metro_ticket_gate_tb.v
vvp metro_gate
gtkwave metro_ticket_gate.vcd
```

Alternatively, run Behavioral Simulation in Vivado.

------------------------------------------------------------------------

## Author

**Krishvika**
