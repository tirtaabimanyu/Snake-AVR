.include "m8515def.inc"

; PORTA buat Enable, RS, dan LED
; 0 Enable LCD 1, LCD 2 (Input)
; 1 RS LCD 1, LCD 2 (Input)
; 2 Enable LCD 3
; 3 RS LCD 3
; 4 - 
; 5 LED (Output)
; 6 LED (Output)
; 7 LED (Output)

; PORTB buat DDRAM LCD 1
; PORTC buat DDRAM LCD 2

; PORTD buat Button
; 0 -
; 1 -
; 2 Start (Input)
; 3 Pause (Input)
; 4 Atas (Input)
; 5 Bawah (Input)
; 6 Kanan (Input)
; 7 Kiri (Input)

; PORTE buat DDRAM LCD 3

; status
; 0 The game hasn't started yet
; 1 The game is running
; 2 Paused
; 3 Time up
; 4 0 Life

.def temp = r16
.def immediate = r17
.def counter = r18
.def arah = r19
.def status = r20
.def button = r21
.def length = r22
.def head_row = r23
.def head_col = r24
.def crashed = r25

.equ lcd_content = 0x60
.equ snake_position = 0x100
.equ best_score_l = 0x1A0
.equ best_score_h = 0x1A1
.equ your_score_l = 0x1A4
.equ your_score_h = 0x1A5
.equ time_left_l =  0x1A8
.equ time_left_h =  0x1A9
.equ saved_score_l = 0x1AC
.equ saved_score_h = 0x1AD

.org $00 rjmp reset
.org $01 rjmp start
.org $02 rjmp pause
.org $06 rjmp update
.org $07 rjmp dummy

; ================================================================================================= ;

reset:

init_stack:
ldi temp, low(RAMEND)
out SPL, temp
ldi temp, high(RAMEND)
out SPH, temp
rcall init_port
rcall init_interrupt
rcall init_lcd

landing:
rcall init_landing
landing_wait:
cpi status, 0
breq landing_wait

init_game:
rcall init_timer
rcall init_led
rcall init_status
rcall update_status

ldi length, 0x02
ldi arah, 0x40
ldi head_row, 0x01
ldi head_col, 0x01
ldi YH, high(lcd_content)
ldi YL, low(lcd_content)
ldi ZH, high(initial_state*2)
ldi ZL, low(initial_state*2)
ldi counter, 200
rcall flash_to_sram
ldi counter, 132
rcall flash_to_sram
rcall spawn_food

ldi ZL, low(saved_score_h)
ldi ZH, high(saved_score_h)
ld temp, Z
cpi temp, 0xFF
breq belum_pernah_main
	ldi XL, low(best_score_l)
	ldi XH, high(best_score_l)
	ldi YL, low(saved_score_l)
	ldi YH, high(saved_score_l)
	ld temp, Y
	st X, temp
	ldi XL, low(best_score_h)
	ldi XH, high(best_score_h)
	ldi YL, low(saved_score_h)
	ldi YH, high(saved_score_h)
	ld temp, Y
	st X, temp
	rjmp init_yang_lain
belum_pernah_main:
	ldi XL, low(best_score_l)
	ldi XH, high(best_score_l)
	ldi temp, low(digits*2)
	st X, temp
	ldi XL, low(best_score_h)
	ldi XH, high(best_score_h)
	ldi temp, high(digits*2)
	st X, temp
init_yang_lain:
ldi XL, low(your_score_l)
ldi XH, high(your_score_l)
ldi temp, low(digits*2)
st X, temp
ldi XL, low(your_score_h)
ldi XH, high(your_score_h)
ldi temp, high(digits*2)
st X, temp
ldi XL, low(time_left_l)
ldi XH, high(time_left_l)
ldi temp, low(time*2)
st X, temp
ldi XL, low(time_left_h)
ldi XH, high(time_left_h)
ldi temp, high(time*2)
st X, temp

