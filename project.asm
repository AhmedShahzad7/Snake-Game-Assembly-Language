[org 0x0100]

call hide_cursor

start:
call clrscr
mov ax, 20
push ax ; push x position
mov ax, 12
push ax ; push y position
mov ax, 0x0E ;Yellow Attribute
push ax ; push attribute
mov ax, title
push ax ; push address of message
call printstr ; call the printstr subroutine
mov ax, 20
push ax ; push x position
mov ax, 15
push ax ; push y position
mov ax, 0xC7 ; blinking red Attribute
push ax ; push attribute
mov ax, key
push ax ; push address of message
call printstr ; call the printstr subroutine
l1:
mov ah, 0
int 16h
cmp al, 13
jne l1
call clrscr
call start_playing
call show_game_over
jmp start

clrscr:
push es
push ax
push cx
push di
mov ax, 0xb800
mov es, ax ; point es to video base
xor di, di ; point di to top left column
mov ax, 0x3020 ; space char in normal attribute
mov cx, 2000 ; number of screen locations
cld ; auto increment mode
rep stosw ; clear the whole screen
pop di
pop cx
pop ax
pop es
ret

printstr: push bp
mov bp, sp
push es
push ax
push cx
push si
push di
push ds
pop es ; load ds in es
mov di, [bp+4] ; point di to string
mov cx, 0xffff ; load maximum number in cx
xor al, al ; load a zero in al
repne scasb ; find zero in the string
mov ax, 0xffff ; load maximum number in ax
sub ax, cx ; find change in cx
dec ax ; exclude null from length
jz exit ; no printing if string is empty
mov cx, ax ; load string length in cx
mov ax, 0xb800
mov es, ax ; point es to video base
mov al, 80 ; load al with columns per row
mul byte [bp+8] ; multiply with y position
add ax, [bp+10] ; add x position
shl ax, 1 ; turn into byte offset
mov di,ax ; point di to required location
mov si, [bp+4] ; point si to string
mov ah, [bp+6] ; load attribute in ah
cld ; auto increment mode
nextchar: lodsb ; load next char in al
stosw ; print char/attribute pair
loop nextchar ; repeat for the whole string
exit: pop di
pop si
pop cx
pop ax
pop es
pop bp
ret 8

sleep:
mov ah, 0
int 1ah
mov bx, dx
.wait:
mov ah, 0
int 1ah
sub dx, bx
cmp dx, si
jl .wait
ret

hide_cursor:
mov ah, 02h ;interupt for setting cursor position
mov bh, 0 ;page number
mov dh, 25 ;row position pointing cursor
mov dl, 0 ;column position pointing cursor
int 10h
ret

clear_keyboard_buffer:
mov ah, 1
int 16h
jz .end
mov ah, 0h ; retrieve key from buffer
int 16h
jmp clear_keyboard_buffer
.end:
ret

exit_process:
mov ah, 4ch
int 21h
ret

buffer_clear:
mov bx, 0
.next:	
mov byte [buffer + bx], ' '
inc bx
cmp bx, 2000
jnz .next
ret
		
; in:
;	bl = char
;	cx = col
;	dl = row
buffer_write:
mov di, buffer
mov al, 80
mul dl
add ax, cx
add di, ax
mov byte [di], bl
ret
	
