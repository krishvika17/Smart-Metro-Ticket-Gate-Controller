module metro_ticket_gate_tb;

//  DUT Port Signals

reg        clk;
reg        reset;
reg        card_detected;
reg        ticket_valid;
reg        passenger_crossed;
reg        timeout;
reg        emergency;
reg        maintenance;

wire       gate_open;
wire       alarm;
wire [3:0] display;
wire [7:0] entry_count;

//  DUT Instantiation  (ports matched exactly — do not modify)

metro_ticket_gate dut (
    .clk              (clk),
    .reset            (reset),
    .card_detected    (card_detected),
    .ticket_valid     (ticket_valid),
    .passenger_crossed(passenger_crossed),
    .timeout          (timeout),
    .emergency        (emergency),
    .maintenance      (maintenance),
    .gate_open        (gate_open),
    .alarm            (alarm),
    .display          (display),
    .entry_count      (entry_count)
);

//  Clock Generation — 100 MHz  (period = 10 ns)

initial clk = 0;
always #5 clk = ~clk;

// Helper task: advance N rising edges and add a small read margin
task clk_step;
    input integer n;
    integer i;
    begin
        for (i = 0; i < n; i = i + 1)
            @(posedge clk);
        #1; // 1 ns after edge — outputs have settled
    end
endtask

//  Waveform Dump

initial begin
    $dumpfile("metro_ticket_gate.vcd");
    $dumpvars(0, metro_ticket_gate_tb);
end

//  Main Stimulus

initial begin
    // Initialise all inputs to safe (de-asserted) defaults
    reset            = 1;
    card_detected    = 0;
    ticket_valid     = 0;
    passenger_crossed= 0;
    timeout          = 0;
    emergency        = 0;
    maintenance      = 0;

    //  TEST 1 — System Reset
    //  Assert reset for 4 cycles; verify outputs are cleared.
   
    $display("\n[TEST 1] System Reset");
    clk_step(4);
    reset = 0;
    clk_step(1);
    $display("  reset deasserted | gate_open=%b alarm=%b display=%0h entry_count=%0d",
             gate_open, alarm, display, entry_count);

    //  TEST 2 — Valid Ticket Flow
    //  Tap card → validate → gate opens → passenger crosses →
    //  gate closes → entry_count increments.
   
    $display("\n[TEST 2] Valid Ticket — full happy path");

    // Tap card (IDLE → CARD_DETECTED)
    card_detected = 1;
    clk_step(1);   // CARD_DETECTED registered

    // CARD_DETECTED → VALIDATE (auto-transition, 1 cycle)
    clk_step(1);
    ticket_valid = 1;  // Backend confirms valid card

    // VALIDATE → OPEN_GATE (ticket_valid sampled)
    clk_step(1);
    $display("  OPEN_GATE state  | gate_open=%b  [expect 1]", gate_open);

    // OPEN_GATE → WAIT_FOR_PASSENGER (auto, 1 cycle)
    clk_step(1);

    // Passenger crosses
    passenger_crossed = 1;
    clk_step(1);   // WAIT_FOR_PASSENGER sees crossing → CLOSE_GATE
    passenger_crossed = 0;
    card_detected     = 0;
    ticket_valid      = 0;

    // CLOSE_GATE → IDLE (auto, 1 cycle)
    clk_step(2);
    $display("  After close      | gate_open=%b entry_count=%0d  [expect 0, 1]",
             gate_open, entry_count);

    //  TEST 3 — Invalid Ticket
    //  Tap card, ticket NOT valid, card removed → INVALID_TICKET
    //  state; alarm fires for 10 cycles; gate stays closed.
 
    $display("\n[TEST 3] Invalid Ticket — alarm check");

    card_detected = 1;
    clk_step(2);             // Through CARD_DETECTED → VALIDATE
    card_detected = 0;       // Remove card without ticket_valid → INVALID_TICKET
    clk_step(2);
    $display("  INVALID_TICKET   | gate_open=%b alarm=%b  [expect 0, 1]",
             gate_open, alarm);

    // Wait for alarm countdown (10 cycles)
    clk_step(12);
    $display("  Alarm expired    | gate_open=%b alarm=%b display=%0h  [expect 0, 0, 0]",
             gate_open, alarm, display);

    //  TEST 4 — Passenger Timeout
    //  Valid ticket, gate opens, passenger never crosses.
    //  Timeout signal fires → gate closes, count unchanged.
 
    $display("\n[TEST 4] Passenger Timeout — gate auto-close");

    card_detected = 1;
    clk_step(1);             // → CARD_DETECTED
    ticket_valid  = 1;
    clk_step(2);             // → VALIDATE → OPEN_GATE
    $display("  Gate opened      | gate_open=%b  [expect 1]", gate_open);

    clk_step(1);             // → WAIT_FOR_PASSENGER
    timeout = 1;             // Simulate timer expiry
    clk_step(1);             // → CLOSE_GATE
    timeout       = 0;
    card_detected = 0;
    ticket_valid  = 0;
    clk_step(2);             // → IDLE; output updates
    $display("  After timeout    | gate_open=%b entry_count=%0d  [expect 0, 1]",
             gate_open, entry_count);

    //  TEST 5 — Emergency Mode
    //  Assert emergency mid-IDLE; gate must open immediately.
    //  Deassert; system returns to IDLE.

    $display("\n[TEST 5] Emergency Mode — immediate gate override");

    emergency = 1;
    clk_step(1);             // State register overridden → EMERGENCY
    clk_step(1);             // Output block in EMERGENCY state
    $display("  EMERGENCY active | gate_open=%b alarm=%b  [expect 1, 1]",
             gate_open, alarm);

    emergency = 0;
    clk_step(2);             // FSM exits EMERGENCY → IDLE; outputs settle
    $display("  After emergency  | gate_open=%b alarm=%b  [expect 0, 0]",
             gate_open, alarm);

    //  TEST 6 — Maintenance Mode
    //  Assert maintenance; verify normal flow is blocked.
    //  Attempt to tap a card — system must ignore it.
    //  Deassert; normal operation resumes.

    $display("\n[TEST 6] Maintenance Mode — normal flow disabled");

    maintenance = 1;
    clk_step(2);             // State → MAINTENANCE; // Return to IDLE
    $display("  MAINTENANCE      | gate_open=%b alarm=%b display=%0h  [expect 0, 0, 8]",
             gate_open, alarm, display);

    // Try to tap a card — should be ignored while in MAINTENANCE
    card_detected = 1;
    ticket_valid  = 1;
    clk_step(3);
    $display("  Card tapped (MNT)| gate_open=%b  [expect 0 — gate stays shut]",
             gate_open);
    card_detected = 0;
    ticket_valid  = 0;

    maintenance = 0;
    clk_step(2);             // → IDLE
    $display("  After maintenance| gate_open=%b display=%0h  [expect 0, 0]",
             gate_open, display);
    //  Simulation Complete
    $display("\n[SIM] All test cases complete. entry_count = %0d\n", entry_count);
    $finish;
end

endmodule