forever:
	cpi status, 3
	brne skip_time_up
	rcall time_up
	rcall save_score
	rjmp landing
	skip_time_up:
	cpi status, 4
	brne skip_you_lose
	rcall you_lose
	rcall save_score
	rjmp landing
	skip_you_lose:
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
sbi PORTA,0 ; SETB EN
cbi PORTA,0 ; CLR EN
ret

clear_lcd_3:
cbi PORTA, 3 ; CLR RS
ldi temp, 0b00000001 ; MOV DATA,0x01
out PORTE, temp
sbi PORTA,2 ; SETB EN
cbi PORTA,2 ; CLR EN
ret

set_cursor_to_row_1:
cbi PORTA, 1 ; CLR RS
ldi temp, 0b10000000
out PORTB, temp
out PORTC, temp
sbi PORTA,0 ; SETB EN
cbi PORTA,0 ; CLR EN
ret

set_cursor_to_row_2:
cbi PORTA, 1 ; CLR RS
ldi temp, 0b11000000
out PORTB, temp
out PORTC, temp
sbi PORTA,0 ; SETB EN
cbi PORTA,0 ; CLR EN
ret

set_cursor_to_row_3:
cbi PORTA, 1 ; CLR RS
ldi temp, 0b10010100
out PORTB, temp
out PORTC, temp
sbi PORTA,0 ; SETB EN
cbi PORTA,0 ; CLR EN
ret

set_cursor_to_row_4:
cbi PORTA, 1 ; CLR RS
ldi temp, 0b11010100
out PORTB, temp
out PORTC, temp
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
sbi PORTA,0 ; SETB EN
cbi PORTA,0 ; CLR EN
cbi PORTA,1
ret

write_string:
lpm
tst r0
breq end_write_string
sbi PORTA, 3
out PORTE, r0
sbi PORTA, 2
cbi PORTA, 2
cbi PORTA, 3
adiw Z, 1
rjmp write_string
end_write_string:
ret

delay:
    ldi  XL, 9
    ldi  XH, 30
    ldi  YL, 229
L1: dec  YL
    brne L1
    dec  XH
    brne L1
    dec  XL
    brne L1
    nop
ret

; ================================================================================================= ;

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
ret

init_interrupt:
ldi temp, 0b00001010
out MCUCR, temp
ldi temp, 0b11000000
out GICR, temp
sei
ret

init_timer:
ldi temp, (1<<CS11)
out TCCR1B, temp
ldi temp, (1<<CS00)
out TCCR0, temp
ldi temp, (1<<TOV1) | (1<<TOV0)
out TIFR, temp
ldi temp, (1<<TOIE1) | (1<<TOIE0)
out TIMSK, temp
sei
ret

init_led:
ldi temp, 0b11100000
out PORTA, temp
ret

init_lcd:
cbi PORTA, 1 ; CLR RS
cbi PORTA, 3 ; CLR RS
ldi temp, 0b00111000 ; MOV DATA,0x38 --> 8bit, 2line, 5x7
out PORTB, temp
out PORTC, temp
out PORTE, temp
sbi PORTA,0 ; SETB EN
cbi PORTA,0 ; CLR EN
sbi PORTA,2 ; SETB EN
cbi PORTA,2 ; CLR EN

cbi PORTA, 1 ; CLR RS
cbi PORTA, 3 ; CLR RS
ldi temp, 0b00001100 ; MOV DATA,0x0C --> disp ON, cursor OFF, blink OFF
out PORTB, temp
out PORTC, temp
out PORTE, temp
sbi PORTA,0 ; SETB EN
cbi PORTA,0 ; CLR EN
sbi PORTA,2 ; SETB EN
cbi PORTA,2 ; CLR EN

cbi PORTA,1 ; CLR RS
cbi PORTA,3 ; CLR RS
ldi temp, 0b00000110 ; MOV DATA,0x06 --> increase cursor, display scroll OFF
out PORTB, temp
out PORTC, temp
out PORTE, temp
sbi PORTA,0 ; SETB EN
cbi PORTA,0 ; CLR EN
sbi PORTA,2 ; SETB EN
cbi PORTA,2 ; CLR EN
rcall clear_lcd
ret

