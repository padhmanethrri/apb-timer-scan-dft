
module apb_timer_top (
    input  wire        pclk,
    input  wire        presetn,

    input  wire        transfer,
    input  wire        read,
    input  wire        write,
    input  wire [7:0]  addr_in,
    input  wire [31:0] data_in,

    output wire [31:0] read_data
);

    wire        psel;
    wire        penable;
    wire [7:0]  paddr;
    wire        pwrite;
    wire [31:0] pwdata;
    wire [31:0] prdata;
    wire        pready;

    // APB Master
    apb_master master_inst (
        .pclk(pclk),
        .presetn(presetn),
        .transfer(transfer),
        .read(read),
        .write(write),
        .addr_in(addr_in),
        .data_in(data_in),
        .prdata(prdata),
        .pready(pready),
        .psel(psel),
        .penable(penable),
        .paddr(paddr),
        .pwrite(pwrite),
        .pwdata(pwdata),
        .read_data(read_data)
    );

    // APB Timer Slave
    apb_timer timer_inst (
        .pclk(pclk),
        .presetn(presetn),
        .psel(psel),
        .penable(penable),
        .pwrite(pwrite),
        .paddr(paddr),
        .pwdata(pwdata),
        .prdata(prdata),
        .pready(pready)
    );

endmodule

