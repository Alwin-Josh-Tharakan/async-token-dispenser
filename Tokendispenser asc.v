`timescale 1ns/1ps
// =============================================================================
// TokenDispenser_ASC.v
// Asynchronous Smart Token Dispenser
// PEECT415 - Digital Systems and VLSI Design | GEC Thrissur
// Student : Alwin Josh Tharakan
// KTU Reg.: TCR24EC027  | Admission: 24B220  | Roll: 10
//
// FIX: Added `timescale 1ns/1ps so that #1 delay = 1 ns (matches testbench).
//      Without this, iVerilog used a default time unit and the #1 delays were
//      never reached within the simulation window, leaving state frozen at 000.
// =============================================================================
//
// State encoding (Gray-code: 1 bit changes per transition):
//   S0=000 Rs. 0 Wait    S1=001 Rs. 5 Hold (In5 active)
//   S2=011 Rs. 5 Wait    S3=010 Rs.10 Hold (In10 active)
//   S4=110 Rs.10 Wait    S5=111 Rs.15 Release (TR=1)
//   S6=100 Rs.20 Release (TR=1, CR=1)
//   101 = unused (conceptual routing state for S5->S0)
//
// Output equations:
//   Token_Release = y2.y1'.y0' + y2.y1.y0   (S6=100 or S5=111)
//   Coin_Return   = y2.y1'.y0'              (S6=100 only)
// =============================================================================

module TokenDispenser_ASC (
    input  wire In5,
    input  wire In10,
    input  wire Reset,
    output wire Token_Release,
    output wire Coin_Return
);

    reg [2:0] state;

    localparam S0 = 3'b000;  // Rs.  0 -- Wait
    localparam S1 = 3'b001;  // Rs.  5 -- Hold (In5 sensor active)
    localparam S2 = 3'b011;  // Rs.  5 -- Wait
    localparam S3 = 3'b010;  // Rs. 10 -- Hold (In10 sensor active)
    localparam S4 = 3'b110;  // Rs. 10 -- Wait
    localparam S5 = 3'b111;  // Rs. 15 -- Token Release
    localparam S6 = 3'b100;  // Rs. 20 -- Token Release + Coin Return
    // 3'b101 unused: implicit routing state for race-free S5->S0 path

    initial begin
        state = S0;
    end

    // -------------------------------------------------------------------------
    // Asynchronous Next-State Logic
    // Single always block sensitive to inputs -- correct for Fundamental Mode.
    // #1 models 1 ns gate propagation. timescale 1ns/1ps ensures correct scale.
    // -------------------------------------------------------------------------
    always @(In5 or In10 or Reset) begin
        if (Reset) begin
            #1 state = S0;
        end else begin
            case (state)
                S0: begin
                    if      (In10) #1 state = S3;  // Rs.0  + Rs.10 -> Rs.10
                    else if (In5)  #1 state = S1;  // Rs.0  + Rs.5  -> Rs.5
                end
                S1: begin
                    if (!In5 && !In10) #1 state = S2;  // sensor released
                end
                S2: begin
                    if      (In10) #1 state = S5;  // Rs.5  + Rs.10 -> Rs.15 RELEASE
                    else if (In5)  #1 state = S3;  // Rs.5  + Rs.5  -> Rs.10
                end
                S3: begin
                    if (!In5 && !In10) #1 state = S4;  // sensor released
                end
                S4: begin
                    if      (In10) #1 state = S6;  // Rs.10 + Rs.10 -> Rs.20 RELEASE+RETURN
                    else if (In5)  #1 state = S5;  // Rs.10 + Rs.5  -> Rs.15 RELEASE
                end
                S5: begin
                    if (!In5 && !In10) #1 state = S0;  // return to idle
                end
                S6: begin
                    if (!In5 && !In10) #1 state = S0;  // return to idle
                end
                default: #1 state = S0;
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // Output Logic (purely combinational)
    // Token_Release = y2.y1'.y0' + y2.y1.y0  =>  S5 (111) or S6 (100)
    // Coin_Return   = y2.y1'.y0'              =>  S6 (100) only
    // -------------------------------------------------------------------------
    assign Token_Release = (state == S5) || (state == S6);
    assign Coin_Return   = (state == S6);

    // State bit aliases exposed for testbench $monitor / check_result
    wire y2 = state[2];
    wire y1 = state[1];
    wire y0 = state[0];

endmodule