
module apb_master (
    input wire        pclk,
    input wire        presetn,

    input wire        transfer,
    input wire        read,
    input wire        write,
    input wire [7:0]  addr_in,
    input wire [31:0] data_in,
    input wire [31:0] prdata,
    input wire        pready,

    output reg        psel,
    output reg        penable,
    output reg [7:0]  paddr,
    output reg        pwrite,
    output reg [31:0] pwdata,
    output reg [31:0] read_data
);

    localparam IDLE   = 2'b00;
    localparam SETUP  = 2'b01;
    localparam ACCESS = 2'b10;

    reg [1:0] state;

    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            state    <= IDLE;
            psel     <= 1'b0;
            penable  <= 1'b0;
            paddr    <= 8'b0;
            pwrite   <= 1'b0;
            pwdata   <= 32'b0;
            read_data <= 32'b0;
        end else begin
            case (state)
                IDLE: begin
                    psel    <= 1'b0;
                    penable <= 1'b0;

                    if (transfer && (read ^ write)) begin
                        paddr  <= addr_in;
                        pwrite <= write;
                        pwdata <= data_in;
                        state  <= SETUP;
                    end
                end

                SETUP: begin
                    psel    <= 1'b1;
                    penable <= 1'b0;
                    state   <= ACCESS;
                end

                ACCESS: begin
                    psel    <= 1'b1;
                    penable <= 1'b1;

                    if (pready) begin
                        if (!pwrite)
                            read_data <= prdata;

                        psel    <= 1'b0;
                        penable <= 1'b0;
                        state   <= IDLE;
                    end
                end

                default: begin
                    state   <= IDLE;
                    psel    <= 1'b0;
                    penable <= 1'b0;
                end
            endcase
        end
    end

endmodule
