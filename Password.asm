;Author: David Jones 6/20/17
.model small
.586
.stack 100h
.data 
passwordPrompt 		db 	'Please enter a password (Press Ctrl + S to hide/show password)',0
missingSpecialChar	db	'The password is lacking a special character',0
missingNumber		db 	'The password is lacking a number',0
missingUpper		db 	'The password is lacking an uppercase character',0
missingLower		db	'The password is lacking a lowercase character',0
passwordTooShort	db  'The password must be at least six characters',0
passwordTooLong		db  'The password cannot be longer than 14 characters',0
passwordSuccess		db 	'Your password is successful!!',0
tryAgainPrompt		db	'Do you wish to try again (y/n)? ',0
invalidSelection	db 	'Try again. Only Y/y or N/n works',0
passwordString		db 	15 DUP (0)
requirementsMet		db 	'Password meets requirements',0
showPassword		db 	0
isValid				db 	0

.code
MAX_VIDEO_CHARS EQU 2000
MAX_VIDEO_SIZE 	EQU 4000
VIDEO_SEG		EQU 0b800h
CHARS_PER_LINE	EQU 80
BYTES_PER_LINE 	EQU 160
RED				EQU 0Ch
BLACK			EQU 07h
GREEN			EQU 0Ah
gotoPos MACRO lineNumber,columnNumber
		;Sets the cursor position to the specified line number and column number
		mov dh, lineNumber
		mov dl, columnNumber
		mov ah, 2
		xor bh,bh
		int 010h
ENDM
displayMsg	MACRO dsString
		;Displays the specified string center in the line number in dx.
		lea di, dsString
		mov cx, dx
		call displayStrCenter
		inc dx
ENDM
main	proc
		mov ax, @data
		mov ds, ax
		mov es, ax
	start:
		;Change the video mode to 80x25 and set the password to invalid
		mov [showPassword], 0
		mov ax, 3
		int 010h
		;display password prompt
		lea di, passwordPrompt
		mov ah, BLACK
		xor cx, cx 
		call displayStrCenter
		;Initialize the screen
		mov ax, 08h
		lea di, passwordString
		call displayErrors
		gotoPos 1, 40
	getKeyLoop:
		;Get a key stroke and update the error messages and display
		xor ah,ah
		int 016h
		call displayErrors
		;Check to see if more keystrokes should be recorded, if so loop
		cmp al, 0Dh					
		jne getKeyLoop
		;Is the password valid? If so then display a success message
		test [isValid], 1
		jz askTryAgain
		mov ah, GREEN
		displayMsg passwordSuccess
	askTryAgain:
		;Display do you want to try again
		mov ah, BLACK
		displayMsg tryAgainPrompt
		;Update the cursor position
		push dx
		shl dx, 8
		mov dl, cl
		mov ah, 2
		xor bh,bh
		dec dh
		int 010h
		pop dx
	waitForYN:
		;Get the users response to whether they want to quit or not
		xor ah,ah
		int 016h
		;Convert to uppercase and make sure they selected Y or N. If not yell in red
		and al, 0DFh
		cmp al, 'Y'
		je start
		cmp al, 'N'
		je exitProgram
		mov cx, dx
		mov ah, RED
		lea di, invalidSelection
		call displayStrCenter
		jmp waitForYN
exitProgram:
		;Reset the video mode to 80x25
		mov ax, 3
		int 010h
		mov ax, 04c00h
		int 021h
main 	endp

clearLines proc	;al = startline, cl = total lines to clear
		push ax
		mov al, BYTES_PER_LINE / 4
		mul cl
		mov cx, ax
		pop ax
		push di
		push bx
		mov bl, BYTES_PER_LINE
		mul bl
		mov bx, VIDEO_SEG
		mov es, bx
		mov di, ax
		xor eax, eax
		rep stosd
		mov bx, @data
		mov es, bx
		pop bx
		pop di
		ret
clearLines endp

displayStrCenter proc
		;es:di is the string pointer, ah is the attributes, al is discarded
		;cx is the line number, when returns it is the column after the end of the str		
		push bx
		push si
		push ax	
		push cx
		;calculate the string length and put in ax
		mov si, di
		or cx, 0FFFFh
		xor al,al
		repne scasb
		not cx
		dec cx
		;load es with the video segment
		mov ax, VIDEO_SEG
		mov es, ax
		;calculate the column for the string to be centered
		mov di, CHARS_PER_LINE
		sub di, cx
		;Set bx to the end of the string
		mov bx, di
		and di, 0FEh
		shr bx, 1
		add bx, cx
		;calculate the line number in memory and add to di
		pop ax
		mov cl, BYTES_PER_LINE
		mul cl
		add di, ax
		pop ax					
	displayLoop:
		lodsb
		test al, 0FFh
		jz exitDisplayString
		stosw
		jmp displayLoop
	exitDisplayString:
		mov cx, @data
		mov es, cx
		pop si
		mov cx, bx
		pop bx
		ret
