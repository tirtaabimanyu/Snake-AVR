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

; crashed
; 0 Snake doesn't crash into anything
; 1 Snake crashed into itself
; 2 Snake crashed into a food

; arah
; 0x10 atas
; 0x20 bawah
; 0x40 kanan
; 0x80 kiri

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

; ============================================================================================== ;

reset:

; Menginisialisasi nilai dari Stack Pointer
init_stack:
	ldi temp, low(RAMEND)
	out SPL, temp
	ldi temp, high(RAMEND)
	out SPH, temp
end_init_stack:

; Menginisialisasi pengaturan I/O dan interrupt
init_component:
	rcall init_port			
	rcall init_interrupt
	rcall init_lcd
end_init_component:

; Menampilkan halaman awal ketika memulai permainan
landing:
	rcall init_landing
	landing_wait:
		cpi status, 0
		breq landing_wait
	end_landing_wait:
end_landing:

; Mengatur nilai awal dari variabel-variabel yang akan digunakan
; dan juga nilai awal dari SRAM
init_game:
	rcall init_timer
	rcall init_led
	rcall init_status
	rcall update_status

	; Nilai awal dari variabel
	ldi length, 0x02
	ldi arah, 0x40
	ldi head_row, 0x01
	ldi head_col, 0x01

	; Nilai awal dari SRAM
	ldi YH, high(lcd_content)
	ldi YL, low(lcd_content)
	ldi ZH, high(initial_state*2)
	ldi ZL, low(initial_state*2)
	ldi counter, 200
	rcall flash_to_sram
	ldi counter, 132
	rcall flash_to_sram

	; Memunculkan makanan untuk pertama kali
	rcall spawn_food

	; Menginisialisasi nilai dari best score, your score, dan time left
	ldi ZL, low(saved_score_h)
	ldi ZH, high(saved_score_h)
	ld temp, Z
	; Menentukan apakah sudah pernah ada best score sebelumnya
	cpi temp, 0xFF
	breq belum_pernah_main
		; Jika sudah pernah main, maka gunakan best score sebelumnya
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
		; Jika belum pernah main, maka best scorenya 0
		ldi XL, low(best_score_l)
		ldi XH, high(best_score_l)
		ldi temp, low(digits*2)
		st X, temp
		ldi XL, low(best_score_h)
		ldi XH, high(best_score_h)
		ldi temp, high(digits*2)
		st X, temp
	init_yang_lain:
		; Inisialisasi score awal menjadi 0
		ldi XL, low(your_score_l)
		ldi XH, high(your_score_l)
		ldi temp, low(digits*2)
		st X, temp
		ldi XL, low(your_score_h)
		ldi XH, high(your_score_h)
		ldi temp, high(digits*2)
		st X, temp
		; Inisialisasi time left awal menjadi 128
		ldi XL, low(time_left_l)
		ldi XH, high(time_left_l)
		ldi temp, low(time*2)
		st X, temp
		ldi XL, low(time_left_h)
		ldi XH, high(time_left_h)
		ldi temp, high(time*2)
		st X, temp
	end_init_yang_lain:
end_init_game:

; Program utama
forever:
	; Mengecek apakah waktu sudah habis
	cpi status, 3
	brne skip_time_up
		rcall time_up
		rcall save_score
		rcall delay
		rjmp landing
	skip_time_up:
	; Mengecek apakah nyawa sudah habis
	cpi status, 4
	brne skip_you_lose
		rcall you_lose
		rcall save_score
		rcall delay
		rjmp landing
	skip_you_lose:

	; Mengecek input dari button
	in button, PIND
	cpi button, 0
	breq forever
	; Mengecek jika tombol start yang ditekan
	cpi button, 4
	breq forever
	; Mengecek jika tombol pause yang ditekan
	cpi button, 8
	breq forever

	; Mengecek jika arahnya berlawanan dengan arah sekarang
	; Jika arahnya berlawanan maka tidak diubah
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

