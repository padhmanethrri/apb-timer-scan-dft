
`timescale 1ns/1ps

module tb_apb_timer;

    reg pclk;
    reg presetn;
    reg transfer;
    reg read;
    reg write;
    reg [7:0] addr_in;
    reg [31:0] data_in;

    wire [31:0] read_data;
    integer errors;

    // Design under test
    apb_timer_top dut (
        .pclk(pclk),
        .presetn(presetn),
        .transfer(transfer),
        .read(read),
        .write(write),
        .addr_in(addr_in),
        .data_in(data_in),
        .read_data(read_data)
    );

    // 10 ns clock period
    initial pclk = 0;
    always #5 pclk = ~pclk;

    // Waveform generation
    initial begin
        $dumpfile("results/timer.vcd");
        $dumpvars(0, tb_apb_timer);
    end

    // APB write transaction
    task apb_write;
        input [7:0] address;
        input [31:0] value;
        begin
            @(negedge pclk);
            addr_in = address;
            data_in = value;
            write = 1;
            read = 0;
            transfer = 1;

            @(negedge pclk);
            transfer = 0;

            wait (dut.psel && dut.penable && dut.pready);
            @(posedge pclk);
            #1;
            write = 0;
        end
    endtask

    // APB read transaction
    task apb_read;
        input [7:0] address;
        input [31:0] expected;
        reg [31:0] captured_data;
        begin
            @(negedge pclk);
            addr_in = address;
            write = 0;
            read = 1;
            transfer = 1;

            @(negedge pclk);
            transfer = 0;

            wait (dut.psel && dut.penable && dut.pready);

            @(posedge pclk);
            #1;
            captured_data = read_data;
            read = 0;

            if (captured_data === expected) begin
                $display("PASS: Read 0x%02h = %0d",
                         address, captured_data);
            end else begin
                $display("FAIL: Read 0x%02h expected %0d, got %0d",
                         address, expected, captured_data);
                errors = errors + 1;
            end
        end
    endtask

    // Main test sequence
    initial begin
        errors = 0;

        presetn = 0;
        transfer = 0;
        read = 0;
        write = 0;
        addr_in = 0;
        data_in = 0;

        // Initial reset
        repeat (3) @(negedge pclk);
        presetn = 1;

        // Test 1: LOAD register write and readback
        apb_write(8'h04, 5);
        apb_read(8'h04, 5);

        // STATUS should be zero before starting
        apb_read(8'h0C, 0);

        // Start timer in one-shot mode
        apb_write(8'h00, 1);

        // Allow countdown to finish
        repeat (8) @(negedge pclk);

        // Check timer completion
        apb_read(8'h08, 0);
        apb_read(8'h0C, 1);

        // Test 2: One-shot mode stops at zero
        // CTRL enable bit should clear automatically
        apb_read(8'h00, 0);

        repeat (5) @(negedge pclk);
        apb_read(8'h08, 0);

        // Test 3: Back-to-back register accesses
        apb_write(8'h04, 3);
        apb_read(8'h04, 3);

        apb_write(8'h04, 9);
        apb_read(8'h04, 9);

        apb_write(8'h04, 200);
        apb_read(8'h04, 200);

        // COUNT is read-only; writes must be ignored
        apb_write(8'h08, 55);
        apb_read(8'h08, 0);

        // Test 4: Reload mode
        apb_write(8'h04, 3);
        apb_write(8'h00, 3);

        repeat (12) @(negedge pclk);

        apb_read(8'h00, 3);
        apb_read(8'h0C, 1);

        // COUNT should be nonzero in reload mode
        if (dut.timer_inst.count == 0) begin
            $display("FAIL: COUNT is zero in reload mode");
            errors = errors + 1;
        end else begin
            $display("PASS: COUNT is nonzero in reload mode");
        end

        // Stop timer before reset test
        apb_write(8'h00, 0);

        // Test 5: Reset clears all registers
        apb_write(8'h04, 9);
        apb_write(8'h00, 1);

        @(negedge pclk);
        presetn = 0;

        repeat (2) @(negedge pclk);
        presetn = 1;

        apb_read(8'h00, 0);
        apb_read(8'h04, 0);
        apb_read(8'h08, 0);
        apb_read(8'h0C, 0);

        // Final result
        if (errors == 0)
            $display("\nALL TESTS PASSED");
        else
            $display("\nTESTS FAILED: %0d error(s)", errors);

        $finish;
    end

    // Simulation timeout
    initial begin
        #20000;
        $display("ERROR: Simulation timed out");
        $finish;
    end

endmodule
