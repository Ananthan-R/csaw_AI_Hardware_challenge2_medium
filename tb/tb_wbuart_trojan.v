`timescale 1ns/1ps

module tb_wbuart_trojan;

    localparam CLK_PERIOD = 10;
    localparam CLOCKS_PER_BAUD = 25;

    reg             i_clk, i_reset, i_wb_cyc, i_wb_stb, i_wb_we;
    reg     [1:0]   i_wb_addr;
    reg     [31:0]  i_wb_data;
    reg     [3:0]   i_wb_sel;
    reg             i_uart_rx, i_cts_n;

    wire            o_wb_stall, o_wb_ack;
    wire    [31:0]  o_wb_data;
    wire            o_uart_tx, o_rts_n;

    localparam ADDR_SETUP = 2'b00;
    localparam ADDR_FIFO  = 2'b01;
    localparam ADDR_RXREG = 2'b10;

    wbuart #(.INITIAL_SETUP(CLOCKS_PER_BAUD)) 
    dut ( .i_clk(i_clk), .i_reset(i_reset), .i_wb_cyc(i_wb_cyc), .i_wb_stb(i_wb_stb), 
          .i_wb_we(i_wb_we), .i_wb_addr(i_wb_addr), .i_wb_data(i_wb_data), .i_wb_sel(i_wb_sel), 
          .o_wb_stall(o_wb_stall), .o_wb_ack(o_wb_ack), .o_wb_data(o_wb_data), 
          .i_uart_rx(i_uart_rx), .o_uart_tx(o_uart_tx), .i_cts_n(i_cts_n), .o_rts_n(o_rts_n) );

    always @(posedge i_clk) begin
        if (dut.rx_stb)
            $display("[DEBUG] RX_STB detected! rx_uart_data=0x%h at time %t", dut.rx_uart_data, $time);
        if (dut.rxf_wb_read) begin
            $display("[DEBUG] RXF_WB_READ detected! rxf_wb_data=0x%h (decimal %d) at time %t", dut.rxf_wb_data, dut.rxf_wb_data, $time);
            if (dut.rxf_wb_data == 8'h1e)
                $display("[DEBUG] *** MATCH! Received 0x1e byte ***");
            else
                $display("[DEBUG] *** NO MATCH! Expected 0x1e but got 0x%h ***", dut.rxf_wb_data);
        end
    end

    always #(CLK_PERIOD/2) i_clk = ~i_clk;

    initial begin
        $display("--- Trojan Verification Testbench Starting ---");
        
        i_clk <= 0; i_reset <= 1; i_wb_cyc <= 0; i_wb_stb <= 0; i_wb_we <= 0;
        i_wb_addr <= 0; i_wb_data <= 0; i_wb_sel <= 0; i_uart_rx <= 1; i_cts_n <= 1;

        repeat(5) @(posedge i_clk);
        i_reset <= 0;
        @(posedge i_clk);
        $display("\n[INFO] Reset released. Starting Trojan trigger sequence.");

        $display("[TRIGGER] Sending byte 0x1e to UART RX...");
        uart_write_byte(8'h1e);
        $display("[SUCCESS] Byte sent.");
        
        // Wait much longer for UART to fully process
        repeat(300) @(posedge i_clk);
        $display("[DEBUG] After sending 0x1e: trojan_state=%d, rx_byte_1e_detected=%b", dut.trojan_state, dut.rx_byte_1e_detected);
        $display("[DEBUG] rx_stb=%b, rx_uart_data=0x%h, rx_uart_reset=%b", dut.rx_stb, dut.rx_uart_data, dut.rx_uart_reset);
        $display("[DEBUG] rx_empty_n=%b, rxf_status=0x%h", dut.rx_empty_n, dut.rxf_status);
        
        // Check if data was received by reading RX register
        $display("[CHECK] Reading RX register to trigger 0x1e detection...");
        wb_read(ADDR_RXREG);
        $display("[DEBUG] RX register data: 0x%h, rxf_wb_data=0x%h, rxf_wb_read=%b", o_wb_data, dut.rxf_wb_data, dut.rxf_wb_read);
        
        repeat(5) @(posedge i_clk);
        $display("[DEBUG] After RX read: trojan_state=%d, rx_byte_1e_detected=%b", dut.trojan_state, dut.rx_byte_1e_detected);

        $display("[TRIGGER] Reading from UART Setup Register (1/2)...");
        wb_read(ADDR_SETUP);
        $display("[DEBUG] After setup read 1: trojan_state=%d, setup_read_count=%d", dut.trojan_state, dut.setup_read_count);
        
        $display("[TRIGGER] Reading from UART Setup Register (2/2)...");
        wb_read(ADDR_SETUP);
        $display("[DEBUG] After setup read 2: trojan_state=%d, setup_read_count=%d", dut.trojan_state, dut.setup_read_count);
        
        $display("[TRIGGER] Reading from UART FIFO Register (1/2)...");
        wb_read(ADDR_FIFO);
        $display("[DEBUG] After FIFO read 1: trojan_state=%d, fifo_read_count=%d", dut.trojan_state, dut.fifo_read_count);
        
        $display("[TRIGGER] Reading from UART FIFO Register (2/2)...");
        wb_read(ADDR_FIFO);
        $display("[DEBUG] After FIFO read 2: trojan_state=%d, fifo_read_count=%d", dut.trojan_state, dut.fifo_read_count);
        
        $display("\n[ARMED] Trojan trigger sequence complete. Trojan should be armed.");
        $display("[DEBUG] Final trojan_state=%d", dut.trojan_state);

        $display("\n[PAYLOAD] Reading from UART Setup Register to trigger payload...");
        wb_read(ADDR_SETUP);

        if (o_wb_data === 32'hdeadbeef)
            $display("\n[PASS] ✅ Trojan payload SUCCESS! Read value is 0x%h.", o_wb_data);
        else
            $display("\n[FAIL] ❌ Trojan payload FAILED! Expected 0xdeadbeef, got 0x%h.", o_wb_data);

        $display("\n[VERIFY] Verifying one-shot behavior. Reading Setup Register again...");
        wb_read(ADDR_SETUP);
        
        if (o_wb_data !== 32'hdeadbeef)
            $display("[PASS] ✅ One-shot behavior CONFIRMED! Read value is 0x%h.", o_wb_data);
        else
            $display("[FAIL] ❌ One-shot behavior FAILED! Value is still 0xdeadbeef.", o_wb_data);
        
        $display("\n--- Testbench Finished ---");
        $finish;
    end

    task uart_write_byte;
        input [7:0] data;
        integer i;
        begin
            i_uart_rx = 0; #(CLK_PERIOD * CLOCKS_PER_BAUD);
            for (i = 0; i < 8; i = i + 1) begin
                i_uart_rx = data[i]; #(CLK_PERIOD * CLOCKS_PER_BAUD);
            end
            i_uart_rx = 1; #(CLK_PERIOD * CLOCKS_PER_BAUD);
        end
    endtask

    task wb_read;
        input [1:0] addr;
        begin
            @(posedge i_clk);
            i_wb_cyc <= 1; i_wb_stb <= 1; i_wb_we  <= 0;
            i_wb_addr <= addr; i_wb_sel <= 4'b1111;
            @(posedge i_clk);
            i_wb_stb <= 0; i_wb_sel <= 0;
            wait (o_wb_ack);
            $display("[DEBUG] WB Read from addr 0x%h, got data 0x%h", addr, o_wb_data);
            @(posedge i_clk);
            i_wb_cyc <= 0;
        end
    endtask

endmodule