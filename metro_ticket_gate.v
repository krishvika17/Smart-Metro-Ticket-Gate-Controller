module metro_ticket_gate (
    input  wire       clk,               // System clock
    input  wire       reset,             // Synchronous active-high reset
    input  wire       card_detected,     // High when a card is tapped
    input  wire       ticket_valid,      // High when card passes validation
    input  wire       passenger_crossed, // High when IR sensor detects crossing
    input  wire       timeout,           // High when open-gate timer expires
    input  wire       emergency,         // High for emergency (gate forced open)
    input  wire       maintenance,       // High to enter maintenance mode
    output reg        gate_open,         // High = gate barrier lifted
    output reg        alarm,             // High = audible/visual alert active
    output reg  [3:0] display,           // 4-bit encoded display code (see params)
    output wire [7:0] entry_count        // Running count of successful entries
);

//  State Encoding (parameter-based, one-hot friendly binary)

parameter [3:0]
    IDLE              = 4'd0,
    CARD_DETECTED     = 4'd1,
    VALIDATE          = 4'd2,
    OPEN_GATE         = 4'd3,
    WAIT_FOR_PASSENGER= 4'd4,
    CLOSE_GATE        = 4'd5,
    INVALID_TICKET    = 4'd6,
    EMERGENCY         = 4'd7,
    MAINTENANCE       = 4'd8;


//  Display Codes (4-bit values driven onto `display` output)
//  External decoder (7-seg or LED bar) maps these to text/icons

parameter [3:0]
    DISP_IDLE        = 4'h0,   // "--"  ready
    DISP_CARD        = 4'h1,   // "CD"  card detected
    DISP_VALIDATING  = 4'h2,   // "VA"  validating
    DISP_OPEN        = 4'h3,   // "GO"  gate open
    DISP_WAIT        = 4'h4,   // "PS"  please step through
    DISP_CLOSING     = 4'h5,   // "CL"  closing
    DISP_INVALID     = 4'h6,   // "ER"  error / invalid
    DISP_EMERGENCY   = 4'h7,   // "EM"  emergency
    DISP_MAINTENANCE = 4'h8;   // "MN"  maintenance

//  Internal Registers

reg [3:0] state;          // Current FSM state
reg [3:0] next_state;     // Next FSM state (combinational)
reg [7:0] entry_cnt_reg;  // Passenger entry counter
reg       count_en;       // Pulse: increment counter this cycle
reg [3:0] alarm_cnt;      // Counts down alarm duration

// Expose counter as output
assign entry_count = entry_cnt_reg;

//  BLOCK 1 — State Register (sequential)
//  Registers current state on every rising clock edge.
//  Emergency and Maintenance inputs are checked here for
//  immediate (priority) override of any ongoing state.

always @(posedge clk) begin
    if (reset) begin
        state <= IDLE;
    end
    else if (emergency) begin
        // Emergency overrides everything — go directly
        state <= EMERGENCY;
    end
    else if (maintenance && (state != EMERGENCY)) begin
        // Maintenance overrides normal flow (not emergency)
        state <= MAINTENANCE;
    end
    else begin
        state <= next_state;
    end
end

//  BLOCK 2 — Next-State Logic (combinational)
//  Determines next_state purely from current state + inputs.
//  No registers or side effects allowed here.

