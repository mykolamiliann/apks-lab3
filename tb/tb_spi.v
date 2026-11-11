// Тестбенч для SPI: перевіряє передавач (Tx) і приймач (Rx)
`timescale 1ns / 1ps

module tb_spi;

    // ---- Сигнали для передавача ----
    reg        clk = 0;
    reg        rst = 1;
    reg        start = 0;
    reg  [7:0] data_in = 8'd0;
    wire       sck, mosi, ss_n, busy, done;

    // ---- Приймач 1: підключений до нашого передавача ----
    wire [7:0] rx_data;
    wire       rx_valid;

    // ---- Приймач 2: слухає "інший пристрій", який імітує тестбенч ----
    reg        ext_sck  = 0;
    reg        ext_mosi = 0;
    reg        ext_ss_n = 1;
    wire [7:0] rx2_data;
    wire       rx2_valid;

    integer errors = 0;

    // Тактовий сигнал: період 20 нс (50 МГц)
    always #10 clk = ~clk;

    // Модулі, які перевіряємо
    spi_master_tx #(.CLK_DIV(4)) tx (
        .clk(clk), .rst(rst), .start(start), .data_in(data_in),
        .sck(sck), .mosi(mosi), .ss_n(ss_n), .busy(busy), .done(done)
    );

    spi_slave_rx rx1 (
        .clk(clk), .rst(rst), .sck(sck), .mosi(mosi), .ss_n(ss_n),
        .data_out(rx_data), .valid(rx_valid)
    );

    spi_slave_rx rx2 (
        .clk(clk), .rst(rst), .sck(ext_sck), .mosi(ext_mosi), .ss_n(ext_ss_n),
        .data_out(rx2_data), .valid(rx2_valid)
    );

    // Тест 1: передавач надсилає байт, приймач 1 має отримати те саме
    task send_byte(input [7:0] b);
        begin
            @(negedge clk);
            data_in = b;
            start   = 1;
            @(negedge clk);
            start   = 0;
            @(posedge done);
            @(negedge clk);
            if (rx_data === b)
                $display("OK   Tx -> Rx: передано %h, прийнято %h", b, rx_data);
            else begin
                $display("FAIL Tx -> Rx: передано %h, прийнято %h", b, rx_data);
                errors = errors + 1;
            end
        end
    endtask

    // Тест 2: тестбенч сам "грає" інший SPI-пристрій і передає байт у приймач 2
    task ext_send(input [7:0] b);
        integer i;
        begin
            ext_ss_n = 0;
            for (i = 7; i >= 0; i = i - 1) begin
                ext_mosi = b[i];
                #100 ext_sck = 1;          // передній фронт: приймач читає біт
                #100 ext_sck = 0;
            end
            #100 ext_ss_n = 1;
            #100;
            if (rx2_data === b)
                $display("OK   ext -> Rx: передано %h, прийнято %h", b, rx2_data);
            else begin
                $display("FAIL ext -> Rx: передано %h, прийнято %h", b, rx2_data);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("spi.vcd");      // файл з осцилограмами для GTKWave
        $dumpvars(0, tb_spi);

        #50 rst = 0;               // зняли скидання

        send_byte(8'hA5);
        send_byte(8'h3C);
        ext_send(8'h96);
        ext_send(8'h5A);

        if (errors == 0) $display("Усі тести пройдено");
        else             $display("Помилок: %0d", errors);
        $finish;
    end

endmodule