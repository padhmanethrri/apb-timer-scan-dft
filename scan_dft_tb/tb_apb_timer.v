`timescale 1ns/1ps

// Scan testbench for the APB timer.
//
// Scan chain (49 bits) is one left-shift register:
//     R = {done, count[7:0], load[7:0], ctrl[31:0]}
//     shift: R <= {R[47:0], scan_in};   scan_out = R[48] (= done)
// So: bits go in MSB first, and come out MSB first (first in, first out).
//
// Rule for the scan tasks: call them right after a negedge of pclk.
// They return right after a negedge, so no extra clock edge slips in
// between two calls.

module tb_apb_timer;

    reg         pclk     = 0;
    reg         presetn  = 0;
    reg         transfer = 0;
    reg         read     = 0;
    reg         write    = 0;
    reg  [7:0]  addr_in  = 0;
    reg  [31:0] data_in  = 0;
    reg         scan_en  = 0;
    reg         scan_in  = 0;

    wire [31:0] read_data;
    wire        scan_out;

    integer     errors = 0;
    reg [48:0]  unloaded;

    localparam [48:0] PAT_A = 49'h1ABCDE1234567;
    localparam [48:0] PAT_B = 49'h0A5A5A5A5A5A5;
    localparam [48:0] ALL1  = 49'h1FFFFFFFFFFFF;
    localparam [48:0] ZERO  = 49'h0;

    apb_timer_top dut (
        .pclk(pclk),
        .presetn(presetn),
        .transfer(transfer),
        .read(read),
        .write(write),
        .addr_in(addr_in),
        .data_in(data_in),
        .read_data(read_data),
        .scan_en(scan_en),
        .scan_in(scan_in),
        .scan_out(scan_out)
    );

    // White-box view of the 49 scanned flops, in chain order
    wire [48:0] chain = {dut.timer_inst.done,  dut.timer_inst.count,
                         dut.timer_inst.load,  dut.timer_inst.ctrl};

    always #5 pclk = ~pclk;

    initial begin
        $dumpfile("results/scan_timer.vcd");
        $dumpvars(0, tb_apb_timer);
    end

    // ------------------------------------------------------------
    // Checking helpers
    // ------------------------------------------------------------
    task check49;
        input [48:0]    got;
        input [48:0]    expected;
        input [8*64:1]  label;
        begin
            if (got === expected)
                $display("PASS: %0s", label);
            else begin
                $display("FAIL: %0s  got=%h expected=%h", label, got, expected);
                errors = errors + 1;
            end
        end
    endtask

    // ------------------------------------------------------------
    // Reset: ends right after a negedge
    // ------------------------------------------------------------
    task do_reset;
        begin
            @(negedge pclk);
            presetn = 0;
            repeat (2) @(negedge pclk);
            presetn = 1;
            @(negedge pclk);
        end
    endtask

    // ------------------------------------------------------------
    // Scan: shift 49 bits in (MSB first) and capture the 49 bits that
    // come out (MSB first). scan_out is sampled at negedge, before the
    // posedge that shifts it away, so there is no race.
    // ------------------------------------------------------------
    task scan_shift;
        input  [48:0] vec_in;
        output [48:0] vec_out;
        integer k;
        begin
            scan_en = 1;
            for (k = 48; k >= 0; k = k - 1) begin
                scan_in    = vec_in[k];
                vec_out[k] = scan_out;
                @(negedge pclk);
            end
            scan_en = 0;
            scan_in = 0;
        end
    endtask

    // Load a state, run ONE normal clock (scan_en=0), compare the result
    task capture_test;
        input [48:0]    start;
        input [48:0]    expected;
        input [8*64:1]  label;
        begin
            scan_shift(start, unloaded);
            check49(chain, start, "  state loaded through scan");
            @(negedge pclk);                       // one functional clock
            check49(chain, expected, label);       // look inside
            scan_shift(ZERO, unloaded);            // look from outside
            check49(unloaded, expected, "  same result seen at scan_out");
        end
    endtask

    // ------------------------------------------------------------
    // APB helpers (same as the functional testbench)
    // ------------------------------------------------------------
    task apb_write;
        input [7:0]  address;
        input [31:0] value;
        begin
            @(negedge pclk);
            addr_in  = address;
            data_in  = value;
            write    = 1;
            read     = 0;
            transfer = 1;

            @(negedge pclk);
            transfer = 0;

            wait (dut.psel && dut.penable && dut.pready);
            @(posedge pclk);
            #1;
            write = 0;
        end
    endtask

    task apb_read;
        input [7:0]  address;
        input [31:0] expected;
        reg   [31:0] captured_data;
        begin
            @(negedge pclk);
            addr_in  = address;
            write    = 0;
            read     = 1;
            transfer = 1;

            @(negedge pclk);
            transfer = 0;

            wait (dut.psel && dut.penable && dut.pready);
            @(posedge pclk);
            #1;
            captured_data = read_data;
            read = 0;

            if (captured_data === expected)
                $display("PASS: APB read 0x%02h = %0d", address, captured_data);
            else begin
                $display("FAIL: APB read 0x%02h expected %0d, got %0d",
                         address, expected, captured_data);
                errors = errors + 1;
            end
        end
    endtask

    // ------------------------------------------------------------
    // Test sequence
    // ------------------------------------------------------------
    initial begin
        // ---- 1. Reset ----
        do_reset;
        check49(chain, ZERO, "1. reset clears all 49 chain bits");

        // ---- 2. Scan shifting and scan-out ----
        scan_shift(PAT_A, unloaded);
        check49(unloaded, ZERO,  "2a. scan_out during first load = old (zero) state");
        check49(chain,    PAT_A, "2b. chain holds PAT_A after 49 shifts");
        check49({48'b0, scan_out}, {48'b0, PAT_A[48]},
                                 "2c. scan_out pin shows chain MSB (done)");

        scan_shift(PAT_B, unloaded);
        check49(unloaded, PAT_A, "2d. shifted-out bits equal PAT_A, MSB first");
        check49(chain,    PAT_B, "2e. chain now holds PAT_B");

        scan_shift(ALL1, unloaded);
        check49(chain, ALL1, "2f. all ones loaded (stuck-at-0 check on chain)");
        scan_shift(ZERO, unloaded);
        check49(unloaded, ALL1, "2g. all ones shifted out");
        check49(chain, ZERO, "2h. all zeros loaded (stuck-at-1 check on chain)");

        // ---- 3. Functional capture (scan_en = 0 for exactly one clock) ----
        // vector = {done, count, load, ctrl}
        capture_test({1'b0, 8'd3, 8'd7, 32'h00000001},
                     {1'b0, 8'd2, 8'd7, 32'h00000001},
                     "3a. enabled timer counts 3 -> 2");
        capture_test({1'b0, 8'd1, 8'd7, 32'h00000001},
                     {1'b1, 8'd0, 8'd7, 32'h00000000},
                     "3b. one-shot at 1: count 0, done set, enable clears");
        capture_test({1'b0, 8'd1, 8'd7, 32'h00000003},
                     {1'b1, 8'd7, 8'd7, 32'h00000003},
                     "3c. reload mode at 1: count reloads, done set");
        capture_test({1'b0, 8'd5, 8'd9, 32'hA5A5A5A4},
                     {1'b0, 8'd5, 8'd9, 32'hA5A5A5A4},
                     "3d. disabled timer holds every bit");

        // ---- 4. Reset clears a fully loaded chain ----
        scan_shift(ALL1, unloaded);
        check49(chain, ALL1, "4a. chain loaded with all ones");
        do_reset;
        check49(chain, ZERO, "4b. reset clears the chain");

        // ---- 5. Regression: normal APB timer behaviour with scan_en = 0 ----
        apb_read (8'h0C, 0);                    // done is 0 after reset
        apb_write(8'h04, 5);
        apb_read (8'h04, 5);
        apb_write(8'h00, 1);                    // start one-shot
        repeat (8) @(negedge pclk);
        apb_read (8'h08, 0);                    // stopped at zero
        apb_read (8'h0C, 1);                    // done set
        apb_read (8'h00, 0);                    // enable bit cleared itself

        apb_write(8'h04, 3);  apb_read(8'h04, 3);
        apb_write(8'h04, 9);  apb_read(8'h04, 9);
        apb_write(8'h04, 200);apb_read(8'h04, 200);
        apb_write(8'h08, 55);                   // COUNT is read-only
        apb_read (8'h08, 0);

        apb_write(8'h04, 3);
        apb_write(8'h00, 3);                    // enable + reload
        repeat (12) @(negedge pclk);
        apb_read (8'h00, 3);
        apb_read (8'h0C, 1);
        if (dut.timer_inst.count == 0) begin
            $display("FAIL: count sat at 0 in reload mode");
            errors = errors + 1;
        end else
            $display("PASS: reload mode keeps counting");
        apb_write(8'h00, 0);                    // stop

        // ---- Summary ----
        if (errors == 0)
            $display("\nALL TESTS PASSED");
        else
            $display("\nTESTS FAILED: %0d error(s)", errors);
        $finish;
    end

    initial begin
        #200000;
        $display("ERROR: simulation timed out");
        $finish;
    end

endmodule
