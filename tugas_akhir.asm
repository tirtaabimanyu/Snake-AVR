.include "m8515def.inc"

; PORTA buat Enable, RS, dan LED
; 0 Enable (Input)
; 1 RS (Input)
; 5 LED (Output)
; 6 LED (Output)
; 7 LED (Output)

; PORTB buat DDRAM LCD 1
; PORTC buat DDRAM LCD 2

; PORTD buat Button
; 2 Start (Input)
; 3 Pause (Input)
; 4 Atas (Input)
; 5 Bawah (Input)
; 6 Kanan (Input)
; 7 Kiri (Input)

; PORTE buat DDRAM LCD 3

.def temp = r16
.def immediate = r17
.def counter = r18
.def arah = r19
.def target = r20
.def button = r21
.def length = r22

.equ lcd_content = 0x60
.equ snake_position = 0x130

.org $00 rjmp reset
.org $01 rjmp start
.org $02 rjmp pause
.org $06 rjmp update

; ================================================================================================= ;

reset:

init_stack:
ldi temp, low(RAMEND)
out SPL, temp
ldi temp, high(RAMEND)
out SPH, temp

init_port:
ldi temp, 0b00000111
out DDRA, temp
ldi temp, 0b00000000
out DDRB, temp
ldi temp, 0b00000000
out DDRC, temp
ldi temp, 0b00000000
out DDRD, temp
ldi temp, 0b00000000
out DDRE, temp

init_interrupt:
ldi temp, 0b00001010
out MCUCR, temp
ldi temp, 0b11000000
out GICR, temp
sei

init_timer:
ldi temp, (1<<CS11)
out TCCR1B, temp
ldi temp, (1<<TOV1)
out TIFR, temp
ldi temp, (1<<TOIE1)
out TIMSK, temp
sei

init_led:
ldi temp, 0b11100000
out PORTA, temp

init_lcd:
cbi PORTA, 1 ; CLR RS
ldi temp, 0b00111000 ; MOV DATA,0x38 --> 8bit, 2line, 5x7
out PORTB, temp
out PORTC, temp
out PORTE, temp
sbi PORTA,0 ; SETB EN
cbi PORTA,0 ; CLR EN

cbi PORTA, 1 ; CLR RS
ldi temp, 0b00001100 ; MOV DATA,0x0C --> disp ON, cursor OFF, blink OFF
out PORTB, temp
out PORTC, temp
out PORTE, temp
sbi PORTA,0 ; SETB EN
cbi PORTA,0 ; CLR EN

cbi PORTA,1 ; CLR RS
ldi temp, 0b00000110 ; MOV DATA,0x06 --> increase cursor, display sroll OFF
out PORTB, temp
out PORTC, temp
out PORTE, temp
sbi PORTA,0 ; SETB EN
cbi PORTA,0 ; CLR EN

rcall clear_lcd

; ================================================================================================= ;

init_game:
ldi length, 0x02
ldi arah, 0x40
ldi YH, high(lcd_content)
ldi YL, low(lcd_content)
ldi ZH, high(initial_state*2)
ldi ZL, low(initial_state*2)
ldi counter, 200
rcall flash_to_sram
ldi counter, 200
rcall flash_to_sram
forever:
in button, PIND
cpi button, 0
breq forever
cpi button, 4
breq forever
cpi button, 8
breq forever
cpi arah, 0x10
brne skip_cek_atas
	cpi button, 0x20
	breq forever
	mov arah, button
	rjmp forever
skip_cek_atas:
cpi arah, 0x20
brne skip_cek_bawah
	cpi button, 0x10
	breq forever
	mov arah, button
	rjmp forever
skip_cek_bawah:
cpi arah, 0x40
brne skip_cek_kanan
	cpi button, 0x80
	breq forever
	mov arah, button
	rjmp forever
skip_cek_kanan:
cpi arah, 0x80
brne skip_cek_kiri
	cpi button, 0x40
	breq forever
	mov arah, button
	rjmp forever
skip_cek_kiri:
rjmp forever

; ================================================================================================= ;

flash_to_sram:
cpi counter, 0
breq end_flash_to_sram
lpm
st Y+, r0
adiw Z, 1
dec counter
rjmp flash_to_sram
end_flash_to_sram:
ret

clear_lcd:
cbi PORTA, 1 ; CLR RS
ldi temp, 0b00000001 ; MOV DATA,0x01
out PORTB, temp
out PORTC, temp
out PORTE, temp
sbi PORTA,0 ; SETB EN
cbi PORTA,0 ; CLR EN
ret