init_landing:
rcall clear_lcd_3
cbi PORTA, 3 ; CLR RS
ldi temp, 0b11000010
out PORTE, temp
sbi PORTA, 2 ; SETB EN
cbi PORTA, 2 ; CLR EN
ldi ZL, low(message_press_start*2)
ldi ZH, high(message_press_start*2)
rcall write_string
cbi PORTA, 3 ; CLR RS
ldi temp, 0b10011000
out PORTE, temp
sbi PORTA, 2 ; SETB EN
cbi PORTA, 2 ; CLR EN
ldi ZL, low(message_to_play*2)
ldi ZH, high(message_to_play*2)
rcall write_string
ret

init_paused:
rcall clear_lcd_3
cbi PORTA, 3 ; CLR RS
ldi temp, 0b11000010
out PORTE, temp
sbi PORTA, 2 ; SETB EN
cbi PORTA, 2 ; CLR EN
ldi ZL, low(message_press_pause*2)
ldi ZH, high(message_press_pause*2)
rcall write_string
cbi PORTA, 3 ; CLR RS
ldi temp, 0b10010111
out PORTE, temp
sbi PORTA, 2 ; SETB EN
cbi PORTA, 2 ; CLR EN
ldi ZL, low(message_to_resume*2)
ldi ZH, high(message_to_resume*2)
rcall write_string
ret

time_up:
ldi status, 0
ldi temp, 0
out TCCR1B, temp
sei
rcall clear_lcd_3
cbi PORTA, 3 ; CLR RS
ldi temp, 0b11000100
out PORTE, temp
sbi PORTA, 2 ; SETB EN
cbi PORTA, 2 ; CLR EN
ldi ZL, low(message_time_up*2)
ldi ZH, high(message_time_up*2)
rcall write_string
rcall delay
ret

you_lose:
ldi status, 0
ldi temp, 0
out TCCR1B, temp
sei
rcall clear_lcd_3
cbi PORTA, 3 ; CLR RS
ldi temp, 0b11000100
out PORTE, temp
sbi PORTA, 2 ; SETB EN
cbi PORTA, 2 ; CLR EN
ldi ZL, low(message_you_lose*2)
ldi ZH, high(message_you_lose*2)
rcall write_string
rcall delay
ret

save_score:
ldi ZL, low(best_score_h)
ldi ZH, high(best_score_h)
ld temp, Z
ldi YL, low(your_score_h)
ldi YH, high(your_score_h)
ld immediate, Y
cp immediate, temp
brne highnya_gak_sama
	ldi ZL, low(best_score_l)
	ldi ZH, high(best_score_l)
	ld temp, Z
	ldi YL, low(your_score_l)
	ldi YH, high(your_score_l)
	ld immediate, Y
	cp immediate, temp
	brlt end_save_score
		ldi ZL, low(your_score_h)
		ldi ZH, high(your_score_h)
		ld temp, Z
		ldi ZL, low(saved_score_h)
		ldi ZH, high(saved_score_h)
		st Z, temp
		ldi ZL, low(your_score_l)
		ldi ZH, high(your_score_l)
		ld temp, Z
		ldi ZL, low(saved_score_l)
		ldi ZH, high(saved_score_l)
		st Z, temp
	rjmp end_save_score
highnya_gak_sama:
	brlt end_save_score
		ldi ZL, low(your_score_h)
		ldi ZH, high(your_score_h)
		ld temp, Z
		ldi ZL, low(saved_score_h)
		ldi ZH, high(saved_score_h)
		st Z, temp
		ldi ZL, low(your_score_l)
		ldi ZH, high(your_score_l)
		ld temp, Z
		ldi ZL, low(saved_score_l)
		ldi ZH, high(saved_score_l)
		st Z, temp
end_save_score:
ret