; in:
;	cx = col
;	dx = row
; out: 
;	bl = char
buffer_read:
mov di, buffer
mov al, 80
mul dl
add ax, cx
add di, ax
mov bl, [di]
ret
	
	; in:
	;	si = string address
	;	di = buffer destination offset
	buffer_print_string:
		.next:
			mov al, [si]
			cmp al, 0
			jz .end
			mov byte [buffer + di], al
			inc di
			inc si
			jmp .next
		.end:
			ret
		
	;   0 = snake right
	;   2 = snake left
	;   4 = snake down
	;   8 = snake up
	; > 8 = ASCII char
	buffer_render:
			mov ax, 0b800h
			mov es, ax
			mov di, buffer
			mov si, 0
		.next:
			mov bl, [di]
			cmp bl, 8
			jz .is_snake
			cmp bl, 4
			jz .is_snake
			cmp bl, 2
			jz .is_snake
			cmp bl, 1
			jz .is_snake
			jmp .write
		.is_snake:
			mov bl, 219 ;Solid block character
		.write:
			mov byte [es:si], bl
			inc di
			add si, 2
			cmp si, 4000
			jnz .next
			ret

	print_score:
			mov si, .text
			mov di, 0
			call buffer_print_string
			mov ax, [score]
			mov di, 13
		.next_digit:
			xor dx, dx
			mov bx, 10
			div bx
			push ax
			mov al, dl
			add al, 48
			mov byte [buffer + di], al
			pop ax
			dec di
			cmp ax, 0
			jnz .next_digit
			ret
		.text:
			db " SCORE: 000000", 0

	update_snake_direction:
			mov ah, 1
			int 16h
			jz .end
			mov ah, 0h ; retrieve key from buffer
			int 16h
			cmp al, 27 ; ESC
			jz exit_process
			cmp ah, 48h ; up
			jz .up
			cmp ah, 50h ; down
			jz .down
			cmp ah, 4bh; left
			jz .left
			cmp ah, 4dh; right
			jz .right
			jmp update_snake_direction
		.up:
			mov byte [snake_direction], 8
			jmp update_snake_direction
		.down:
			mov byte [snake_direction], 4
			jmp update_snake_direction
		.left:
			mov byte [snake_direction], 2
			jmp update_snake_direction
		.right:
			mov byte [snake_direction], 1
			jmp update_snake_direction
		.end:
			ret
		
	update_snake_head:
			mov al, [snake_head_y]
			mov byte [snake_head_previous_y], al
			mov al, [snake_head_x]
			mov byte [snake_head_previous_x], al
			mov ah, [snake_direction]
			cmp ah, 8 ; up
			jz .up
			cmp ah, 4 ; down
			jz .down
			cmp ah, 2; left
			jz .left
			cmp ah, 1; right
			jz .right
		.up:
			dec word [snake_head_y]
			jmp .end
		.down:
			inc word [snake_head_y]
			jmp .end
		.left:
			dec word [snake_head_x]
			jmp .end
		.right:
			inc word [snake_head_x]
		.end:
			; update previous snake body with direction information
			mov bl, [snake_direction]
			mov ch, 0
			mov cl, [snake_head_previous_x]
			mov dl, [snake_head_previous_y]
			call buffer_write
			ret

	check_snake_new_position:
			mov ch, 0
			mov cl, [snake_head_x]
			mov dh, 0
			mov dl, [snake_head_y]
			call buffer_read
			cmp bl, 8
			jle .set_game_over
			cmp bl, '*'
			je .food
			cmp bl, ' '
			je .empty_space
		.set_game_over:
			cmp al, 1
			mov byte [is_game_over], al 
		.write_new_head:
			mov bl, 1
			mov ch, 0
			mov cl, [snake_head_x]
			mov ch, 0
			mov dl, [snake_head_y]
			call buffer_write
			ret
		.food:
			inc dword [score]
			call .write_new_head
			call create_food
			jmp .end
		.empty_space:
			call update_snake_tail
			call .write_new_head
		.end:
			ret

	update_snake_tail:
			mov al, [snake_tail_y]
			mov byte [snake_tail_previous_y], al
			mov al, [snake_tail_x]
			mov byte [snake_tail_previous_x], al
			mov ch, 0
			mov cl, [snake_tail_x]
			mov dh, 0
			mov dl, [snake_tail_y]
			call buffer_read
			cmp bl, 8 ; up
			jz .up
			cmp bl, 4 ; down
			jz .down
			cmp bl, 2; left
			jz .left
			cmp bl, 1; right
			jz .right
			jmp exit_process
		.up:
			dec word [snake_tail_y]
			jmp .end
		.down:
			inc word [snake_tail_y]
			jmp .end
		.left:
			dec word [snake_tail_x]
			jmp .end
		.right:
			inc word [snake_tail_x]
		.end:
			mov bl, ' '
			mov ch, 0
			mov cl, [snake_tail_previous_x]
			mov ch, 0
			mov dl, [snake_tail_previous_y]
			call buffer_write
		ret

	create_initial_foods:
			mov cx, 10
		.again:
			push cx
			call create_food
			pop cx
			loop .again

	
	create_food:
		.try_again:
			
			mov ah, 0
			int 1ah ; cx = hi dx = low
			mov ax, dx
			and ax, 0fffh
			mul dx
			mov dx, ax
			mov ax, dx
			mov cx, 2000
			xor dx, dx
			div cx ; dx = rest of division
			mov bx, dx
			mov di, buffer
			mov al, [di + bx]
			cmp al, ' ' ; create food just in empty position
			jnz .try_again
			mov byte [di + bx], '*'
			ret

	reset:
			mov ax, 0
			mov word [score], ax
			mov byte [is_game_over], al
			mov al, 8
			mov byte [snake_direction], al
			mov al, 40
			mov byte [snake_head_x], al
			mov byte [snake_head_previous_x], al
			mov byte [snake_tail_previous_x], al
			mov byte [snake_tail_x], al
			mov al, 15
			mov byte [snake_head_y], al
			mov byte [snake_head_previous_y], al
			mov byte [snake_tail_y], al
			mov byte [snake_tail_previous_y], al
			ret

	start_playing:
			call reset		
			call buffer_clear
			call draw_border
			call create_initial_foods
		.main_loop:
			mov si, 2
			call sleep
		
			call update_snake_direction
			call update_snake_head
			call check_snake_new_position
			call print_score
			call buffer_render
		
			mov al, [is_game_over]
			cmp al, 0
			jz .main_loop
			ret

	draw_border:
			mov di, 0
		.next_x:
			mov byte [buffer + di], 255
			mov byte [buffer + 80 + di], 196
			mov byte [buffer + 1920 + di], 196
			inc di
			cmp di, 80
			jnz .next_x
			mov di, 0
		.next_y:
			mov byte [buffer + 80 + di], 179
			mov byte [buffer + 159 + di], 179
			add di,80
			cmp di, 2000
			jnz .next_y
		.corners:
			mov byte [buffer + 80], 218
			mov byte [buffer + 159], 191
			mov byte [buffer + 1920], 192
			mov byte [buffer + 1999], 217
			ret
		
	show_game_over:
			mov si, .text_1
			mov di, 880 + 32
			call buffer_print_string
			mov si, .text_2
			mov di, 960 + 32
			call buffer_print_string
			mov si, .text_1
			mov di, 1040 + 32
			call buffer_print_string
			call buffer_render
			mov si, 48
			call sleep
			call clear_keyboard_buffer
			mov ah, 0
			int 16h
			ret
		.text_1:
			db "               ", 0
		.text_2:
			db "   GAME OVER   ", 0

score: dw 1
is_game_over: db 1
snake_direction: db 1
snake_head_x: db 1
snake_head_y: db 1
snake_head_previous_x: db 1
snake_head_previous_y: db 1
snake_tail_x: db 1
snake_tail_y: db 1
snake_tail_previous_x: db 1
snake_tail_previous_y: db 1
title: db 'SNAKE GAME', 0
key: db 'PRESS ENTER KEY TO START', 0
buffer: db 2000 ;(the term "buffer" likely refers to a region of memory that is used to store and manipulate data)