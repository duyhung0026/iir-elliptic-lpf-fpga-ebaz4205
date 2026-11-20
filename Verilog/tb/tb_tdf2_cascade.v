`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/17/2026 03:25:27 PM
// Design Name: 
// Module Name: tb_tdf2_cascade
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tb_tdf2_cascade;
localparam CLK_HALF    = 10;       // 10ns -> 50 MHz
localparam SAMPLE_NS   = 28160;    // 1/35511Hz = 28.16 us
localparam NUM_SAMPLES = 3000;
 
//////// DUT ports //////////////
reg        clk    = 0;
reg        enable = 0;
reg [11:0] data_in;
wire[11:0] data_out;
 
/////// Instantiate DUT /////////
filter_block_tdf2_cascade uut (
    .clk     (clk),
    .enable  (enable),
    .data_in (data_in),
    .data_out(data_out)
);
 
/////// Clock 50 MHz ///////////
always #CLK_HALF clk = ~clk;
 
/////// Input data array ///////
reg [15:0] input_data [0:NUM_SAMPLES-1]; // doc 16-bit hex tu file
integer i;
 
////// Output file ////////////
integer fp_out;
 
////// Stimulus //////////////
initial begin
    // Nap file hex (16-bit signed Q1.14 tu MATLAB)
    // Moi dong: 4 ky tu hex, vi du "1A2B"
 $readmemh("...\\...\\compare rtl vs matlab\\gen\\input_12bit(th3).txt", input_data);
 
    // Mo file ghi output
 fp_out = $fopen("...\\...\\compare rtl vs matlab\\dump_data\\filter_block_output_tdf2_cascade(th3).txt", "w");
    if (fp_out == 0) begin
        $display("ERROR: Khong mo duoc file output!");
        $finish;
    end
 
    data_in = 12'd0;

    repeat(5) @(posedge clk);
 
    // Chay qua toan bo mau
    for (i = 0; i < NUM_SAMPLES; i = i + 1) begin
        @(posedge clk);
        #1;
        data_in <=  input_data[i][11:0];// + 12'd2048; // map signed->unsigned 12-bit
        enable  <= 1'b1;
 
        @(posedge clk);
        #1;
        enable  <= 1'b0;
 
        // Ghi output ra file (decimal)
        $fwrite(fp_out, "%0d\n", data_out);
        #(SAMPLE_NS - 4*CLK_HALF);
    end
 
    $fclose(fp_out);
    #1000;
    $finish;
end
 
initial begin
    $monitor("t=%0t | in=%4d | out=%4d | en=%b",
             $time, data_in, data_out, enable);
end
 
endmodule