; ============================================================================================== ;

; Memindahkan data awal di program memory ke data memory
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

; Delay selama 200ms
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

; Menghilangkan semua tulisan di lcd 1 dan 2
clear_lcd:
	cbi PORTA, 1 ; CLR RS
	ldi temp, 0b00000001 ; MOV DATA,0x01
	out PORTB, temp
	out PORTC, temp
	sbi PORTA,0 ; SETB EN
	cbi PORTA,0 ; CLR EN
ret

; Menghilangkan semua tulisan di lcd 3
clear_lcd_3:
	cbi PORTA, 3 ; CLR RS
	ldi temp, 0b00000001 ; MOV DATA,0x01
	out PORTE, temp
	sbi PORTA,2 ; SETB EN
	cbi PORTA,2 ; CLR EN
ret

; Mengatur cursor agar ke awal baris 1 di lcd 1 dan 2
set_cursor_to_row_1:
	cbi PORTA, 1 ; CLR RS
	ldi temp, 0b10000000
	out PORTB, temp
	out PORTC, temp
	sbi PORTA,0 ; SETB EN
	cbi PORTA,0 ; CLR EN
ret

; Mengatur cursor agar ke awal baris 2 di lcd 1 dan 2
set_cursor_to_row_2:
	cbi PORTA, 1 ; CLR RS
	ldi temp, 0b11000000
	out PORTB, temp
	out PORTC, temp
	sbi PORTA,0 ; SETB EN
	cbi PORTA,0 ; CLR EN
ret

; Mengatur cursor agar ke awal baris 3 di lcd 1 dan 2
set_cursor_to_row_3:
	cbi PORTA, 1 ; CLR RS
	ldi temp, 0b10010100
	out PORTB, temp
	out PORTC, temp
	sbi PORTA,0 ; SETB EN
	cbi PORTA,0 ; CLR EN
ret

; Mengatur cursor agar ke awal baris 4 di lcd 1 dan 2
set_cursor_to_row_4:
	cbi PORTA, 1 ; CLR RS
	ldi temp, 0b11010100
	out PORTB, temp
	out PORTC, temp
	sbi PORTA,0 ; SETB EN
	cbi PORTA,0 ; CLR EN
ret

; Menuliskan konten lcd dari SRAM ke DDRAM
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

; Menuliskan string dari program memory ke LCD
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

; ============================================================================================== ;

; Menginisialisasi nilai I/O
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

; Menyetel tipe external interrupt yang digunakan
init_interrupt:
	ldi temp, 0b00001010
	out MCUCR, temp
	ldi temp, 0b11000000
	out GICR, temp
	sei
ret

; Menyetel tipe internal interrupt yang digunakan
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

; Menyetel nilai awal LED
init_led:
	ldi temp, 0b11100000
	out PORTA, temp
ret

; Menyetel nilai awal LCD
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
	rcall clear_lcd_3
ret

; Menampilkan halaman awal dari permainan
init_landing:
	; Menampilkan tulisan PRESS START
	rcall clear_lcd_3
	cbi PORTA, 3 ; CLR RS
	ldi temp, 0b11000010
	out PORTE, temp
	sbi PORTA, 2 ; SETB EN
	cbi PORTA, 2 ; CLR EN
	ldi ZL, low(message_press_start*2)
	ldi ZH, high(message_press_start*2)
	rcall write_string
	; Menampilkan tulisan TO PLAY
	cbi PORTA, 3 ; CLR RS
	ldi temp, 0b10011000
	out PORTE, temp
	sbi PORTA, 2 ; SETB EN
	cbi PORTA, 2 ; CLR EN
	ldi ZL, low(message_to_play*2)
	ldi ZH, high(message_to_play*2)
	rcall write_string
ret