init_status:
rcall clear_lcd_3
cbi PORTA, 3 ; CLR RS
ldi temp, 0b10000000
out PORTE, temp
sbi PORTA, 2 ; SETB EN
cbi PORTA, 2 ; CLR EN
ldi ZL, low(message_best_score*2)
ldi ZH, high(message_best_score*2)
rcall write_string
cbi PORTA, 3 ; CLR RS
ldi temp, 0b11000000
out PORTE, temp
sbi PORTA, 2 ; SETB EN
cbi PORTA, 2 ; CLR EN
ldi ZL, low(message_your_score*2)
ldi ZH, high(message_your_score*2)
rcall write_string
cbi PORTA, 3 ; CLR RS
ldi temp, 0b11010100
out PORTE, temp
sbi PORTA, 2 ; SETB EN
cbi PORTA, 2 ; CLR EN
ldi ZL, low(message_time_left*2)
ldi ZH, high(message_time_left*2)
rcall write_string
ret

; ================================================================================================= ;

start:
	cpi status, 0
	brne end_start
	ldi status, 1
end_start:
reti

pause:
push temp
	cpi status, 0
	breq end_pause
	cpi status, 1
	breq pause_game
		rcall init_status
		ldi status, 1
		ldi temp, (1<<CS11)
		rjmp update_timer
	pause_game:
		rcall init_paused
		ldi status, 2
		ldi temp, 0
	update_timer:
	out TCCR1B, temp
	sei
end_pause:
pop temp
reti

update:
	in temp, SREG
	push temp
	rcall update_position
	rcall update_lcd
	rcall update_status
	rcall update_status_lcd
	pop temp
	out SREG, temp
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
	push temp
	rcall set_white_block
	rcall update_body

	ldi ZH, high(snake_position)
	ldi ZL, low(snake_position)
	ld temp, Z

	cpi arah, 0x10
	brne skip_atas
	subi head_row, 1
	cpi head_row, 0
	brne skip_tembus_atas
	ldi head_row, 8
	subi temp, -128
	skip_tembus_atas:
	subi temp, 16

	skip_atas:
	cpi arah, 0x20
	brne skip_bawah
	subi head_row, -1
	cpi head_row, 9
	brne skip_tembus_bawah
	ldi head_row, 1
	subi temp, 128
	skip_tembus_bawah:
	subi temp, -16

	skip_bawah:
	cpi arah, 0x40
	brne skip_kanan
	subi head_col, -1
	cpi head_col, 17
	brne skip_tembus_kanan
	ldi head_col, 1
	subi temp, 16
	skip_tembus_kanan:
	subi temp, -1

	skip_kanan:
	cpi arah, 0x80
	brne skip_kiri
	subi head_col, 1
	cpi head_col, 0
	brne skip_tembus_kiri
	ldi head_col, 16
	subi temp, -16
	skip_tembus_kiri:
	subi temp, 1
	skip_kiri:

	rcall check_if_crash
	rcall set_black_block
	ldi ZH, high(snake_position)
	ldi ZL, low(snake_position)
	st Z, temp

	pop temp
	cpi crashed, 2
	brne skip_add_body
	ldi ZH, high(snake_position)
	ldi ZL, low(snake_position)
	add ZL, length
	subi length, -1
	st Z, temp
	rcall set_black_block
	skip_add_body:
ret

check_if_crash:
push temp
	mov ZL, temp
	ldi ZH, 0x00
	ld temp, Z
	cpi temp, 0xFF
	brne skip_set_crash
		ldi crashed, 1
	skip_set_crash:
	cpi temp, 0x2A
	brne end_check_if_crash
		ldi crashed, 2
		rcall spawn_food
end_check_if_crash:
pop temp
ret

update_body:
	ld temp, Y
	cpi temp, 0xFF
	breq end_update_body
	ld temp, Z
	rcall shift_if_not_zero
	ld temp, Z
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
	mov XL, temp
	ldi immediate, 0x10
	st X, immediate
ret

set_black_block:
	ldi XH, 0
	mov XL, temp
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

