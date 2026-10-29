`include "CACHE.sv"
`include "RAM.sv"

module test_cache_ram (
);
        localparam DATA_WIDTH = 31;
        localparam TAG_BITS   = 18;
        localparam INDEX_BITS = 11;
        localparam OFF_BITS   = 2;

        logic clk, reset;
        //CPU <-> CACHE
        logic cpu_req;
        logic cpu_write;
        logic [DATA_WIDTH:0] cpu_address;
        logic [DATA_WIDTH:0] write_data_cpu;
        logic [DATA_WIDTH:0] read_data_cpu;
        logic cpu_ready;

        //CACHE <-> RAM
        logic mem_ready;
        logic [DATA_WIDTH:0] read_data_mem;
        logic [DATA_WIDTH:0] mem_addr;
        logic [DATA_WIDTH:0] write_data_mem;
        logic mem_write, mem_req;

        always #5 clk = ~clk;

        CACHE #(
            .INDEX_BITS(INDEX_BITS),
            .TAG_BITS(TAG_BITS),
            .DATA_WIDTH(DATA_WIDTH),
            .OFF_BITS(OFF_BITS)
        ) DUT_CACHE (
            .clk(clk),
            .reset(reset),
            .cpu_req(cpu_req),
            .cpu_write(cpu_write),
            .cpu_address(cpu_address),
            .write_data_cpu(write_data_cpu),
            .read_data_mem(read_data_mem),
            .mem_ready(mem_ready),
            .mem_addr(mem_addr),
            .write_data_mem(write_data_mem),
            .mem_write(mem_write),
            .mem_req(mem_req),
            .read_data_cpu(read_data_cpu),
            .cpu_ready(cpu_ready)
        );

        RAM #(
            .DATA_WIDTH(DATA_WIDTH),
            .INDEX_BITS(INDEX_BITS)
        ) DUT_RAM (
            .clk(clk),
            .reset(reset),
            .mem_req(mem_req),
            .mem_write(mem_write),
            .address(mem_addr),
            .w_data(write_data_mem),
            .r_data(read_data_mem),
            .mem_ready(mem_ready)
        );

        task automatic write_cycle (input logic[DATA_WIDTH:0] addr, input logic[DATA_WIDTH:0] data);
            begin
                @(posedge clk)
                    cpu_address = addr;
                    write_data_cpu = data;
                    cpu_write = 1'b1;
                    cpu_req = 1'b1;

                    do 
                    begin
                        @(posedge clk);
                    end 
                    while(!cpu_ready);

                    cpu_req = 1'b0;
                    cpu_write = 1'b0;
                    $display("[WRITE SUCCESS] Addr: 0x%0h | Data: 0x%0h | Time: %0t", addr, data, $time);
            end
        endtask

        task automatic read_cycle (input logic[DATA_WIDTH:0] addr, input logic[DATA_WIDTH:0] expected_data);
            begin
                @(posedge clk)
                    cpu_address = addr;
                    cpu_write = 1'b0;
                    cpu_req = 1'b1;

                    do 
                    begin
                        @(posedge clk);
                    end
                    while(!cpu_ready);

                    assert (read_data_cpu == expected_data)
                        $display("[READ SUCCESS] Addr: 0x%0h | Data: 0x%0h | Time: %0t", addr, read_data_cpu, $time);
                    else 
                        $error("[READ FAIL] Addr: 0x%0h | Expected: 0x%0h | Got: 0x%0h", addr, expected_data, read_data_cpu);

                    cpu_req = 1'b0;
            end
        endtask

        initial begin
            clk = 0;
            reset = 1;
            cpu_req = 0;
            cpu_write = 0;
            cpu_address = 0;
            write_data_cpu = 0;
            $dumpfile("test_cache_ram.vcd");
            $dumpvars(0, test_cache_ram);

            repeat (5) @(posedge clk);
                reset = 0;
            @(posedge clk);

            $display("THE BEGINING OF THE TESTS");

            $display("TEST 1: WRITE AND READ BACK");
            write_cycle(32'h0000_0100, 32'hDEADBEEF);

            $display("TEST 2: READ BACK");
            read_cycle(32'h0000_0100, 32'hDEADBEEF);

            $display("TEST 3: TAG CONFLICT");
            write_cycle(32'h0080_0100, 32'hDEADBEEB);

            $display("TEST 4: Write BACK");
            write_cycle(32'h0180_0100, 32'hDEADBAEB);

            read_cycle(32'h0180_0100, 32'hDEADBAEB);

            $display("DONE WITH TESTS");
            $stop;
        end
endmodule