; Menampilkan halaman permainan ketika sedang dihentikan
init_paused:
	; Menampilkan tulisan PRESS PAUSE
	rcall clear_lcd_3
	cbi PORTA, 3 ; CLR RS
	ldi temp, 0b11000010
	out PORTE, temp
	sbi PORTA, 2 ; SETB EN
	cbi PORTA, 2 ; CLR EN
	ldi ZL, low(message_press_pause*2)
	ldi ZH, high(message_press_pause*2)
	rcall write_string
	; Menampilkan tulisan TO RESUME
	cbi PORTA, 3 ; CLR RS
	ldi temp, 0b10010111
	out PORTE, temp
	sbi PORTA, 2 ; SETB EN
	cbi PORTA, 2 ; CLR EN
	ldi ZL, low(message_to_resume*2)
	ldi ZH, high(message_to_resume*2)
	rcall write_string
ret

; Menampilkan tulisan TIME UP di layar ketika waktu sudah habis
time_up:
	; Mengubah status menjadi permainan belum dimulai
	ldi status, 0
	; Mematikan timer 1
	ldi temp, 0
	out TCCR1B, temp
	sei
	; Menampilkan tulisan TIME UP
	rcall clear_lcd_3
	cbi PORTA, 3 ; CLR RS
	ldi temp, 0b11000100
	out PORTE, temp
	sbi PORTA, 2 ; SETB EN
	cbi PORTA, 2 ; CLR EN
	ldi ZL, low(message_time_up*2)
	ldi ZH, high(message_time_up*2)
	rcall write_string
ret

; Menampilkan tulisan YOU LOSE di layar ketika nyawa sudah habis
you_lose:
	; Mengubah status menjadi permainan belum dimulai
	ldi status, 0
	; Mematikan timer 1
	ldi temp, 0
	out TCCR1B, temp
	sei
	; Menampilkan tulisan YOU LOSE
	rcall clear_lcd_3
	cbi PORTA, 3 ; CLR RS
	ldi temp, 0b11000100
	out PORTE, temp
	sbi PORTA, 2 ; SETB EN
	cbi PORTA, 2 ; CLR EN
	ldi ZL, low(message_you_lose*2)
	ldi ZH, high(message_you_lose*2)
	rcall write_string
ret

; Menyimpan score ketika habis bermain
; dan menentukan apakah itu best score atau bukan
save_score:
	; Mengambil alamat high dari best score
	ldi ZL, low(best_score_h)
	ldi ZH, high(best_score_h)
	ld temp, Z
	; Mengambil alamat high dari your score
	ldi YL, low(your_score_h)
	ldi YH, high(your_score_h)
	ld immediate, Y
	; Mengecek apakah alamat high your score sama
	; dengan alamat high best score
	; Jika sama maka harus ditentukan dari alamat lownya,
	; Jika tidak bisa ditentukan dari alamat highnya saja
	cp immediate, temp
	brne highnya_gak_sama
		; Mengambil alamat low dari best score
		ldi ZL, low(best_score_l)
		ldi ZH, high(best_score_l)
		ld temp, Z
		; Mengambil alamat high dari best score
		ldi YL, low(your_score_l)
		ldi YH, high(your_score_l)
		ld immediate, Y
		; Mengecek apakah alamat low your score
		; lebih tinggi dari alamat low best score
		; Jika iya maka saved score diupdate
		; Jika tidak maka sudahi fungsi ini
		cp immediate, temp
		brlt end_save_score
		; Mengupdate saved score
		rcall update_saved_score
		rjmp end_save_score
	highnya_gak_sama:
		; Jika your score lebih tinggi dari best score
		; maka saved score diupdate
		; Jika tidak, maka langsung sudahi fungsi ini
		brlt end_save_score
		; Mengupdate saved score
		rcall update_saved_score
end_save_score:
ret

; Menyimpan your score di saved score
update_saved_score:
	; Mengambil alamat high your score
	ldi ZL, low(your_score_h)
	ldi ZH, high(your_score_h)
	ld temp, Z
	; Mengambil alamat high saved score
	ldi ZL, low(saved_score_h)
	ldi ZH, high(saved_score_h)
	; Menyimpan alamat high your score di alamat high saved score
	st Z, temp
	; Mengambil alamat low your score
	ldi ZL, low(your_score_l)
	ldi ZH, high(your_score_l)
	ld temp, Z
	; Mengambil alamat low saved score
	ldi ZL, low(saved_score_l)
	ldi ZH, high(saved_score_l)
	; Menyimpan alamat low your score di alamat high saved score
	st Z, temp
end_update_saved_score:
ret

; Menampilkan tulisan yang ada di layar status
init_status:
	rcall clear_lcd_3
	; Menampilkan tulisan BEST SCORE
	cbi PORTA, 3 ; CLR RS
	ldi temp, 0b10000000
	out PORTE, temp
	sbi PORTA, 2 ; SETB EN
	cbi PORTA, 2 ; CLR EN
	ldi ZL, low(message_best_score*2)
	ldi ZH, high(message_best_score*2)
	rcall write_string
	; Menampilkan tulisan YOUR SCORE
	cbi PORTA, 3 ; CLR RS
	ldi temp, 0b11000000
	out PORTE, temp
	sbi PORTA, 2 ; SETB EN
	cbi PORTA, 2 ; CLR EN
	ldi ZL, low(message_your_score*2)
	ldi ZH, high(message_your_score*2)
	rcall write_string
	; Menampilkan tulisan TIME LEFT
	cbi PORTA, 3 ; CLR RS
	ldi temp, 0b11010100
	out PORTE, temp
	sbi PORTA, 2 ; SETB EN
	cbi PORTA, 2 ; CLR EN
	ldi ZL, low(message_time_left*2)
	ldi ZH, high(message_time_left*2)
	rcall write_string
ret

; ============================================================================================== ;

; Fungsi dummy untuk timer 0
dummy:
reti

; Fungsi untuk external interrupt 1
start:
	; Mengecek apakah permainan sudah dimulai
	; Jika sudah maka langsung sudahi fungsi ini
	cpi status, 0
	brne end_start
	; Jika belum maka ubah status menjadi 1 (permainan sedang berjalan)
	ldi status, 1
end_start:
reti

; Fungsi untuk external interrupt 2
pause:
push temp
	; Mengecek apakah permainan sudah dimulai
	; Jika belum maka langsung sudahi fungsi ini
	cpi status, 0
	breq end_pause
	cpi status, 1
	breq pause_game
		; Jika permainan sedang dihentikan, maka jalankan lagi permainannya
		; Munculkan layar status
		rcall init_status
		; Status diubah menjadi 1 (permainan sedang berjalan)
		ldi status, 1
		; Nilai TCCR1B diubah menjadi clockspeed/8
		ldi temp, (1<<CS11)
		rjmp update_timer
	pause_game:
		; Jika permainan sedang berjalan, maka hentikan permainan
		; Munculkan layar ketika permainan berhenti
		rcall init_paused
		; Status diubah menjadi 2 (permainan sedang dihentikan)
		ldi status, 2
		; Nilai TCCR1B diubah menjadi 0 (timer distop)
		ldi temp, 0
	update_timer:
	; Mengupdate nilai timer
	out TCCR1B, temp
	sei
end_pause:
pop temp
reti

; Mengupdate semua nilai yang diperlukan
update:
in temp, SREG
push temp
	; Mengupdate posisi kepala ular
	rcall update_position
	; Mengupdate nilai lcd 1 dan 2
	rcall update_lcd
	; Mengupdate waktu dan score
	rcall update_status
	rcall update_status_lcd
pop temp
out SREG, temp
reti

; Mengupdate posisi kepala ular
update_position:
	; Memajukan badan ular
	ldi ZH, high(snake_position)
	ldi ZL, low(snake_position)
	add ZL, length
	mov YH, ZH
	mov YL, ZL
	sbiw Y, 2
	sbiw Z, 1
	ld temp, Z
	; Simpan posisi ekor sekarang di Stack
	push temp
	; Ubah posisi ekor sekarang menjadi kotak putih
	rcall set_white_block
	; Majukan ular
	rcall update_body

	; Mengambil posisi kepala ular sekarang
	ldi ZH, high(snake_position)
	ldi ZL, low(snake_position)
	ld temp, Z

	; Jika arah sekarang keatas
	cpi arah, 0x10
	brne skip_atas
		; Posisi kepala ular dikurang 1 (naik keatas)
		subi head_row, 1
		; Jika kepala ular keluar arena maka dimunculkan lagi dibawah
		cpi head_row, 0
		brne skip_tembus_atas
			ldi head_row, 8
			subi temp, -128
		skip_tembus_atas:
		subi temp, 16
	skip_atas:
	; Jika arah sekarang kebawah
	cpi arah, 0x20
	brne skip_bawah
		; Posisi kepala ular ditambah 1 (turun kebawah)
		subi head_row, -1
		; Jika kepala ular keluar arena maka dimunculkan lagi di atas
		cpi head_row, 9
		brne skip_tembus_bawah
			ldi head_row, 1
			subi temp, 128
		skip_tembus_bawah:
		subi temp, -16
	skip_bawah:
	; Jika arah sekarang ke kanan
	cpi arah, 0x40
	brne skip_kanan
		; Posisi kepala ular ditambah 1 (geser kanan)
		subi head_col, -1
		; Jika kepala ular keluar arena maka dimunculkan lagi di kiri
		cpi head_col, 17
		brne skip_tembus_kanan
			ldi head_col, 1
			subi temp, 16
		skip_tembus_kanan:
		subi temp, -1
	skip_kanan:
	; Jika arah sekarang ke kiri
	cpi arah, 0x80
	brne skip_kiri
		; Posisi kepala ular dikurang 1 (geser kiri)
		subi head_col, 1
		; Jika kepala ular keluar arena maka dimunculkan lagi di kanan
		cpi head_col, 0
		brne skip_tembus_kiri
			ldi head_col, 16
			subi temp, -16
		skip_tembus_kiri:
		subi temp, 1
	skip_kiri:

	; Cek apakah kepala ular sekarang menabrak sesuatu
	rcall check_if_crash
	; Set posisi kepala ular sekarang menjadi kotak hitam
	rcall set_black_block
	; Simpan posisi kepala ular sekarang di SRAM
	ldi ZH, high(snake_position)
	ldi ZL, low(snake_position)
	st Z, temp

	; Ambil posisi ekor sebelumnya
	pop temp
	; Cek apakah ular menabrak makanan
	; Jika iya maka tambahkan panjang ular
	cpi crashed, 2
	brne skip_add_body
	; Ambil alamat ekor ular sekarang
	ldi ZH, high(snake_position)
	ldi ZL, low(snake_position)
	add ZL, length
	; panjang ular ditambah 1
	subi length, -1
	; Simpan posisi ekor ular di alamat ekor ular
	st Z, temp
	; Ubah posisi ekor ular menjadi kotak hitam
	rcall set_black_block
	skip_add_body:
ret

; Mengecek apakah kepala ular menabrak sesuatu
check_if_crash:
push temp
	mov ZL, temp
	ldi ZH, 0x00
	ld temp, Z
	; Mengecek jika kepala ular menabrak dirinya
	cpi temp, 0xFF
	brne skip_set_crash
		; Status crashed diubah menjadi 1 (menabrak diri sendiri)
		ldi crashed, 1
	skip_set_crash:
	; Mengecek jika kepala ular menabrak makanan
	cpi temp, 0x2A
	brne end_check_if_crash
		; Status crashed diubah menjadi 2 (menabrak makanan)
		ldi crashed, 2
		; Makanan baru dimunculkan
		rcall spawn_food
