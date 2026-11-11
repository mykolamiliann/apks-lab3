// SPI Master - передавач (Tx)
// Режим SPI 0: SCK у спокої = 0, дані читаються на передньому фронті SCK.
// Передає 1 байт (8 біт), старшим бітом уперед (MSB first).

module spi_master_tx #(
    parameter CLK_DIV = 4          // SCK перемикається кожні CLK_DIV тактів clk
) (
    input  wire       clk,         // системний такт
    input  wire       rst,         // скидання (1 = скинути)
    input  wire       start,       // імпульс "почати передачу"
    input  wire [7:0] data_in,     // байт, який треба передати
    output reg        sck,         // тактовий сигнал SPI (генерує Master)
    output reg        mosi,        // дані Master -> Slave
    output reg        ss_n,        // вибір Slave (0 = активний)
    output reg        busy,        // 1 = йде передача
    output reg        done         // імпульс 1 такт: байт передано
);

    // Стани автомата (FSM)
    localparam IDLE     = 2'd0;    // чекаємо start
    localparam TRANSFER = 2'd1;    // передаємо 8 біт
    localparam DONE     = 2'd2;    // завершення передачі

    reg [1:0] state;               // поточний стан
    reg [7:0] shift_reg;           // зсувний регістр з даними
    reg [2:0] bit_cnt;             // номер біта, що передається (0..7)
    reg [7:0] div_cnt;             // лічильник дільника частоти для SCK

    always @(posedge clk) begin
        if (rst) begin
            state     <= IDLE;
            sck       <= 1'b0;
            mosi      <= 1'b0;
            ss_n      <= 1'b1;
            busy      <= 1'b0;
            done      <= 1'b0;
            shift_reg <= 8'd0;
            bit_cnt   <= 3'd0;
            div_cnt   <= 8'd0;
        end else begin
            done <= 1'b0;          // done живе лише 1 такт

            case (state)
                IDLE: begin
                    if (start) begin
                        shift_reg <= data_in;     // запам'ятали байт
                        mosi      <= data_in[7];  // одразу виставили старший біт
                        ss_n      <= 1'b0;        // вибрали Slave
                        busy      <= 1'b1;
                        bit_cnt   <= 3'd0;
                        div_cnt   <= 8'd0;
                        sck       <= 1'b0;
                        state     <= TRANSFER;
                    end
                end

                TRANSFER: begin
                    if (div_cnt == CLK_DIV - 1) begin
                        div_cnt <= 8'd0;
                        sck     <= ~sck;          // перемикаємо SCK
                        if (sck == 1'b1) begin    // зараз буде задній фронт SCK
                            if (bit_cnt == 3'd7) begin
                                state <= DONE;    // усі 8 біт передано
                            end else begin
                                bit_cnt   <= bit_cnt + 1'b1;
                                shift_reg <= {shift_reg[6:0], 1'b0}; // зсув вліво
                                mosi      <= shift_reg[6];           // наступний біт
                            end
                        end
                    end else begin
                        div_cnt <= div_cnt + 1'b1;
                    end
                end

                DONE: begin
                    ss_n  <= 1'b1;        // відпустили Slave
                    busy  <= 1'b0;
                    done  <= 1'b1;        // повідомили: готово
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule