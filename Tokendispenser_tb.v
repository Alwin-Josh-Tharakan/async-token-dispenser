`timescale 1ns/1ps

// =============================================================================
// TokenDispenser_tb.v  --  Comprehensive Testbench  (CORRECTED)
// PEECT415 Digital Systems and VLSI Design | GEC Thrissur
// Student : Alwin Josh Tharakan | TCR24EC027 | Adm: 24B220 | Roll: 10
//
// FIX 1 (design): Added `timescale 1ns/1ps to TokenDispenser_ASC.v so that
//   the #1 delay = 1 ns.  Without it, iVerilog used an unknown default time
//   unit and the state register was never updated within the simulation window.
//
// FIX 2 (testbench): Token/Return outputs are only active while the triggering
//   sensor is HIGH (machine stays in S5/S6 only while a sensor is asserted).
//   The old testbench called insert_Rs_X() which released the sensor before
//   the check, so the machine had already returned to S0.
//
//   New approach for the LAST coin in each token-triggering scenario:
//     1. Assert sensor (In5 or In10 goes HIGH).
//     2. Wait SETTLE ns (state transitions in ~1 ns, SETTLE >> 1 ns).
//     3. CHECK here -- machine is in S5 or S6 with TR/CR active.
//     4. Release sensor manually after check.
//   Intermediate coins still use the full insert_RsX task (press+release).
//
// Scenarios:
//   A : Rs.10 + Rs.10 = Rs.20   -> Token_Release=1, Coin_Return=1
//   B : Rs.5  + Rs.5  + Rs.5    -> Token_Release=1, Coin_Return=0
//   C : Rs.5  + Rs.10 = Rs.15   -> Token_Release=1, Coin_Return=0
//   D : Rs.10 + Rs.5  = Rs.15   -> Token_Release=1, Coin_Return=0
//   E : Reset mid-sequence
//   F : Reset during active Token Release
//   G : Extended coin hold (Hold-state verification)
//   H : Idle no-op
// =============================================================================

module TokenDispenser_tb;

    reg  In5, In10, Reset;
    wire Token_Release, Coin_Return;

    TokenDispenser_ASC uut (
        .In5(In5), .In10(In10), .Reset(Reset),
        .Token_Release(Token_Release), .Coin_Return(Coin_Return)
    );

    // -------------------------------------------------------------------------
    // Timing parameters
    // -------------------------------------------------------------------------
    localparam COIN_PULSE  = 50;   // sensor pulse width (ns)
    localparam COIN_GAP    = 100;  // gap between coins (ns)
    localparam SETTLE      = 20;   // time for state to settle after input change
                                   // (#1 propagation + margin; 20 >> 1 ns)
    localparam RESET_PULSE = 50;   // reset pulse width (ns)

    integer pass_count;
    integer fail_count;

    // -------------------------------------------------------------------------
    // Helper tasks
    // -------------------------------------------------------------------------

    // Full insert cycle: sensor HIGH for COIN_PULSE, then LOW for COIN_GAP.
    // Use for intermediate coins (not the final triggering coin).
    task insert_Rs5;
    begin
        In5 = 1; #COIN_PULSE;
        In5 = 0; #COIN_GAP;
    end
    endtask

    task insert_Rs10;
    begin
        In10 = 1; #COIN_PULSE;
        In10 = 0; #COIN_GAP;
    end
    endtask

    // "Press-only" tasks: assert sensor and wait SETTLE.
    // Use for the LAST coin before check_result -- do NOT release inside.
    // After check_result the caller must do: In5/In10 = 0; #COIN_GAP;
    task press_Rs5;
    begin
        In5 = 1; #SETTLE;
    end
    endtask

    task press_Rs10;
    begin
        In10 = 1; #SETTLE;
    end
    endtask

    // Release tasks (called after check on last coin)
    task release_Rs5;
    begin
        In5 = 0; #COIN_GAP;
    end
    endtask

    task release_Rs10;
    begin
        In10 = 0; #COIN_GAP;
    end
    endtask

    task do_reset;
    begin
        Reset = 1; #RESET_PULSE;
        Reset = 0; #COIN_GAP;
    end
    endtask

    // -------------------------------------------------------------------------
    // check_result: waits SETTLE then verifies TR, CR, and state bits
    // -------------------------------------------------------------------------
    task check_result;
        input [63:0]  scenario_num;
        input [255:0] scenario_name;
        input         exp_token_release;
        input         exp_coin_return;
        input [2:0]   exp_state;
    begin
        #SETTLE;   // extra settle margin
        if (Token_Release === exp_token_release &&
            Coin_Return   === exp_coin_return   &&
            {uut.y2, uut.y1, uut.y0} === exp_state) begin
            $display("[PASS] Scenario %0d: %s", scenario_num, scenario_name);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Scenario %0d: %s", scenario_num, scenario_name);
            $display("       Got      State=%b%b%b  TR=%b  CR=%b",
                     uut.y2, uut.y1, uut.y0, Token_Release, Coin_Return);
            $display("       Expected State=%b   TR=%b  CR=%b",
                     exp_state, exp_token_release, exp_coin_return);
            fail_count = fail_count + 1;
        end
    end
    endtask

    // =========================================================================
    // Stimulus
    // =========================================================================
    initial begin
        $dumpfile("token_results.vcd");
        $dumpvars(0, TokenDispenser_tb);

        pass_count = 0; fail_count = 0;
        In5 = 0; In10 = 0; Reset = 0;
        #20;

        // ----------------------------------------------------------------
        // Scenario H: Idle -- no coins inserted
        // ----------------------------------------------------------------
        do_reset; #200;
        check_result(8, "Idle no coins",
                     0, 0, 3'b000);

        // ----------------------------------------------------------------
        // Scenario A: Rs.10 + Rs.10 = Rs.20  ->  TR=1, CR=1  (S6=100)
        //
        // [S0] --In10--> S3 --In10=0--> S4 --In10--> [S6: TR=1,CR=1]
        //                                              ^check here^
        // ----------------------------------------------------------------
        do_reset;
        insert_Rs10;         // intermediate: S0->S3->S4 (full cycle)
        press_Rs10;          // last coin: S4->S6; sensor stays HIGH
        check_result(1, "Rs.10+Rs.10=Rs.20 Token+Return",
                     1, 1, 3'b100);
        release_Rs10;        // S6->S0 (sensor released)

        // ----------------------------------------------------------------
        // Scenario B: Rs.5 + Rs.5 + Rs.5 = Rs.15  ->  TR=1, CR=0  (S5=111)
        //
        // S0->S1->S2 ->S3->S4 --In5--> [S5: TR=1,CR=0]
        //                               ^check here^
        // ----------------------------------------------------------------
        do_reset;
        insert_Rs5;          // S0->S1->S2
        insert_Rs5;          // S2->S3->S4
        press_Rs5;           // last coin: S4->S5; sensor stays HIGH
        check_result(2, "Rs.5+Rs.5+Rs.5=Rs.15 Token",
                     1, 0, 3'b111);
        release_Rs5;         // S5->S0

        // ----------------------------------------------------------------
        // Scenario C: Rs.5 + Rs.10 = Rs.15  ->  TR=1, CR=0  (S5=111)
        //
        // S0->S1->S2 --In10--> [S5: TR=1,CR=0]
        //                       ^check here^
        // ----------------------------------------------------------------
        do_reset;
        insert_Rs5;          // S0->S1->S2
        press_Rs10;          // last coin: S2->S5; sensor stays HIGH
        check_result(3, "Rs.5+Rs.10=Rs.15 Token",
                     1, 0, 3'b111);
        release_Rs10;        // S5->S0

        // ----------------------------------------------------------------
        // Scenario D: Rs.10 + Rs.5 = Rs.15  ->  TR=1, CR=0  (S5=111)
        //
        // S0->S3->S4 --In5--> [S5: TR=1,CR=0]
        //                      ^check here^
        // ----------------------------------------------------------------
        do_reset;
        insert_Rs10;         // S0->S3->S4
        press_Rs5;           // last coin: S4->S5; sensor stays HIGH
        check_result(4, "Rs.10+Rs.5=Rs.15 Token",
                     1, 0, 3'b111);
        release_Rs5;         // S5->S0

        // ----------------------------------------------------------------
        // Scenario E: Reset mid-sequence (mid Rs.10 Wait) -> S0
        // Then verify normal operation resumes.
        // ----------------------------------------------------------------
        do_reset;
        insert_Rs10;                           // S0->S3->S4 (Rs.10 Wait)
        Reset = 1; #RESET_PULSE; Reset = 0; #COIN_GAP;
        check_result(5, "State after mid-sequence reset",
                     0, 0, 3'b000);
        // Verify operation after reset: Rs.5 + Rs.10 = Rs.15
        insert_Rs5;                            // S0->S1->S2
        press_Rs10;                            // S2->S5; sensor HIGH
        check_result(51, "Rs.5+Rs.10 after mid-sequence reset = Rs.15",
                     1, 0, 3'b111);
        release_Rs10;                          // S5->S0

        // ----------------------------------------------------------------
        // Scenario F: Reset DURING active Token Release
        // Machine enters S5 with In5 HIGH, then reset fires.
        // In5 is released together with Reset to cleanly return to S0.
        // ----------------------------------------------------------------
        do_reset;
        insert_Rs10;                           // S0->S3->S4
        In5 = 1; #SETTLE;                     // S4->S5 (TR=1 active; In5 HIGH)
        Reset = 1; #RESET_PULSE;              // assert reset: S5->S0
        In5 = 0; Reset = 0; #COIN_GAP;        // release both; state stays S0
        check_result(6, "State after reset during Token Release",
                     0, 0, 3'b000);

        // ----------------------------------------------------------------
        // Scenario G: Extended coin hold (Hold-state verification)
        // Check that machine stays in Hold state while sensor is active.
        // ----------------------------------------------------------------
        do_reset;
        In10 = 1; #(COIN_PULSE * 3);          // hold In10 for 150 ns
        check_result(71, "In Rs.10 Hold (S3) while In10=1",
                     0, 0, 3'b010);           // S3=010, still held
        In10 = 0; #COIN_GAP;                  // release -> S4
        check_result(72, "Rs.10 Wait (S4) after In10 release",
                     0, 0, 3'b110);           // S4=110
        press_Rs5;                             // S4->S5; sensor HIGH
        check_result(73, "Rs.5 after long-hold Rs.10 = Rs.15 Token",
                     1, 0, 3'b111);           // S5=111, TR=1
        release_Rs5;                           // S5->S0

        // ----------------------------------------------------------------
        $display("\n===== SUMMARY: Passed=%0d  Failed=%0d =====\n",
                 pass_count, fail_count);
        $finish;
    end

    // -------------------------------------------------------------------------
    // Continuous state monitor
    // -------------------------------------------------------------------------
    initial begin
        $monitor("T=%0t  In5=%b In10=%b Rst=%b  State=%b%b%b  TR=%b CR=%b",
                 $time, In5, In10, Reset,
                 uut.y2, uut.y1, uut.y0, Token_Release, Coin_Return);
    end

endmodule