displayStrCenter endp

displayErrors proc		;al contains character, ds:di points to the end of the string (next character to be stored)
						;dx constains the line number after the write occurred
		;calculate string length and save beginning of string in si
		xor bx, bx
		mov si, offset passwordString		
		mov cx, di
		sub cx, offset passwordString
		;Check for backspace and enter key and make sure the string is not too long in that order 
		cmp al, 8
		je backspace
		;check for enter
		cmp al, 0dh							
		je beforeTooShortCmp
		;Determine if control + s was pressed. If so toggle whether the password was shown
		cmp al, 013h
		je ctrlSpressed
		;check length
		cmp cx, 14							
		jae tooLong
		;Make sure the character is valid
		cmp al, 'z'
		ja exitFunction
		cmp al, 'a'
		jae validChar
		cmp al, 'Z'
		ja exitFunction
		cmp al,'<'
		jae validChar
		cmp al, '9'
		ja exitFunction
		cmp al, '0'
		jae validChar
		cmp al, '+'
		ja exitFunction
		cmp al,'!'
		jb exitFunction
	validChar:					;store the character
		inc cx
		mov [di], al
		inc di
	beforeTooShortCmp: 
		cmp cx, 6
		jb tooShort
	afterTooShortCmp:
		push ax
	checkLoop:
		mov [isValid], 0
		lodsb
		cmp al, 'a'
		jae lowerPresent
		cmp al, 'A'
		jae upperPresent
		cmp al,'<'
		jae specialPresent
		cmp al, '0'
		jae digitPresent
	specialPresent:	
		or bx, 8
	loopEndCheck:
		loop	checkLoop
	endLoop:
		mov ax, 1
		mov cx, 6
		call clearLines
		mov si, di		
		mov dx, 2						;Use dx to record the line where the error message is written
		mov ah, RED						
		test bx, 1
		jz displayLowerMissing
	checkUpper:
		test bx, 2
		jz displayUpperMissing
	checkNumber:
		test bx, 4
		jz displayNumberMissing
	checkSpecial:
		test bx, 8
		jz displaySpecialMissing
	checkTooShort:
		test bx, 16
		jnz displayTooShort
	checkTooLong:
		test bx, 32
		jnz displayTooLong
	beforeCheckReqMet:
		cmp dx, 2
	displayStars:
		je displayReqMet
		mov cx, si								
		sub cx, offset passwordString
		mov ah, BLACK
		test [showPassword], 0FFh
		jnz displayPassword
		;Display stars centered on line 1 (0-indexed)
		mov di, VIDEO_SEG
		mov es, di
		mov al, '*'
		mov di, CHARS_PER_LINE 
		sub di, cx
		and di, 0FEh
		add di, 160
		rep stosw
		;Restore necessart variables and set the cursor position to the end of the string
		mov ax, @data
		mov es, ax
		mov di, si
		mov bx, si
		sub bx, offset passwordString
		mov ax, CHARS_PER_LINE
		sub ax, bx
		shr ax, 1
		add ax, bx
		push dx
		gotoPos 1,al
		pop dx
		pop ax
	exitFunction:
		ret
	displayLowerMissing:
		displayMsg missingLower
		jmp checkUpper
	displayUpperMissing:
		displayMsg missingUpper
		jmp checkNumber
	displaySpecialMissing:
		displayMsg missingSpecialChar
		jmp checkTooShort
	displayNumberMissing:
		displayMsg missingNumber
		jmp checkSpecial
	displayTooLong:
		displayMsg passwordTooLong
		cmp dx, 3
		jmp displayStars
	displayTooShort:
		displayMsg passwordTooShort
		jmp displayStars
	tooShort:
		or bx, 16
		test cx, 0FFFFh
		jnz afterTooShortCmp
	firstTimeInitialization:
		or bx, 010h
		push ax
		jmp endLoop
	tooLong:
		or bx, 32
		jmp afterTooShortCmp
	lowerPresent:
		or bx, 1
		jmp loopEndCheck
	upperPresent:
		or bx, 2
		jmp loopEndCheck
	digitPresent:
		or bx, 4
		jmp loopEndCheck
	displayReqMet:
		mov [isValid], 1
		mov ah, GREEN
		displayMsg requirementsMet
		jmp displayStars
	backspace:
		cmp cx, 0
		je firstTimeInitialization
		dec di
		dec cx
		jmp beforeTooShortCmp
	ctrlSpressed:
		xor [showPassword], 1
		jmp beforeTooShortCmp
	displayPassword:
		;Set the null terminating character to the password and display the password 
		mov byte ptr [si], 0
		lea di, passwordString
		mov cx, 1
		mov ah, BLACK
		call displayStrCenter
		push dx
		;Update the cursor position
		gotoPos 1, cl
		pop dx
		mov di, si
		pop ax
		ret
displayErrors endp
end main
