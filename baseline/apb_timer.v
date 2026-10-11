module apb_timer (
    input wire pclk,
    input wire presetn,
    input wire psel,
    input wire penable,
    input wire pwrite,
    input wire [7:0] paddr,
    input wire [31:0] pwdata,
    output reg [31:0] prdata,
    output wire pready
);

    // Register addresses
    localparam CTRL_ADDR   = 8'h00;
    localparam LOAD_ADDR   = 8'h04;
    localparam COUNT_ADDR  = 8'h08;
    localparam STATUS_ADDR = 8'h0C;

    // Timer registers
    reg [31:0] ctrl;
    reg [7:0] load;
    reg [7:0] count;
    reg done;

    // Zero-wait-state APB slave
    assign pready = presetn && psel && penable;

    // APB read logic
    always @(*) begin
        prdata = 32'b0;

        if (psel && !pwrite) begin
            case (paddr)
                CTRL_ADDR:   prdata = ctrl;
                LOAD_ADDR:   prdata = {24'b0, load};
                COUNT_ADDR:  prdata = {24'b0, count};
                STATUS_ADDR: prdata = {31'b0, done};
                default:     prdata = 32'b0;
            endcase
        end
    end

    // Register writes and timer operation
    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            ctrl  <= 32'b0;
            load  <= 8'b0;
            count <= 8'b0;
            done  <= 1'b0;
        end else begin

            // Timer countdown
            if (ctrl[0] && count > 0) begin
                count <= count - 1'b1;

                if (count == 1) begin
                    done <= 1'b1;

                    if (ctrl[1])
                        count <= load;
                    else
                        ctrl[0] <= 1'b0;
                end
            end

            // APB register writes
            if (psel && penable && pwrite) begin
                case (paddr)
                    CTRL_ADDR: begin
                        ctrl <= pwdata;

                        if (pwdata[0]) begin
                            done  <= 1'b0;
                            count <= load;
                        end
                    end

                    LOAD_ADDR: begin
                        load <= pwdata[7:0];
                    end

                    default: ;
                endcase
            end
        end
    end

endmodule