update_status:
	ldi XL, low(time_left_l)
	ldi XH, high(time_left_l)
	ld ZL, X
	ldi XL, low(time_left_h)
	ldi XH, high(time_left_h)
	ld ZH, X
	adiw Z, 4
	ldi XL, low(time_left_l)
	ldi XH, high(time_left_l)
	st X, ZL
	ldi XL, low(time_left_h)
	ldi XH, high(time_left_h)
	st X, ZH

	lpm temp, Z
	cpi temp, 0xFF
	brne skip_set_status_time_up
		ldi status, 3
	skip_set_status_time_up:
	
	cpi crashed, 1
	brne skip_decrease_lives
	in temp, PORTA
	lsl temp
	out PORTA, temp
	skip_decrease_lives:

	cpi temp, 0
	brne skip_set_game_over
	ldi status, 4
	skip_set_game_over:

	cpi crashed, 2
	brne skip_get_point
	ldi XL, low(your_score_l)
	ldi XH, high(your_score_l)
	ld ZL, X
	ldi XL, low(your_score_h)
	ldi XH, high(your_score_h)
	ld ZH, X
	adiw Z, 4
	ldi XL, low(your_score_l)
	ldi XH, high(your_score_l)
	st X, ZL
	ldi XL, low(your_score_h)
	ldi XH, high(your_score_h)
	st X, ZH
	skip_get_point:	
	ldi crashed, 0

end_update_status:
ret

update_status_lcd:
	cbi PORTA, 3 ; CLR RS
	ldi temp, 0b10001101
	out PORTE, temp
	sbi PORTA, 2 ; SETB EN
	cbi PORTA, 2 ; CLR EN
	ldi XL, low(best_score_l)
	ldi XH, high(best_score_l)
	ld ZL, X
	ldi XL, low(best_score_h)
	ldi XH, high(best_score_h)
	ld ZH, X
	rcall write_string
	cbi PORTA, 3 ; CLR RS
	ldi temp, 0b11001101
	out PORTE, temp
	sbi PORTA, 2 ; SETB EN
	cbi PORTA, 2 ; CLR EN
	ldi XL, low(your_score_l)
	ldi XH, high(your_score_l)
	ld ZL, X
	ldi XL, low(your_score_h)
	ldi XH, high(your_score_h)
	ld ZH, X
	rcall write_string
	cbi PORTA, 3 ; CLR RS
	ldi temp, 0b11100001
	out PORTE, temp
	sbi PORTA, 2 ; SETB EN
	cbi PORTA, 2 ; CLR EN
	ldi XL, low(time_left_l)
	ldi XH, high(time_left_l)
	ld ZL, X
	ldi XL, low(time_left_h)
	ldi XH, high(time_left_h)
	ld ZH, X
	rcall write_string
ret

spawn_food:
	in temp, TCNT0
	lsr temp
	subi temp, -96
	ldi ZH, 0
	mov ZL, temp
	ld temp, Z
	cpi temp, 0xFF
	breq spawn_food
	ldi temp, 0x2A
	st Z, temp
ret

dummy:
reti

; ================================================================================================= ;

message_you_lose:
.db "YOU LOSE", 0
message_time_up:
.db "TIME UP", 0
message_press_start:
.db "PRESS START", 0
message_to_play:
.db "TO PLAY", 0
message_press_pause:
.db "PRESS PAUSE", 0
message_to_resume:
.db "TO RESUME", 0
message_best_score:
.db "BEST SCORE", 0
message_your_score:
.db "YOUR SCORE", 0
message_time_left:
.db "TIME LEFT", 0

initial_state:
.db 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10
.db 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10
.db 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10
.db 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10
.db 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10
.db 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10
.db 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10
.db 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10
.db 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF
.db 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF
.db 0x60, 0x60, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF
.db 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF
.db 0x00, 0x00, 0xFF, 0xFF, 0x00, 0x00, 0xFF, 0xFF, 0x00, 0x00, 0xFF, 0xFF