set_cursor_to_row_1:
cbi PORTA, 1 ; CLR RS
ldi temp, 0b10000000
out PORTB, temp
out PORTC, temp
out PORTE, temp
sbi PORTA,0 ; SETB EN
cbi PORTA,0 ; CLR EN
ret

set_cursor_to_row_2:
cbi PORTA, 1 ; CLR RS
ldi temp, 0b11000000
out PORTB, temp
out PORTC, temp
out PORTE, temp
sbi PORTA,0 ; SETB EN
cbi PORTA,0 ; CLR EN
ret

set_cursor_to_row_3:
cbi PORTA, 1 ; CLR RS
ldi temp, 0b10010100
out PORTB, temp
out PORTC, temp
out PORTE, temp
sbi PORTA,0 ; SETB EN
cbi PORTA,0 ; CLR EN
ret

set_cursor_to_row_4:
cbi PORTA, 1 ; CLR RS
ldi temp, 0b11010100
out PORTB, temp
out PORTC, temp
out PORTE, temp
sbi PORTA,0 ; SETB EN
cbi PORTA,0 ; CLR EN
ret

write_text:
sbi PORTA,1 ; SETB RS
mov YH, ZH
mov YL, ZL
ld temp, Y
out PORTB, temp
adiw Y, 32
adiw Y, 32
ld temp, Y
out PORTC, temp
adiw Y, 32
adiw Y, 32
ld temp, Y
out PORTE, temp
sbi PORTA,0 ; SETB EN
cbi PORTA,0 ; CLR EN
ret

; ================================================================================================= ;

start:
reti

pause:
reti

update:
in temp, PORTA
ldi immediate, 0b11100000
eor temp, immediate
out PORTA, temp
rcall update_position
rcall update_lcd
reti

update_position:
ldi ZH, high(snake_position)
ldi ZL, low(snake_position)
add ZL, length
mov YH, ZH
mov YL, ZL
sbiw Y, 2
sbiw Z, 1
ld temp, Z
mov target, temp
rcall set_white_block
rcall update_body

ldi ZH, high(snake_position)
ldi ZL, low(snake_position)
ld temp, Z
cpi arah, 0x10
brne skip_atas
subi temp, 16
skip_atas:
cpi arah, 0x20
brne skip_bawah
subi temp, -16
skip_bawah:
cpi arah, 0x40
brne skip_kanan
subi temp, -1
skip_kanan:
cpi arah, 0x80
brne skip_kiri
subi temp, 1
skip_kiri:

mov target, temp
rcall set_black_block
ldi ZH, high(snake_position)
ldi ZL, low(snake_position)
st Z, temp ; posisi kepala sekarang
ret

update_body:
ld temp, Y
cpi temp, 0xFF
breq end_update_body
ld temp, Z
mov target, temp
rcall shift_if_not_zero
ld temp, Z
mov target, temp
rcall set_black_block
sbiw Y, 1
sbiw Z, 1
rjmp update_body
end_update_body:
ret

shift_if_not_zero:
ld temp, Y
cpi temp, 0xFF
breq end_shift_if_not_zero
st Z, temp
end_shift_if_not_zero:
ret

set_white_block:
ldi XH, 0
mov XL, target
ldi immediate, 0x10
st X, immediate
ret

set_black_block:
ldi XH, 0
mov XL, target
ldi immediate, 0xFF
st X, immediate
ret

update_lcd:
ldi ZH, high(lcd_content)
ldi ZL, low(lcd_content)
ldi counter, 16
rcall set_cursor_to_row_1
rcall update_row
ldi counter, 16
rcall set_cursor_to_row_2
rcall update_row
ldi counter, 16
rcall set_cursor_to_row_3
rcall update_row
ldi counter, 16
rcall set_cursor_to_row_4
rcall update_row
ret

update_row:
cpi counter, 0
breq end_update_row
rcall write_text
adiw ZL, 1
dec counter
rjmp update_row
end_update_row:
ret

; ================================================================================================= ;

message_lose:
.db "YOU LOSE"
.db 0
message_time_up:
.db "TIME UP"
.db 0
message_press_start:
.db "PRESS START"
.db 0

initial_state:
.db 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10
.db 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10
.db 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10
.db 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10
.db 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10
.db 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10
.db 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10
.db 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10
.db 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10
.db 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10
.db 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10
.db 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10
.db 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF
.db 0x71, 0x70, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
