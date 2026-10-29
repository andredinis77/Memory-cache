`timescale 1ns/1ns
`include "RAM.sv"

module test_ram #(
        parameter DATA_WIDTH = 31
);

        logic clk, reset;
        logic mem_req;
        logic mem_write;
        logic [DATA_WIDTH:0] address;
        logic [DATA_WIDTH:0] w_data;
        logic [DATA_WIDTH:0] r_data;
        logic mem_ready;

        int counter;

        RAM DUT(
            .clk( clk ),
            .reset( reset ),
            .mem_req( mem_req ),
            .mem_write( mem_write ),
            .address( address ),
            .w_data( w_data ),
            .r_data( r_data ),
            .mem_ready( mem_ready )  
        );
        
        initial begin
            reset = 1'b1;
            #20;
            reset = 1'b0;
        end

        initial clk = 1'b0;
        always #10 clk = ~clk;

        initial begin
            counter = 0;
            address = 32'h00000068;
            mem_write = 1'b0;
            w_data = 32'hCA107233;
        end

        task send_req;
            if(counter == 15) begin
                mem_req = 1'b1;
                #1;
            end else begin
                mem_req = 1'b0;
            end
        endtask

        
        always @(posedge clk) begin
            counter = counter + 1'b1;
            send_req;
            
            #10;
            
            if(mem_ready) begin
                $display("SIMULATION HAS BEEN FINISHED: %h", r_data);
                $finish();
            end
        end
endmodule