digits:
.db "000", 0, "001", 0, "002", 0, "003", 0, "004", 0, "005", 0, "006", 0, "007", 0, "008", 0, "009", 0
.db "010", 0, "011", 0, "012", 0, "013", 0, "014", 0, "015", 0, "016", 0, "017", 0, "018", 0, "019", 0 
.db "020", 0, "021", 0, "022", 0, "023", 0, "024", 0, "025", 0, "026", 0, "027", 0, "028", 0, "029", 0 
.db "030", 0, "031", 0, "032", 0, "033", 0, "034", 0, "035", 0, "036", 0, "037", 0, "038", 0, "039", 0 
.db "040", 0, "041", 0, "042", 0, "043", 0, "044", 0, "045", 0, "046", 0, "047", 0, "048", 0, "049", 0 
.db "050", 0, "051", 0, "052", 0, "053", 0, "054", 0, "055", 0, "056", 0, "057", 0, "058", 0, "059", 0 
.db "060", 0, "061", 0, "062", 0, "063", 0, "064", 0, "065", 0, "066", 0, "067", 0, "068", 0, "069", 0 
.db "070", 0, "071", 0, "072", 0, "073", 0, "074", 0, "075", 0, "076", 0, "077", 0, "078", 0, "079", 0 
.db "080", 0, "081", 0, "082", 0, "083", 0, "084", 0, "085", 0, "086", 0, "087", 0, "088", 0, "089", 0 
.db "090", 0, "091", 0, "092", 0, "093", 0, "094", 0, "095", 0, "096", 0, "097", 0, "098", 0, "099", 0 
.db "100", 0, "101", 0, "102", 0, "103", 0, "104", 0, "105", 0, "106", 0, "107", 0, "108", 0, "109", 0 
.db "110", 0, "111", 0, "112", 0, "113", 0, "114", 0, "115", 0, "116", 0, "117", 0, "118", 0, "119", 0 
.db "120", 0, "121", 0, "122", 0, "123", 0, "124", 0, "125", 0, "126", 0, "127", 0, "128", 0, 0xFF

time:
.db "128", 0, "127", 0, "126", 0, "125", 0, "124", 0, "123", 0, "122", 0, "121", 0, "120", 0
.db "119", 0, "118", 0, "117", 0, "116", 0, "115", 0, "114", 0, "113", 0, "112", 0, "111", 0, "110", 0
.db "109", 0, "108", 0, "107", 0, "106", 0, "105", 0, "104", 0, "103", 0, "102", 0, "101", 0, "100", 0
.db "099", 0, "098", 0, "097", 0, "096", 0, "095", 0, "094", 0, "093", 0, "092", 0, "091", 0, "090", 0
.db "089", 0, "088", 0, "087", 0, "086", 0, "085", 0, "084", 0, "083", 0, "082", 0, "081", 0, "080", 0
.db "079", 0, "078", 0, "077", 0, "076", 0, "075", 0, "074", 0, "073", 0, "072", 0, "071", 0, "070", 0
.db "069", 0, "068", 0, "067", 0, "066", 0, "065", 0, "064", 0, "063", 0, "062", 0, "061", 0, "060", 0
.db "059", 0, "058", 0, "057", 0, "056", 0, "055", 0, "054", 0, "053", 0, "052", 0, "051", 0, "050", 0
.db "049", 0, "048", 0, "047", 0, "046", 0, "045", 0, "044", 0, "043", 0, "042", 0, "041", 0, "040", 0
.db "039", 0, "038", 0, "037", 0, "036", 0, "035", 0, "034", 0, "033", 0, "032", 0, "031", 0, "030", 0
.db "029", 0, "028", 0, "027", 0, "026", 0, "025", 0, "024", 0, "023", 0, "022", 0, "021", 0, "020", 0
.db "019", 0, "018", 0, "017", 0, "016", 0, "015", 0, "014", 0, "013", 0, "012", 0, "011", 0, "010", 0
.db "009", 0, "008", 0, "007", 0, "006", 0, "005", 0, "004", 0, "003", 0, "002", 0, "001", 0, "000", 0, 0xFF