always @(*) begin
    // Default: stay in current state
    next_state = state;

    case (state)

        // ---- IDLE ----
        // Gate is closed, system is waiting for a card tap.
        IDLE: begin
            if (card_detected)
                next_state = CARD_DETECTED;
        end

        // ---- CARD_DETECTED ----
        // Brief acknowledgement state; move to validation immediately.
        CARD_DETECTED: begin
            next_state = VALIDATE;
        end

        // ---- VALIDATE ----
        // Wait for the ticket_valid signal from the backend/reader.
        VALIDATE: begin
            if (ticket_valid)
                next_state = OPEN_GATE;
            else if (!card_detected)
                // Card removed without valid result → invalid
                next_state = INVALID_TICKET;
            // If card still present but not yet valid, keep validating
        end

        // ---- OPEN_GATE ----
        // Command gate to open; move to wait-for-passenger immediately.
        OPEN_GATE: begin
            next_state = WAIT_FOR_PASSENGER;
        end

        // ---- WAIT_FOR_PASSENGER ----
        // Stay open until passenger crosses or timeout occurs.
        WAIT_FOR_PASSENGER: begin
            if (passenger_crossed)
                next_state = CLOSE_GATE;
            else if (timeout)
                next_state = CLOSE_GATE;  // Timed out — close anyway
        end

        // ---- CLOSE_GATE ----
        // Gate is commanded to close; return to IDLE next cycle.
        CLOSE_GATE: begin
            next_state = IDLE;
        end

        // ---- INVALID_TICKET ----
        // Keep gate closed, alarm fires briefly (handled in output block).
        // Return to IDLE after alarm countdown ends.
        INVALID_TICKET: begin
            if (alarm_cnt == 4'd0)
                next_state = IDLE;
        end

        // ---- EMERGENCY ----
        // Gate stays open. Exit only when emergency signal is deasserted.
        EMERGENCY: begin
            if (!emergency)
                next_state = IDLE;
        end

        // ---- MAINTENANCE ----
        // System locked. Exit when maintenance signal deasserted.
        MAINTENANCE: begin
            if (!maintenance)
                next_state = IDLE;
        end

        default: next_state = IDLE;

    endcase
end

//  BLOCK 3 — Output Logic (sequential, registered outputs)
//  Drives gate_open, alarm, display from current state.
//  Registered outputs prevent glitches on synthesized hardware.

always @(posedge clk) begin
    if (reset) begin
        gate_open    <= 1'b0;
        alarm        <= 1'b0;
        display      <= DISP_IDLE;
        count_en     <= 1'b0;
        alarm_cnt    <= 4'd0;
    end
    else begin
        // Default de-assertions each cycle (override below per state)
        count_en  <= 1'b0;
        alarm     <= 1'b0;

        case (state)

            IDLE: begin
                gate_open <= 1'b0;
                display   <= DISP_IDLE;
                alarm_cnt <= 4'd10;  // Pre-load alarm timer for next use
            end

            CARD_DETECTED: begin
                gate_open <= 1'b0;
                display   <= DISP_CARD;
            end

            VALIDATE: begin
                gate_open <= 1'b0;
                display   <= DISP_VALIDATING;
            end

            OPEN_GATE: begin
                gate_open <= 1'b1;
                display   <= DISP_OPEN;
            end

            WAIT_FOR_PASSENGER: begin
                gate_open <= 1'b1;
                display   <= DISP_WAIT;
                // Increment counter the cycle the passenger crosses
                if (passenger_crossed)
                    count_en <= 1'b1;
            end

            CLOSE_GATE: begin
                gate_open <= 1'b0;
                display   <= DISP_CLOSING;
            end

            INVALID_TICKET: begin
                gate_open <= 1'b0;
                display   <= DISP_INVALID;
                // Drive alarm and count down timer
                if (alarm_cnt != 4'd0) begin
                    alarm     <= 1'b1;
                    alarm_cnt <= alarm_cnt - 4'd1;
                end
            end

            EMERGENCY: begin
                gate_open <= 1'b1;   // Force gate open
                alarm     <= 1'b1;   // Alert staff
                display   <= DISP_EMERGENCY;
            end

            MAINTENANCE: begin
                gate_open <= 1'b0;   // Gate locked during maintenance
                alarm     <= 1'b0;
                display   <= DISP_MAINTENANCE;
            end

            default: begin
                gate_open <= 1'b0;
                display   <= DISP_IDLE;
            end

        endcase
    end
end

//  BLOCK 4 — Passenger Entry Counter (sequential)
//  Increments on the count_en pulse set in output logic above.
//  Wraps at 255 (natural 8-bit rollover).

always @(posedge clk) begin
    if (reset)
        entry_cnt_reg <= 8'd0;
    else if (count_en)
        entry_cnt_reg <= entry_cnt_reg + 8'd1;
end

endmodule