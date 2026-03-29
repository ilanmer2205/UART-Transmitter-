`timescale 1ns / 1ps

module tb_main;

    localparam BAUDRATE_TEST = 1736;
    localparam CLOCKRATE_TEST = 10;
    localparam BPS_TEST = BAUDRATE_TEST * CLOCKRATE_TEST;

    reg clk=0;
    reg cpu_resetn=1;
    reg [14:0] SW=0;
    reg BTN_C=0;
    reg [7:0] test_pkt = 0;
    // Outputs
    wire TX;
    wire LED;
    wire [7:0] AN;
    wire [6:0] SEG;
    wire tick;
    
    // Internal variables for testing
    reg [7:0] rx_byte=0;
    reg [9:0] row_count=0, col_count=0;

    // Instantiate the Top Level Design (main)
    main #(.BAUD_COUNTER(BAUDRATE_TEST), .REFRESH_COUNTER(16)) dut (
        .clk(clk), 
        .cpu_resetn(cpu_resetn), 
        .SW(SW), 
        .BTN_C(BTN_C), 
        .TX(TX), 
        .LED(LED), 
        .AN(AN), 
        .SEG(SEG)
    );

    baud_rate_generator #(.BAUD_COUNTER(BAUDRATE_TEST)) baud_gen_inst2 (
        .clk(clk),
        .rst(cpu_resetn),
        .tick(tick)
    );
    // Clock Generation (100MHz -> 10ns period)
    initial begin
        clk = 0;
        forever #(CLOCKRATE_TEST/2) clk = ~clk;
    end
    
    event byte_received;
    task check_tx;
        reg [7:0] test_pkt1;
        begin
            forever begin               
                wait(!TX);
//                $display("time: %t[UART RX] start bit: 0x%h", $time, TX);
                #(BPS_TEST/2); //WAIT HALF A BIT
//                $display("time: %t[UART RX] second bit: 0x%h", $time, TX);
                repeat(8) begin
                    #BPS_TEST; //WAIT A BIT
                    test_pkt1 = {TX, test_pkt1[7:1]};
//                    test_pkt1 = 8'hff;
//                    $display("time: %t[UART RX] Captured bit: 0x%h", $time , TX);
                end
                #BPS_TEST; //stop bit
                test_pkt = test_pkt1;      // Update the global data
                -> byte_received;
                $display("Time %t: [UART RX] Captured Byte: 0x%h", $time ,test_pkt1);              
            end
        end
    endtask    
    
    task count_row;
        begin
            forever begin  
                @(byte_received);    
                if (test_pkt == 8'h0d) begin
                    row_count = row_count + 1'b1;
                    $display("[ROW COUNTER] Number of Rows: 0x%d", row_count);   
                    $display("[ROW COUNTER] Number of colums: %d", col_count);  
                    col_count <= 9'h0;           
                end
            end
        end
    endtask
    
    task count_col;
        begin
            forever begin
                @(byte_received);   
                if (test_pkt == 8'h55) begin
                    col_count = col_count + 1;
//                    $display("[COLUMN COUNTER] Number of colums: %h", col_count);   
                end     
            end
            
        end
    endtask
    initial begin
        
        SW[7:0] = 8'h55; 
        SW[9:8] = 2'b01;
        SW[14:13] = 2'b11; //2 in simulation
        cpu_resetn = 0;
        #50;
        cpu_resetn = 1;
        @ (posedge tick);
        @ (posedge tick);
        
        #10;
        BTN_C = 1;
        fork
            check_tx ();
            count_row();
            count_col();
        join_none
        #10;
        BTN_C = 0;
        #200;
        
    end

endmodule