end_check_if_crash:
pop temp
ret

; Mengupdate posisi semua badan ular
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

; Menggeser badan sekarang ke posisi selanjutnya
shift_if_not_zero:
	ld temp, Y
	cpi temp, 0xFF
	breq end_shift_if_not_zero
	st Z, temp
end_shift_if_not_zero:
ret

; Mengubah konten lcd di alamat temp menjadi kotak putih (arena)
set_white_block:
	ldi XH, 0
	mov XL, temp
	ldi immediate, 0x10
	st X, immediate
ret

; Mengubah konten lcd di alamat temp menjadi kotak hitam (badan ular)
set_black_block:
	ldi XH, 0
	mov XL, temp
	ldi immediate, 0xFF
	st X, immediate
ret

; Mengupdate nilai lcd dari SRAM
update_lcd:
	; Mengambil nilai awal konten lcd di SRAM
	ldi ZH, high(lcd_content)
	ldi ZL, low(lcd_content)
	; Mengupdate baris pertama
	ldi counter, 16
	rcall set_cursor_to_row_1
	rcall update_row
	; Mengupdate baris kedua
	ldi counter, 16
	rcall set_cursor_to_row_2
	rcall update_row
	; Mengupdate baris ketiga
	ldi counter, 16
	rcall set_cursor_to_row_3
	rcall update_row
	; Mengupdate baris keempat
	ldi counter, 16
	rcall set_cursor_to_row_4
	rcall update_row
ret

; Mengupdate nilai lcd di satu baris
update_row:
	cpi counter, 0
	breq end_update_row
	rcall write_text
	adiw ZL, 1
	dec counter
	rjmp update_row
end_update_row:
ret

; Mengupdate nilai dari waktu dan score
update_status:
	; Mengurangi waktu sebanyak 1 satuan
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

	; Cek apakah waktu sudah habis
	lpm temp, Z
	cpi temp, 0xFF
	brne skip_set_status_time_up
		; Jika iya ubah status jadi time up
		ldi status, 3
	skip_set_status_time_up:
	
	; Cek apakah ular menabrak dirinya sendiri
	cpi crashed, 1
	brne skip_decrease_lives
	; Jika iya kurangi nyawa sebanyak 1
	in temp, PORTA
	lsl temp
	out PORTA, temp
	skip_decrease_lives:

	; Cek apakah nyawa sudah habis
	cpi temp, 0
	brne skip_set_game_over
	; Jika iya set status menjadi game over
	ldi status, 4
	skip_set_game_over:

	; Cek apakah ular menabrak makanan
	cpi crashed, 2
	brne skip_get_point
	; Jika iya tambah your score sebanyak 1
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

	; Setelah ditambah scorenya atau dikurangi nyawanya
	; status crashed direset lagi
	ldi crashed, 0
end_update_status:
ret

; Update lcd status menjadi isinya yang terbaru
update_status_lcd:
	; Update nilai best score
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
	; Update nilai your score
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
	; Update nilai time left
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

; Memunculkan makanan di permainan
; dengan cara mengambil nilai dari TCNT0
; untuk dijadikan random number generator
spawn_food:
	; Mengambil nilai TCNT0 dan menjadikannya di range 96 sampai 224
	; karena arenanya 16x8 dan dimulai dari alamat 96
	in temp, TCNT0
	lsr temp
	subi temp, -96
	ldi ZH, 0
	mov ZL, temp
	ld temp, Z
	; Mengecek apakah di alamat tersebut sudah ada benda lain (badan ularnya)
	; Jika ada, cari alamat lain dengan mengulang fungsi ini
	cpi temp, 0xFF
	breq spawn_food
	; Membuat alamat tersebut menjadi makanan
	ldi temp, 0x2A
	st Z, temp
ret

; ============================================================================================== ;

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

