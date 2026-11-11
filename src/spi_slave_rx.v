// SPI Slave - приймач (Rx)
// Слухає лінії SCK, MOSI і SS_N, на кожному передньому фронті SCK
// записує 1 біт. Після 8 біт видає прийнятий байт і імпульс valid.

module spi_slave_rx (
    input  wire       clk,         // системний такт (швидший за SCK)
    input  wire       rst,         // скидання (1 = скинути)
    input  wire       sck,         // тактовий сигнал SPI від Master
    input  wire       mosi,        // дані Master -> Slave
    input  wire       ss_n,        // вибір Slave (0 = нас вибрали)
    output reg  [7:0] data_out,    // прийнятий байт
    output reg        valid        // імпульс 1 такт: байт прийнято
);

    reg       sck_prev;            // значення SCK на попередньому такті
    reg [7:0] shift_reg;           // сюди по одному "заїжджають" біти
    reg [2:0] bit_cnt;             // скільки біт уже прийнято (0..7)

    always @(posedge clk) begin
        if (rst) begin
            sck_prev  <= 1'b0;
            shift_reg <= 8'd0;
            bit_cnt   <= 3'd0;
            data_out  <= 8'd0;
            valid     <= 1'b0;
        end else begin
            valid    <= 1'b0;      // valid живе лише 1 такт
            sck_prev <= sck;

            if (ss_n) begin
                bit_cnt <= 3'd0;   // нас не вибрали - починаємо спочатку
            end else if (sck && !sck_prev) begin   // передній фронт SCK
                shift_reg <= {shift_reg[6:0], mosi};  // дописали біт справа
                if (bit_cnt == 3'd7) begin
                    data_out <= {shift_reg[6:0], mosi}; // байт готовий
                    valid    <= 1'b1;
                    bit_cnt  <= 3'd0;
                end else begin
                    bit_cnt <= bit_cnt + 1'b1;
                end
            end
        end
    end

endmodule