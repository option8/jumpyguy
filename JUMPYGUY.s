	DSK JUMPYGUY

**************************************************
* To Do:
*
**************************************************
* Variables
**************************************************

ROW				EQU		$FA			; row/col in text screen
COLUMN			EQU		$FB
CHAR			EQU		$FC			; char/pixel to plot
PROGRESS 		EQU		$FD			; write to main or alt
PLOTROW			EQU		$FE			; row/col in text page
PLOTCOLUMN		EQU		$FF
RNDSEED			EQU		$EA			; +eb +ec
SPRITEOFFSET	EQU		$CE			; where am I in the midst of drawing
SPRITEINDEX		EQU		$1D			; which table do I look for sprite data
SPRITELO		EQU		$1E			; address of sprite pixel table
SPRITEHI		EQU		$1F
PLOTINDEX		EQU		$1C			; which sprite am i drawing
SPRITEWIDTH		EQU		$ED	
SPRITEHEIGHT	EQU		$EF	
BGCHAR			EQU		$40			; stores the background pixel for overwriting
JUMPING			EQU		$41			; are we jumping, and if so, what frame are we on
COLLISIONROW	EQU		$E1			; address of colliding pixels
COLLISIONCOLUMN	EQU		$E2			
COLLISIONFLAG	EQU		$E3			; has there been a collision this frame?

PLAYERSCORE		EQU		$09
HISCORE			EQU		$0A	


**************************************************
* Apple Standard Memory Locations
**************************************************
CLRLORES     EQU   $F832
LORES        EQU   $C050
TXTSET       EQU   $C051
MIXCLR       EQU   $C052
MIXSET       EQU   $C053
TXTPAGE1     EQU   $C054
TXTPAGE2     EQU   $C055
KEY          EQU   $C000
C80STOREOFF  EQU   $C000
C80STOREON   EQU   $C001
STROBE       EQU   $C010
SPEAKER      EQU   $C030
VBL          EQU   $C02E
RDVBLBAR     EQU   $C019       ;not VBL (VBL signal low
WAIT		 EQU   $FCA8 
RAMWRTAUX    EQU   $C005
RAMWRTMAIN   EQU   $C004
SETAN3       EQU   $C05E       ;Set annunciator-3 output to 0
SET80VID     EQU   $C00D       ;enable 80-column display mode (WR-only)
HOME 		 EQU   $FC58			; clear the text screen
CH           EQU   $24			; cursor Horiz
CV           EQU   $25			; cursor Vert
VTAB         EQU   $FC22       ; Sets the cursor vertical position (from CV)
COUT         EQU   $FDED       ; Calls the output routine whose address is stored in CSW,
                               ;  normally COUTI
STROUT		 EQU   $DB3A 		;Y=String ptr high, A=String ptr low

ALTTEXT		 EQU	$C055
ALTTEXTOFF   EQU	$C054

ROMINIT      EQU    $FB2F
ROMSETKBD    EQU    $FE89
ROMSETVID    EQU    $FE93

ALTCHAR		EQU		$C00F		; enables alternative character set - mousetext

BLINK		EQU		$F3
SPEED		EQU		$F1

**************************************************
* START - sets up various fiddly zero page bits
**************************************************

				ORG $2000						; PROGRAM DATA STARTS AT $2000

				JSR ROMSETVID           	 	; Init char output hook at $36/$37
				JSR ROMSETKBD           	 	; Init key input hook at $38/$39
				JSR ROMINIT               	 	; GR/HGR off, Text page 1

				LDA #$01
				STA PROGRESS					; which page do we write to
				
				LDA #$00
				STA BLINK						; blinking text? no thanks.
				STA JUMPING
				STA BGCHAR
				STA LORES						; low res graphics mode
				STA COLLISIONFLAG				; no collision yet
				STA NUMBEROFSPRITES				; just the runner for attract screen
				STA HISCORE
				STA PLAYERSCORE
				JSR CLRLORES					; clear screen		
				

DRAWBOARD		JSR HOME							

				LDA #$70
				STA SPEED						; re-using the applesoft variable. fun.


				STA ALTTEXTOFF					; display main text page
				JSR RNDINIT						; *should* cycle the random seed.
				LDA #$00
				STA NUMBEROFSPRITES				; just the runner for attract screen
				STA SPRITECOLUMN
				STA LASTCOLUMN					; reset runner position
				INC PROGRESS


* SPRITECOLUMN		HEX	01,28,40,58					
* need to reset the runner and sprites for next try
				LDX #$0
				LDA #$01
				STA SPRITECOLUMN,X
				INX
				LDA #$28
				STA SPRITECOLUMN,X
				INX
				LDA #$40
				STA SPRITECOLUMN,X
				INX
				LDA #$58
				STA SPRITECOLUMN,X



**************************************************
*	blanks the screen
**************************************************
; FOR EACH ROW/COLUMN

				LDA #$18				; X = 24
				STA PLOTROW
ROWLOOP2 								; (ROW 20 to 0)
				DEC PLOTROW				;	start columnloop (COLUMN 0 to 40)
				LDA #$28
				STA PLOTCOLUMN
COLUMNLOOP2		DEC PLOTCOLUMN	

				LDA PLOTROW				
PLOTZERO		LDA #$00					; set all pixels to 00
PLOTLINE		STA CHAR
				JSR PLOTQUICK			; plot 00
				INC PROGRESS
				JSR PLOTQUICK			; plot 00 to alt
				INC PROGRESS

				LDA PLOTCOLUMN			; last COLUMN?
				BNE COLUMNLOOP2			; loop

;	/columnloop2
			
				LDA PLOTROW				; last ROW?
				BNE ROWLOOP2			; loop 
	
; 	/rowloop2		
				JSR DRAWGROUND
				INC PROGRESS
				JSR DRAWGROUND
				JSR DRAWCLOUDS
				JSR DRAWSCOREBD

* if the high score is above, say, 90. You get a burger.

				LDA PLAYERSCORE
				CMP #$5A
				BCS BURGERTIME
				
				JSR DRAWLOGO
				INC PROGRESS
				JSR DRAWLOGO

				JMP FIXJUMP
				
BURGERTIME		JSR DRAWBURGER
				INC PROGRESS
				JSR DRAWBURGER


FIXJUMP			LDA #$11				; fix jumper masking on first frame of attract mode
				STA LASTROW
				STA SPRITEROW

				LDA PLAYERSCORE
				CMP HISCORE
				BCC NOHISCORE
* if the current PLAYERSCORE is higher than hiscore, set HISCORE, then reset PLAYERSCORE				
				STA HISCORE
NOHISCORE		JSR UPDATEHISCORE
				LDA #$00
				STA PLAYERSCORE




**************************************************
*	MAIN LOOP
*	waits for keyboard input, moves cursor, etc
**************************************************

ATTRACT		
				JSR NEXTSCREEN			; animate one frame per loop

				LDA SPEED					
				JSR WAIT 				

				LDA KEY					; check for keydown
				CMP #$A0				; space bar		pause?
				BEQ STARTGAME

				CMP #$9B				; ESC
				BEQ END					; exit on ESC?
			
				JSR DRAWCLOUDS


				JMP ATTRACT				; loop until a key

STARTGAME		STA STROBE

				JSR ERASELOGO
				INC PROGRESS
				JSR ERASELOGO

				LDA #$03
				STA NUMBEROFSPRITES		; add obstacle sprites

				JMP MAIN				; back to waiting for a key

					







**************************************************
*	MAIN LOOP
*	waits for keyboard input, moves cursor, etc
**************************************************

MAIN		
MAINLOOP		JSR NEXTSCREEN			; animate one frame per loop

				LDA COLLISIONFLAG		; collided with something on last go-round. time to reset.
				BNE GOTRESET

				LDA KEY					; check for keydown
				CMP #$A0				; space bar 
				BEQ GOTJUMP				;			
				CMP #$D2				; R to reset
				BEQ GOTRESET

				CMP #$9B				; ESC
				BEQ END					; exit on ESC?

				CMP #$CA				; J also jumps
				BEQ GOTJUMP				;			

GOLOOP			JMP MAINLOOP			; loop until a key



GOTJUMP			STA STROBE
* if jumping == 0, then jumping == 1
				LDA JUMPING
				BNE ALREADYJUMPING		; not zero, skip
				INC JUMPING				; should be 1 now.			
								
ALREADYJUMPING	
				JMP MAINLOOP			; back to waiting for a key
				
GOTRESET		STA STROBE
				JMP DRAWBOARD

END				STA STROBE
				STA ALTTEXTOFF
				STA TXTSET
				JSR HOME
				RTS						; END	
					

**************************************************
*	subroutines
*
**************************************************

**************************************************
*	main animation loop
**************************************************

NEXTSCREEN

* MASK ALL THE SPRITES *THEN*
* RENDER ALL THE SPRITES


LOADSPRITES
				LDX NUMBEROFSPRITES		; number of sprites, starts with last one
				STX PLOTINDEX			; start with last sprite, PLOTINDEX decrements per loop
				INC PLOTINDEX

* MASK the sprites *i just rendered* on the hidden frame
MASKALLTHETHINGS

				DEC PLOTINDEX
				LDX PLOTINDEX
				LDA SPRITEINDEXTABLE,X		; use spriteindex to mask sprites. all else is X for position, velocity
				STA SPRITEINDEX
				LDX SPRITEINDEX
				LDA SPRITEWIDTHTABLE,X				
				STA SPRITEWIDTH
				LDA SPRITEHEIGHTTABLE,X				
				STA SPRITEHEIGHT

				LDX PLOTINDEX				; return X to plotindex for plotting position
				LDA SPRITEROW,X
				STA PLOTROW
				STA LASTROW,X
				LDA SPRITECOLUMN,X
				STA PLOTCOLUMN
				STA LASTCOLUMN,X
				INC PROGRESS
				JSR CLEARSPRITE				; be sure to clear previous frames before animating, since it's not triggered by movement
				INC PROGRESS

				LDA PLOTINDEX
				BNE MASKALLTHETHINGS		; do runner/sprite zero last.
;/MASKALLTHETHINGS

				INC PROGRESS
				JSR DRAWGROUND				; covers the mask with green grass layer
				INC PROGRESS



* plot the runner, sprite 0
* define the proper sprite	

RUNNINGMAN
* animate sprite 0 - should rotate between runners on each frame.
				LDA JUMPING
				BNE JUMPINGMAN
* if JUMPING not zero, skip to JUMPINGMAN

				LDX #$0						; load SPRITEINDEXTABLE,0
				STX PLOTINDEX				; reset plotindex for sprite 0
				LDA SPRITEINDEXTABLE,X
				CLC
				ADC #$01					; INC it 05->06->07->08
				CMP #$09
				BCC	SWAPTY					; if more than 8, set to 5 then swap
				LDA #$05
SWAPTY			JSR SWAPSPRITE				; SWAP SPRITEINDEX


				LDX SPRITEINDEXTABLE		; use spriteindex to swap sprites. all else is plotindex for position, velocity
							
				LDA SPRITELOTABLE,X
				STA SPRITELO
				LDA SPRITEHITABLE,X
				STA SPRITEHI      
				 		  	
				LDA SPRITEWIDTHTABLE,X		
				STA SPRITEWIDTH		
				LDA SPRITEHEIGHTTABLE,X	
				STA SPRITEHEIGHT		

				LDX #$0

				LDA SPRITEROW,X
				STA PLOTROW
				STA LASTROW
				LDA SPRITECOLUMN,X
				STA PLOTCOLUMN
				STA LASTCOLUMN
				JSR PLOTSPRITE				; plot sprite zero, runner.


				JMP CONTINUERUNNING



JUMPINGMAN
				LDX #$0						; load SPRITEINDEXTABLE,0
				STX PLOTINDEX				; reset plotindex for sprite 0

* if spriteindex,0 (runner) != 9, swapsprite to 9.
				LDA SPRITEINDEXTABLE
				CMP #$09
				BEQ DONEYET
				LDA #$09
				JSR SWAPSPRITE


				
* if jumping > 11, done jumping, swapsprite to 5. set jumping to 0
DONEYET			INC JUMPING
				LDA JUMPING
				CMP #$12					; 18 frames of jumping
				BCC CONTINUEJUMPING

DONEJUMPING		LDA #$0
				STA JUMPING
				LDA #$05
				JSR SWAPSPRITE	

				LDX SPRITEINDEXTABLE		; use spriteindex to mask sprites. all else is X for position, velocity
				LDA SPRITEWIDTHTABLE,X				
				STA SPRITEWIDTH
				LDA SPRITEHEIGHTTABLE,X				
				STA SPRITEHEIGHT

				LDX #$0						; return X to plotindex of 0 for plotting position
				LDA SPRITEROW,X
				STA PLOTROW
				STA LASTROW
				LDA SPRITECOLUMN,X
				STA PLOTCOLUMN
				STA LASTCOLUMN

				JSR CLEARSPRITE				; be sure to clear previous frames before animating, since it's not triggered by movement



* otherwise
STILLJUMPING
* increment jumping frame number

CONTINUEJUMPING
				
				LDX JUMPING					; if not jumping, or *done* jumping, uses JUMPINGCURVE,0
				LDA JUMPINGCURVE,X			; what row to render on which frame of the JUMP
				STA SPRITEROW				; spriterow, 0
				STA LASTROW					; LASTROW,0

				LDX SPRITEINDEXTABLE		; use spriteindex to swap sprites. all else is plotindex for position, velocity
							
				LDA SPRITELOTABLE,X
				STA SPRITELO
				LDA SPRITEHITABLE,X
				STA SPRITEHI      
				 		  	
				LDA SPRITEWIDTHTABLE,X		
				STA SPRITEWIDTH		
				LDA SPRITEHEIGHTTABLE,X	
				STA SPRITEHEIGHT		

				LDX #$0

				LDA SPRITEROW,X
				STA PLOTROW
				STA LASTROW
				LDA SPRITECOLUMN,X
				STA PLOTCOLUMN
				STA LASTCOLUMN
				JSR PLOTSPRITE				; plot sprite zero, runner.

				
CONTINUERUNNING

COLLIDINGORNOT
* set colliding sprites to FF
				LDA #$FF
				LDY #$0
				STY COLLISIONFLAG			; clear collision detector flag
				STA COLLIDINGSPRITES,Y
				LDY #$1
				STA COLLIDINGSPRITES,Y



* plot obstacle sprites

				LDX NUMBEROFSPRITES		; number of sprites, starts with last one
				STX PLOTINDEX			; start with last sprite, PLOTINDEX decrements per loop
				LDA PLOTINDEX
				BNE NEXTSPRITE
				JMP UPDATESCREEN		; sprite zero already done. chill.

				
NEXTSPRITE		LDA SPRITEINDEXTABLE,X	; get the index of that sprite - may be out of order
				STA SPRITEINDEX





* define the obstacle sprite	
				LDX SPRITEINDEX				; use spriteindex to swap sprites. all else is plotindex for position, velocity
							
				LDA SPRITELOTABLE,X
				STA SPRITELO
				LDA SPRITEHITABLE,X
				STA SPRITEHI      
				 		  	
				LDA SPRITEWIDTHTABLE,X		
				STA SPRITEWIDTH		
				LDA SPRITEHEIGHTTABLE,X	
				STA SPRITEHEIGHT		
				
				LDX PLOTINDEX				; return X to plotindex for plotting position


* update obstacle position

* if moving left, decrement SPRITECOLUMN
* if moving right, increment SPRITECOLUMN
HORIZONTAL		LDA HORIZSIGN,X
				BEQ MOVINGLEFT
				LDA SPRITECOLUMN,X
				CLC 
				ADC HVELOCITY,X
				STA SPRITECOLUMN,X
				STA PLOTCOLUMN
				JMP NEXTOBSTACLE
MOVINGLEFT		LDA SPRITECOLUMN,X
				SEC
				SBC HVELOCITY,X
				STA SPRITECOLUMN,X
				STA PLOTCOLUMN
				CLC
				ADC SPRITEWIDTH			; add the sprite width to see if it's all the way off screen
				BMI OFFLEFT
				JMP NEXTOBSTACLE 			; still positive number, still on screen

OFFLEFT			LDA #$40					; off the left side. wrap around to right side
				STA SPRITECOLUMN,X

* cleared an obstacle. Increment the player score. In DECIMAL
				LDA PLAYERSCORE
				SED
				CLC
				ADC #$01
				STA PLAYERSCORE
				CLD
				
* display updated player score				

				STX $07 						; hang onto X
				JSR UPDATESCORE
				LDX $07							; back to X, thanks.

* twinkle the stars.
				JSR DRAWCLOUDS



* as one obstacle goes off to the left, kick another off from the right. speed up runner

				LDA SPEED
				CMP #$40						; faster than $40, start ramping forward "level 2"
				BCC GOTTAGOFAST					; speed max at 1, not 0. odd.
				
				DEC SPEED						; running slightly faster with each iteration
				JMP NEXTOBSTACLE
GOTTAGOFAST										; already running at full speed. 
* start sending the obstacles two at a time?
				DEC SPEED						; running slightly faster with each iteration


* move runner closer to obstacles

* need to mask the runner left side
				STX $07 						; hang onto X

				LDX SPRITEINDEXTABLE			; use spriteindex to mask sprites. all else is X for position, velocity
				LDA SPRITEWIDTHTABLE,X				
				STA SPRITEWIDTH
				LDA SPRITEHEIGHTTABLE,X				
				STA SPRITEHEIGHT


				LDX #$0							; zero for the runner sprite
				JSR CLEARSPRITE					; flicker?
				INC PROGRESS
				JSR CLEARSPRITE					; flicker?
				INC PROGRESS					; do i need both of these?

REDRAWRUNNER	LDX SPRITEINDEXTABLE			; use spriteindex to swap sprites. all else is plotindex for position, velocity
							
				LDA SPRITELOTABLE,X
				STA SPRITELO
				LDA SPRITEHITABLE,X
				STA SPRITEHI      
				 		  	
				LDA SPRITEWIDTHTABLE,X		
				STA SPRITEWIDTH		
				LDA SPRITEHEIGHTTABLE,X	
				STA SPRITEHEIGHT		

				LDX #$0

* don't go completely off the screen
				LDA SPRITECOLUMN
				CMP #$1C
				BCS REPLOTRUNNER

MOVERIGHT		INC SPRITECOLUMN				; spritecolumn, 0 = runner horiz position.
				INC LASTCOLUMN

REPLOTRUNNER	LDA SPRITEROW,X
				STA PLOTROW
				STA LASTROW
				LDA SPRITECOLUMN,X
				STA PLOTCOLUMN
				STA LASTCOLUMN
				JSR PLOTSPRITE					; plot sprite zero, runner.


				LDX $07							; back to X, thanks.


				
NEXTOBSTACLE		
				LDA SPRITEROW,X
				STA PLOTROW
				LDA SPRITECOLUMN,X
				STA PLOTCOLUMN

				LDA SPRITEINDEXTABLE,X	; get the index of that sprite - may be out of order
				STA SPRITEINDEX

* redefine the ball sprite	
				LDX SPRITEINDEX				; use spriteindex to swap sprites. all else is plotindex for position, velocity
							
				LDA SPRITELOTABLE,X
				STA SPRITELO
				LDA SPRITEHITABLE,X
				STA SPRITEHI      
				 		  	
				LDA SPRITEWIDTHTABLE,X		
				STA SPRITEWIDTH		
				LDA SPRITEHEIGHTTABLE,X	
				STA SPRITEHEIGHT		

* 	plot new sprite on next frame
PLOTOBSTACLE	JSR PLOTSPRITE


CHECKCOLLISION	LDA COLLISIONFLAG
				BEQ NOCOLLISION			; still zero, no collision yet


* collision detected.
* show crash sprite, centered on collision location.
* save the current score
* compare to the high score
* if higher, adjust the high score
* kill the player and return to ATTRACT
				

				LDA COLLISIONROW
				STA PLOTROW
				DEC PLOTROW
				DEC PLOTROW
				LDA COLLISIONCOLUMN
				STA PLOTCOLUMN
				DEC PLOTCOLUMN
				DEC PLOTCOLUMN
				DEC PLOTCOLUMN
* redefine the obstacle sprite	
				LDX #$0				; spriteindex 0 = splosion.
							
				LDA SPRITELOTABLE,X
				STA SPRITELO
				LDA SPRITEHITABLE,X
				STA SPRITEHI      
				 		  	
				LDA SPRITEWIDTHTABLE,X		
				STA SPRITEWIDTH		
				LDA SPRITEHEIGHTTABLE,X	
				STA SPRITEHEIGHT		

* 	plot new sprite on next frame
				INC PROGRESS
				JSR PLOTSPRITE
				INC PROGRESS
				LDA COLLISIONROW
				STA PLOTROW
				DEC PLOTROW
				DEC PLOTROW
				LDA COLLISIONCOLUMN
				STA PLOTCOLUMN
				DEC PLOTCOLUMN
				DEC PLOTCOLUMN
				DEC PLOTCOLUMN
				JSR PLOTSPRITE

				JSR BONK			; animation *and* sound? Dinner *and* a show?
	
				LDA #$ff
				JSR WAIT
	
				JMP ENDSCREEN
				
				
NOCOLLISION

* loop for next sprite
				DEC PLOTINDEX
				BEQ UPDATESCREEN		; plotindex of 0, we already did the runner
				BNE LOOPTY				; not yet 0, go back and plot another sprite
								
				
LOOPTY			LDX PLOTINDEX
				JMP NEXTSPRITE


UPDATESCREEN
				INC PROGRESS
				ROR PROGRESS			; lowest bit into carry
				BCC ALTSCREEN			; carry set on odd, not on even
				STA ALTTEXTOFF
				JMP NORMSCREEN

ALTSCREEN		STA ALTTEXT


* wait after screen swap, to let it happen?
NORMSCREEN		ROL PROGRESS

				LDA SPEED
				JSR WAIT 				

ENDSCREEN		RTS

;/NEXTSCREEN		
				
	


**************************************************
*	Draw a sprite at PLOTROW, PLOTCOLUMN - clobbers A, Y
**************************************************

PLOTSPRITE		
				LDA #$0
				STA SPRITEOFFSET		; set offset to 0

				LDA #$0
				STA ROW					; for each ROW in X

SPRITEROWS		LDA #$0
				STA COLUMN				; for each COLUMN in Y
				LDA PLOTCOLUMN
				CLC
				ADC COLUMN
				STA PLOTCOLUMN
SPRITECOLUMNS	LDY SPRITEOFFSET
				LDA (SPRITELO),Y		; LDA Sprite Origin,OFFSET
				STA CHAR				; store character
				INC PROGRESS			
				JSR PLOTCHAR			; PLOT on offscreen frame
				INC PROGRESS
				INC SPRITEOFFSET
				INC PLOTCOLUMN
				INC COLUMN
				LDA SPRITEWIDTH
				CMP COLUMN 
				BCS SPRITECOLUMNS		; do next column
				
				INC PLOTROW
				INC ROW
				DEC PLOTCOLUMN
				LDA PLOTCOLUMN			; PLOTCOLUMN back to sprite's origin
				SEC
				SBC SPRITEWIDTH
				STA PLOTCOLUMN
				
				LDA SPRITEHEIGHT
				CMP ROW
				BCS SPRITEROWS			; do next row	
							
SPRITEDONE		RTS
				
	 


**************************************************
*	Erase sprite-sized hole at lastrow, lastcolumn - clobbers A
**************************************************

CLEARSPRITE		
				LDA #$0
				STA SPRITEOFFSET		; set offset to 0
				STA ROW					; for each ROW in X

				LDA LASTROW,X
				STA PLOTROW
				LDA LASTCOLUMN,X
				SEC
				SBC HVELOCITY,X			; obstacles moving left, dammit.
				STA PLOTCOLUMN
				

CLEARROWS		LDA #$0
				STA COLUMN				; for each COLUMN in Y
				LDA PLOTCOLUMN
				CLC
				ADC COLUMN
				STA PLOTCOLUMN
CLEARCOLUMNS	LDY SPRITEOFFSET
				LDA #$00				
				STA CHAR				; store character
				JSR PLOTQUICK			; PLOT on offscreen frame
				INC SPRITEOFFSET
				INC PLOTCOLUMN
				INC COLUMN
			;	LDA SPRITEWIDTH
				LDA #$08				; clear 9px wide mask
				CMP COLUMN 
				BCS CLEARCOLUMNS		; do next column
				
				INC PLOTROW
				INC ROW
				DEC PLOTCOLUMN
				LDA PLOTCOLUMN			; PLOTCOLUMN back to sprite's origin
				SEC
			;	SBC SPRITEWIDTH
				SBC #$08
				STA PLOTCOLUMN
				
				LDA SPRITEHEIGHT
				CMP ROW
				BCS CLEARROWS			; do next row	
							
CLEARDONE		RTS





**************************************************
*	process two digit score (decimal) into two
*	numeral sprites - clobbers A, X
**************************************************

UPDATESCORE

* get score
				LDA PLAYERSCORE
* get low nibble of score
* AND score with 0F
				AND #$0F
* load sprite for that digit
				CLC
				ADC #$0A
* spriteindex = digit + #$0A to X
				TAX

				LDA SPRITELOTABLE,X
				STA SPRITELO
				LDA SPRITEHITABLE,X
				STA SPRITEHI      

				LDA SPRITEWIDTHTABLE,X		
				STA SPRITEWIDTH		
				LDA SPRITEHEIGHTTABLE,X	
				STA SPRITEHEIGHT		

* plotrow = 0
				LDA #$0
				STA PLOTROW
* plotcolumn = #$0C and #$11
				LDA #$11
				STA PLOTCOLUMN				
				JSR PLOTSPRITE
				INC PROGRESS
* 	plot sprite again for alternate frame
				LDA #$0
				STA PLOTROW
				LDA #$11
				STA PLOTCOLUMN				
				JSR PLOTSPRITE				; plot those sprites where they already are
				INC PROGRESS

* get score
				LDA PLAYERSCORE
* get HI nibble of score
* AND score with F0
				AND #$F0
				LSR
				LSR
				LSR
				LSR
* load sprite for that digit
				CLC
				ADC #$0A
* spriteindex = digit + #$0A to X
				TAX

				LDA SPRITELOTABLE,X
				STA SPRITELO
				LDA SPRITEHITABLE,X
				STA SPRITEHI      

				LDA SPRITEWIDTHTABLE,X		
				STA SPRITEWIDTH		
				LDA SPRITEHEIGHTTABLE,X	
				STA SPRITEHEIGHT		

* plotrow = 0
				LDA #$0
				STA PLOTROW
* plotcolumn = #$0C and #$11
				LDA #$0C
				STA PLOTCOLUMN				
				JSR PLOTSPRITE
				INC PROGRESS
* 	plot sprite again for alternate frame
				LDA #$0
				STA PLOTROW
				LDA #$0C
				STA PLOTCOLUMN				
				JSR PLOTSPRITE				; plot those sprites where they already are
				INC PROGRESS


				
				RTS

**************************************************
*	process two digit high score (decimal) into two
*	numeral sprites - clobbers A, X
**************************************************


UPDATEHISCORE

* get score
				LDA HISCORE
* get low nibble of score
* AND score with 0F
				AND #$0F
* load sprite for that digit
				CLC
				ADC #$0A
* spriteindex = digit + #$0A to X
				TAX

				LDA SPRITELOTABLE,X
				STA SPRITELO
				LDA SPRITEHITABLE,X
				STA SPRITEHI      

				LDA SPRITEWIDTHTABLE,X		
				STA SPRITEWIDTH		
				LDA SPRITEHEIGHTTABLE,X	
				STA SPRITEHEIGHT		

* plotrow = 0
				LDA #$0
				STA PLOTROW
* plotcolumn = #$1D and #$23
				LDA #$23
				STA PLOTCOLUMN				
				JSR PLOTSPRITE
				INC PROGRESS
* 	plot sprite again for alternate frame
				LDA #$0
				STA PLOTROW
				LDA #$23
				STA PLOTCOLUMN				
				JSR PLOTSPRITE				; plot those sprites where they already are
				INC PROGRESS

* get score
				LDA HISCORE
* get HI nibble of score
* AND score with F0
				AND #$F0
				LSR
				LSR
				LSR
				LSR
* load sprite for that digit
				CLC
				ADC #$0A
* spriteindex = digit + #$0A to X
				TAX

				LDA SPRITELOTABLE,X
				STA SPRITELO
				LDA SPRITEHITABLE,X
				STA SPRITEHI      

				LDA SPRITEWIDTHTABLE,X		
				STA SPRITEWIDTH		
				LDA SPRITEHEIGHTTABLE,X	
				STA SPRITEHEIGHT		

* plotrow = 0
				LDA #$0
				STA PLOTROW
* plotcolumn = #$1D and #$23
				LDA #$1e
				STA PLOTCOLUMN				
				JSR PLOTSPRITE
				INC PROGRESS
* 	plot sprite again for alternate frame
				LDA #$0
				STA PLOTROW
				LDA #$1e
				STA PLOTCOLUMN				
				JSR PLOTSPRITE				; plot those sprites where they already are
				INC PROGRESS


				
				RTS






**************************************************
*	prints one CHAR at PLOTROW,PLOTCOLUMN - clobbers A,Y
*	used for plotting background elements that don't need collision detection
**************************************************
PLOTQUICK
				LDY PLOTROW
				TYA
				CMP #$18
				BCS OUTOFBOUNDS2			; stop plotting if dimensions are outside screen
				
				ROR PROGRESS
				BCC PLOTQUICKALT			; every other frame, write to alt text page

				LDA LoLineTableL,Y
				STA $0
				LDA LoLineTableH,Y
				STA $1       		  		; now word/pointer at $0+$1 points to line 
				JMP LOADQUICK

PLOTQUICKALT	LDA AltLineTableL,Y
				STA $0
				LDA AltLineTableH,Y
				STA $1       		  		; now word/pointer at $0+$1 points to line 

LOADQUICK		ROL PROGRESS				; return progress state for next ROR

				LDY PLOTCOLUMN
				TYA
				CMP #$28
				BCS OUTOFBOUNDS2			; stop plotting if dimensions are outside screen

				STY $06						; hang onto Y for a sec...

				LDA CHAR
				LDY $06
				STA ($0),Y  

OUTOFBOUNDS2	RTS
;/PLOTQUICK			   







**************************************************
*	prints one CHAR at PLOTROW,PLOTCOLUMN - clobbers A,Y
* 	checks for collisions. This is the tricky part.
**************************************************
PLOTCHAR

* "foreground" is obstacle sprite
* "background" is already rendered sprite 0, runner

* get char to overwrite
* if CHAR and BGCHAR are the same, skip?
				JSR GETCHAR
				STA BGCHAR
			;	CMP CHAR
			;	BEQ OUTOFBOUNDS

				LDA CHAR
				BEQ OUTOFBOUNDS			; don't plot 00 px

				LDY PLOTROW
				TYA
				CMP #$18
				BCS OUTOFBOUNDS			; stop plotting if dimensions are outside screen
				
				CLC
				ROR PROGRESS
				BCC PLOTCHARALT			; every other frame, write to alt text page
				ROL PROGRESS

				LDA LoLineTableL,Y
				STA $0
				LDA LoLineTableH,Y
				STA $1       		  	; now word/pointer at $0+$1 points to line 
				JMP LOADCHAR

PLOTCHARALT		ROL PROGRESS
				LDA AltLineTableL,Y
				STA $0
				LDA AltLineTableH,Y
				STA $1       		  	; now word/pointer at $0+$1 points to line 

LOADCHAR								; return progress state for next ROR

				LDY PLOTCOLUMN
				TYA
				CMP #$28
				BCS OUTOFBOUNDS			; stop plotting if dimensions are outside screen

				STY $06					; hang onto Y for a sec...



* check collisions only on rows with runner/obstacles
				LDY PLOTROW
				TYA
				CMP #$17
				BCS FULLPIXEL
				
				CMP #$0F
				BCC FULLPIXEL
				

CLOBBER			LDA CHAR				; this would be a byte with two pixels
				BEQ FULLPIXEL			; zero foreground pixel? ignore for collision
				CMP #$CC				; green "grass" pixel? ignore
				LDA BGCHAR
				BEQ FULLPIXEL			; zero background pixel? ignore
				CMP #$CC				; green "grass" pixel? ignore
				BEQ FULLPIXEL

NONZERO			
				LDA #$01
				STA COLLISIONFLAG		; set collision detected
									
				JMP PLOTCOLLISION			
										
FULLPIXEL		LDA CHAR
				LDY $06
				STA ($0),Y  


OUTOFBOUNDS		RTS
;/PLOTCHAR				   


* DEBUG where pixels overlap, make a purple spot to track. #$33

PLOTCOLLISION
				;LDA #$33					; collision spot purple for debugging
				;LDY PLOTCOLUMN
				;STA (COLLISIONLO),Y		; collision spot purple
				
				LDA CHAR
				LDY $06
				STA ($0),Y  

				LDA PLOTCOLUMN
				STA COLLISIONCOLUMN
				LDA PLOTROW
				STA COLLISIONROW
				
COLLISIONDONE	RTS 


**************************************************
*	changes index in SPRITEINDEXTABLE to new value from Accumulator - clobbers Y
**************************************************

SWAPSPRITE		
				LDY PLOTINDEX			; get current plotindex
				STA SPRITEINDEXTABLE,Y	; put accumulator's sprite index into table instead of current ball
				RTS
				
**************************************************
*	GETS one CHAR at PLOTROW,PLOTCOLUMN - value returns in Accumulator - clobbers Y
**************************************************
GETCHAR
				LDY PLOTROW
				CLC
				ROR PROGRESS
				BCC GETCHARALT			; every other frame, write to alt text page
				ROL PROGRESS			; return progress state for next ROR

				LDA LoLineTableL,Y
				STA $0
				LDA LoLineTableH,Y
				JMP STORECHAR

GETCHARALT		ROL PROGRESS			; return progress state for next ROR
				LDA AltLineTableL,Y
				STA $0
				LDA AltLineTableH,Y

STORECHAR		STA $1       		  	; now word/pointer at $0+$1 points to line 
				LDY PLOTCOLUMN
				LDA ($0),Y  			; byte at row,col is now in accumulator
				RTS
;/GETCHAR					   




**************************************************
*	draws the splash screen logo - clobbers A, Y
**************************************************

DRAWLOGO								; draws the moon and clouds		
				LDA #$26
				STA PLOTCOLUMN
				LDA #$B					; down a bit.
				STA PLOTROW
				LDA #$0
				STA SPRITEOFFSET		; set offset to 0

				LDA #$05
				STA ROW					; for each ROW
LOGOROWS		LDA #$24
				STA COLUMN				; for each COLUMN
				LDA PLOTCOLUMN
				SEC
				SBC COLUMN
				STA PLOTCOLUMN
LOGOCOLUMNS		LDY SPRITEOFFSET
				LDA LOGO1,Y			; LDA Sprite Origin,OFFSET
				STA CHAR				; store character
				JSR PLOTQUICK			; PLOT on frame
				INC SPRITEOFFSET
				INC PLOTCOLUMN
				DEC COLUMN				; count down columns from 40
				BNE LOGOCOLUMNS		; do next column
				
				INC PLOTROW
				DEC ROW					; count down rows from 4
				BNE LOGOROWS			; do next row				


				LDA #$0
				STA SPRITEOFFSET		; set offset to 0
				LDA #$05
				STA ROW					; for each ROW
LOGO2ROWS		LDA #$24
				STA COLUMN				; for each COLUMN
				LDA PLOTCOLUMN
				SEC
				SBC COLUMN
				STA PLOTCOLUMN
LOGO2COLUMNS	LDY SPRITEOFFSET
				LDA LOGO2,Y			; LDA Sprite Origin,OFFSET
				STA CHAR				; store character
				JSR PLOTQUICK			; PLOT on frame
				INC SPRITEOFFSET
				INC PLOTCOLUMN
				DEC COLUMN				; count down columns from 40
				BNE LOGO2COLUMNS		; do next column
				
				INC PLOTROW
				DEC ROW					; count down rows from 4
				BNE LOGO2ROWS			; do next row				

LOGODONE
				RTS







**************************************************
*	erases the logo, ready to start game - clobbers A
**************************************************
; FOR EACH ROW/COLUMN

ERASELOGO		LDA #$16				; X = 22
				STA PLOTROW
ERASELOOP 								; (ROW 22 to 12)
				DEC PLOTROW				;	start columnloop (COLUMN 0 to 40)
				LDA #$28
				STA PLOTCOLUMN
ERASELOOP2		DEC PLOTCOLUMN	

				LDA PLOTROW				
				LDA #$00					; set all pixels to 00
				STA CHAR
				JSR PLOTQUICK			; plot 00
				LDA PLOTCOLUMN			; last COLUMN?
				BNE ERASELOOP2			; loop

;	/ERASELOOP2
				LDA PLOTROW				; last ROW?
				CMP #$0B
				BCS ERASELOOP			; loop 
; 	/ERASELOOP		
				RTS



**************************************************
*	draws the header moon and clouds - clobbers A, Y
**************************************************

DRAWCLOUDS								; draws the moon and clouds		
				LDA #$28
				STA PLOTCOLUMN
				LDA #$5					; down a bit.
				STA PLOTROW
				LDA #$0
				STA SPRITEOFFSET		; set offset to 0

				LDA #$04
				STA ROW					; for each ROW
CLOUDROWS		LDA #$28
				STA COLUMN				; for each COLUMN
				LDA PLOTCOLUMN
				SEC
				SBC COLUMN
				STA PLOTCOLUMN
CLOUDCOLUMNS	LDY SPRITEOFFSET

				JSR RND
				CMP #$80
				BCC TWINKLESTARS
				LDA CLOUDS,Y			; LDA Sprite Origin,OFFSET
				JMP NORMALSTARS
TWINKLESTARS	LDA TWINKLE,Y			; LDA Sprite Origin,OFFSET
NORMALSTARS		STA CHAR				; store character
				JSR PLOTQUICK			; PLOT on frame
				INC PROGRESS			
				JSR PLOTQUICK			; PLOT on offscreen frame
				INC PROGRESS
				INC SPRITEOFFSET
				INC PLOTCOLUMN
				DEC COLUMN				; count down columns from 40
				BNE CLOUDCOLUMNS		; do next column
				
				INC PLOTROW
				DEC ROW					; count down rows from 4
				BNE CLOUDROWS			; do next row				
CLOUDSDONE
				RTS



**************************************************
*	draws the scoreboard and initial zero scores - clobbers A, Y
**************************************************

DRAWSCOREBD								; draws the scoreboard	
				LDA #$28
				STA PLOTCOLUMN
				LDA #$0					; down a bit.
				STA PLOTROW
				LDA #$0
				STA SPRITEOFFSET		; set offset to 0

				LDA #$04
				STA ROW					; for each ROW
SCOREBDROWS		LDA #$28
				STA COLUMN				; for each COLUMN
				LDA PLOTCOLUMN
				SEC
				SBC COLUMN
				STA PLOTCOLUMN
SCOREBDCOLUMNS	LDY SPRITEOFFSET
				LDA SCOREBOARD,Y		; LDA Sprite Origin,OFFSET
				STA CHAR				; store character
				JSR PLOTQUICK			; PLOT on frame
				INC PROGRESS			
				JSR PLOTQUICK			; PLOT on offscreen frame
				INC PROGRESS
				INC SPRITEOFFSET
				INC PLOTCOLUMN
				DEC COLUMN				; count down columns from 40
				BNE SCOREBDCOLUMNS		; do next column
				
				INC PLOTROW
				DEC ROW					; count down rows from 4
				BNE SCOREBDROWS			; do next row				
SCOREBDDONE
				RTS




**************************************************
*	redraws the brown and green ground/footer - clobbers A
**************************************************

DRAWGROUND
				LDA #$16
				STA PLOTROW			
				LDA #$28
				STA PLOTCOLUMN
				
COLUMNLOOP3		DEC PLOTCOLUMN	
				LDA #$CC					; set all pixels to CC green
				STA CHAR
				JSR PLOTQUICK			; plot CC
				LDA PLOTCOLUMN			; last COLUMN?
				BNE COLUMNLOOP3			; loop

;	/columnloop3
				INC PLOTROW

				LDA #$28
				STA PLOTCOLUMN
COLUMNLOOP4		DEC PLOTCOLUMN	
				LDA #$84				; set all pixels to 84 green/brown
				STA CHAR
				JSR PLOTQUICK			; plot 84
				LDA PLOTCOLUMN			; last COLUMN?
				BNE COLUMNLOOP4			; loop

;	/columnloop4

				RTS




**************************************************
*	draws the BURGER  - clobbers A, Y
* 	congratulations on finding the easter egg.
**************************************************

DRAWBURGER								; draws the BURGER		
				LDA #$20
				STA PLOTCOLUMN
				LDA #$B					; down a bit.
				STA PLOTROW
				LDA #$0
				STA SPRITEOFFSET		; set offset to 0

				LDA #$07
				STA ROW					; for each ROW
BURGERROWS		LDA #$17
				STA COLUMN				; for each COLUMN
				LDA PLOTCOLUMN
				SEC
				SBC COLUMN
				STA PLOTCOLUMN
BURGERCOLUMNS	LDY SPRITEOFFSET
				LDA BURGER,Y			; LDA Sprite Origin,OFFSET
				STA CHAR				; store character
				JSR PLOTQUICK			; PLOT on frame
				INC SPRITEOFFSET
				INC PLOTCOLUMN
				DEC COLUMN				; count down columns from 40
				BNE BURGERCOLUMNS		; do next column
				
				INC PLOTROW
				DEC ROW					; count down rows from 4
				BNE BURGERROWS			; do next row				


BURGERDONE
				RTS


**************************************************
*	CLICKS and BEEPS - clobbers X,Y,A
**************************************************
CLICK			LDX #$06
CLICKLOOP		LDA #$10				; SLIGHT DELAY
				JSR WAIT
				LDA SPEAKER				
				DEX
				BNE CLICKLOOP
				RTS
;/CLICK

BEEP			LDX #$30
BEEPLOOP		LDA #$08				; short DELAY
				JSR WAIT
				LDA SPEAKER				
				DEX
				BNE BEEPLOOP
				RTS
;/BEEP


BONK			LDX #$50
BONKLOOP		LDA #$20				; longer DELAY
				JSR WAIT
				LDA SPEAKER				
				DEX
				BNE BONKLOOP
				RTS
;/BONK



**************************************************
* DATASOFT RND 6502
* BY JAMES GARON
* 10/02/86
* Thanks to John Brooks for this. I modified it slightly.
*
* returns a randomish number in Accumulator.
**************************************************
RNDINIT
               LDA   $C030			; #$AB
               STA   RNDSEED
               LDA   $4E			; #$55
               STA   RNDSEED+1
               LDA   PROGRESS		; #$7E
               STA   RNDSEED+2
               RTS

* RESULT IN ACC
RND            LDA   RNDSEED
               ROL   RNDSEED
               EOR   RNDSEED
               ROR   RNDSEED
               INC   RNDSEED+1
               BNE   RND10
               LDA   RNDSEED+2
               INC   RNDSEED+2
RND10          ADC   RNDSEED+1
               BVC   RND20
               INC   RNDSEED+1
               BNE   RND20
               LDA   RNDSEED+2
               INC   RNDSEED+2
RND20          STA   RNDSEED
               RTS


**************************************************
* Data Tables
*
**************************************************
**************************************************
* sprites definitions
**************************************************

REDBALL				HEX 10,B1,F1,10
					HEX	11,BB,BB,11
					HEX	01,1B,1B,01

PURPLEBALL			HEX 30,b3,f3,30
					HEX	33,00,00,33
					HEX	03,3b,3b,03


STUMP				HEX 00,80,08,08,08,08,80,00,00
					HEX	00,88,88,08,88,88,88,00,00
					HEX	84,88,08,80,88,08,88,84,cc
					HEX	84,84,88,88,84,84,88,84,84

ROCK				HEX 00,50,aa,5a,af,a0,00,00,00
					HEX	00,5a,55,5a,aa,a5,5a,00,00
					HEX	c4,45,50,05,50,55,45,44,cc

PIT1				HEX	42,26,26,26,26,26,42,cc,cc
					HEX	88,22,22,22,22,22,88,84,84

RUNNER1				HEX 00,00,00,90,90,90,00,00
					HEX	00,b0,f0,f9,fb,b0,00,b0
					HEX	0b,00,00,ff,ff,00,0b,00
					HEX	00,00,00,22,02,02,20,00
					HEX	00,11,02,00,00,00,12,10
					HEX	CC,c4,c4,c4,c4,c4,c4,c4
RUNNER2				HEX 00,00,00,90,90,90
					HEX	00,00,00,f9,fb,00
					HEX	00,00,B0,ff,fb,b0
					HEX	00,00,00,22,02,20
					HEX	00,00,11,02,01,02
					HEX	CC,CC,c4,c4,c4,c4
RUNNER3				HEX 00,00,00,90,90,90,00,00
					HEX	00,00,b0,f9,fb,f0,00,b0
					HEX	00,0b,00,ff,ff,00,0b,00
					HEX	00,00,00,22,02,20,00,00
					HEX	00,11,02,00,00,12,10,00
					HEX	CC,c4,c4,c4,c4,c4,c4,CC
RUNNER4				HEX 00,00,00,90,90,90
					HEX	00,00,00,f9,fb,00
					HEX	00,00,bb,ff,ff,b0
					HEX	00,00,00,22,22,00
					HEX	00,00,11,00,12,10
					HEX	CC,CC,c4,c4,c4,c4
JUMPY				HEX	00,00,00,00,00,00,00,00,00
					HEX 00,00,00,90,90,90,00,00,00
					HEX	00,00,b0,f9,fb,f0,00,b0,00
					HEX	00,0b,00,ff,ff,00,0b,00,10
					HEX	10,20,20,02,02,02,02,02,01
					HEX	01,00,00,00,00,00,00,00,00
					HEX	00,00,00,00,00,00,00,00,00

SPRITELOTABLE		db  <SPLOSION,<PURPLEBALL,<STUMP,<ROCK,<PIT1,<RUNNER1,<RUNNER2,<RUNNER3,<RUNNER4,<JUMPY,<ZERO,<ONE,<TWO,<THREE,<FOUR,<FIVE,<SIX,<SEVEN,<EIGHT,<NINE
SPRITEHITABLE		db	>SPLOSION,>PURPLEBALL,>STUMP,>ROCK,>PIT1,>RUNNER1,>RUNNER2,>RUNNER3,>RUNNER4,>JUMPY,>ZERO,>ONE,>TWO,>THREE,>FOUR,>FIVE,>SIX,>SEVEN,>EIGHT,>NINE

SPRITEHEIGHTTABLE	HEX 02,02,03,02,01,05,05,05,05,06,02,02,02,02,02,02,02,02,02,02
SPRITEWIDTHTABLE	HEX 04,03,08,08,08,07,05,07,05,08,03,03,03,03,03,03,03,03,03,03

SPRITEINDEXTABLE	HEX 05,02,03,04			; on-screen sprites can be any of the above, in any order

**************************************************
* sprite position, velocity, etc of on-screen sprites
**************************************************

SPRITEROW			HEX	11,14,14,16				
SPRITECOLUMN		HEX	01,28,40,58					
LASTROW				HEX	11,16,00,00					; location of last sprite drawn, for erasure
LASTCOLUMN			HEX	01,28,40,58					
HORIZSIGN			HEX	00,00,00,00					; 1 for positive H velocity, 0 for negative H velocity
VERTSIGN			HEX	00,00,00,00					; 1 or 0 for direction
HVELOCITY			HEX	00,01,01,01					; horizontal delta
VVELOCITY			HEX	00,00,00,00					; vertical delta

COLLIDINGSPRITES	HEX FF,FF

NUMBEROFSPRITES		HEX 00


CLOUDS	HEX 00,00,A0,FA,ff,ff,ff,fa,a0,00,00,00,00,00,00,00,00,00,00,00,00,00,0a,00,00,00,00,00,00,00,00,f0,00,00,00,00,00,00,00,00
	HEX 05,05,f5,f5,f5,a5,55,55,55,55,55,55,55,55,55,55,55,55,55,55,55,55,55,55,55,55,55,55,55,55,55,55,55,55,55,55,55,55,55,55
	HEX 55,55,55,5a,5f,5f,5f,5f,5a,50,50,50,a0,00,00,00,00,00,0a,05,05,05,05,05,05,05,05,05,05,05,05,05,05,05,05,05,05,05,05,05
	HEX 05,05,05,05,05,00,00,00,00,00,00,00,00,00,00,00,0f,00,00,00,00,00,00,00,00,00,00,00,f0,00,00,00,00,00,00,00,00,00,00,00

TWINKLE	HEX 00,00,A0,FA,ff,ff,ff,fa,a0,00,00,00,00,00,00,00,00,00,00,00,00,00,0f,00,00,00,00,00,00,00,00,50,00,00,00,00,00,00,00,00
	HEX 05,05,f5,f5,f5,a5,55,55,55,55,55,55,55,55,55,55,55,55,55,55,55,55,55,55,55,55,55,55,55,55,55,55,55,55,55,55,55,55,55,55
	HEX 55,55,55,5a,5f,5f,5f,5f,5a,50,50,50,a0,00,00,00,00,00,0a,05,05,05,05,05,05,05,05,05,05,05,05,05,05,05,05,05,05,05,05,05
	HEX 05,05,05,05,05,00,00,00,00,00,00,00,00,00,00,00,0a,00,00,00,00,00,00,00,00,00,00,00,a0,00,00,00,00,00,00,00,00,00,00,00


JUMPINGCURVE	HEX 11,10,0f,0e,0d,0c,0b,0a,09,09,09,09,0a,0b,0c,0d,0e,0f,0f
* how far up from base to be on each frame.
*** make this a nice smooth curve.

LOGO1	HEX	00,00,55,5a,5a,aa,00,55,aa,00,00,55,aa,00,50,a5,aa,aa,a5,aa,aa,a0,00,50,a5,5a,5a,aa,a5,00,55,aa,00,00,55,aa
		HEX	00,00,00,00,55,aa,00,55,aa,00,00,55,aa,00,55,aa,05,55,aa,05,55,aa,00,55,aa,00,00,55,aa,00,55,aa,00,00,55,aa
		HEX 00,00,00,00,55,aa,00,55,aa,a0,50,a5,aa,00,55,aa,00,55,aa,00,55,aa,00,55,aa,00,50,a5,aa,00,55,aa,00,00,55,aa
		HEX 50,a0,00,00,55,aa,00,00,05,0a,0a,0a,00,00,05,5a,00,05,5a,00,05,5a,00,55,aa,0a,0a,0a,05,00,00,05,5a,5a,5a,aa
		HEX 55,aa,00,00,55,aa,00,00,00,50,a5,5a,5a,5a,00,00,00,00,00,00,00,00,00,05,5a,00,00,00,00,00,05,5a,5a,5a,5a,05
LOGO2	HEX 00,05,5a,5a,5a,05,00,00,55,aa,05,00,00,00,00,55,aa,00,00,55,aa,00,55,aa,00,00,55,aa,00,00,00,00,00,00,00,00
		HEX	00,00,00,00,00,00,00,00,55,aa,00,55,5a,aa,00,55,aa,00,00,55,aa,00,55,aa,00,00,55,aa,00,00,00,00,00,00,00,00
		HEX	00,00,00,00,00,00,00,00,55,aa,50,00,55,aa,00,55,aa,a0,50,a5,aa,00,55,aa,00,00,55,aa,00,00,00,00,00,00,00,00
		HEX	00,00,00,00,00,00,00,00,00,05,5a,5a,5a,5a,00,00,05,0a,0a,0a,00,00,00,05,5a,5a,5a,aa,00,00,00,00,00,00,00,00
		HEX 00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,05,5a,5a,5a,5a,05,00,00,00,00,00,00,00,00
	

SCOREBOARD	HEX	22,22,22,22,22,22,22,22,22,22,22,22,f2,f2,f2,f2,22,f2,f2,f2,f2,22,22,22,22,22,22,22,22,22,f2,f2,f2,f2,22,f2,f2,f2,f2,22
			HEX	22,2a,aa,22,a2,22,a2,22,a2,a2,a2,22,ff,22,22,ff,22,ff,22,22,ff,22,22,22,aa,22,aa,22,2a,22,ff,22,22,ff,22,ff,22,22,ff,22
			HEX	22,22,aa,22,aa,a2,aa,22,aa,a2,aa,22,ff,f2,f2,ff,22,ff,f2,f2,ff,22,22,22,aa,2a,aa,22,aa,22,ff,f2,f2,ff,22,ff,f2,f2,ff,22
			HEX	22,22,22,22,22,22,22,22,2a,22,22,22,22,22,22,22,22,22,22,22,22,22,22,22,22,22,22,22,22,22,22,22,22,22,22,22,22,22,22,22

ZERO		HEX f2,f2,f2,f2,ff,22,22,ff,ff,f2,f2,FF
ONE			HEX	22,f2,f2,22,22,22,ff,22,22,22,ff,22
TWO			HEX	f2,f2,f2,f2,F2,F2,F2,FF,FF,F2,F2,F2
THREE		HEX	f2,f2,f2,f2,22,F2,F2,FF,F2,F2,F2,FF
FOUR		HEX	F2,22,22,F2,FF,F2,F2,FF,22,22,22,FF
FIVE		HEX	f2,f2,f2,f2,FF,F2,F2,F2,F2,F2,F2,FF
SIX			HEX	f2,f2,f2,f2,FF,F2,F2,F2,FF,F2,F2,ff
SEVEN		HEX	f2,f2,f2,f2,22,22,22,FF,22,22,22,FF
EIGHT		HEX	f2,f2,f2,f2,FF,F2,F2,FF,FF,F2,F2,ff
NINE		HEX	f2,f2,f2,f2,FF,F2,F2,FF,F2,F2,F2,FF

DIGITSLO	db <ZERO,<ONE,<TWO,<THREE,<FOUR,<FIVE,<SIX,<SEVEN,<EIGHT,<NINE
DIGITSHI	db >ZERO,>ONE,>TWO,>THREE,>FOUR,>FIVE,>SIX,>SEVEN,>EIGHT,>NINE


SPLOSION	HEX	b0,00,30,00,b0
			HEX 30,93,d9,93,30
			HEX	b0,03,39,03,b0

BURGER		HEX	00,00,00,00,90,90,d9,99,d9,99,d9,99,d9,99,d9,99,d9,90,90,00,00,00,00
			HEX	00,00,90,89,d8,9d,d9,9d,d9,9d,d9,9d,d9,9d,d9,9d,d9,9d,d9,99,90,00,00
			HEX	00,00,d0,d9,18,19,d9,d9,19,d9,d9,d9,d9,d9,d9,d9,19,19,19,d9,d0,00,00
			HEX	0c,0c,84,8c,84,84,84,c4,4d,4d,8d,88,88,88,4c,4c,84,81,8c,8c,8c,04,0c
			HEX	00,08,80,88,80,88,88,88,88,88,88,88,88,88,88,88,88,88,80,88,80,08,00
			HEX	00,00,00,99,89,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,00,00,00
			HEX	00,00,00,00,09,08,09,09,09,09,09,09,09,09,09,09,09,09,09,00,00,00,00


**************************************************
* Lores/Text lines
* Thanks to Dagen Brock for this.
**************************************************
Lo01                 equ   $400
Lo02                 equ   $480
Lo03                 equ   $500
Lo04                 equ   $580
Lo05                 equ   $600
Lo06                 equ   $680
Lo07                 equ   $700
Lo08                 equ   $780
Lo09                 equ   $428
Lo10                 equ   $4a8
Lo11                 equ   $528
Lo12                 equ   $5a8
Lo13                 equ   $628
Lo14                 equ   $6a8
Lo15                 equ   $728
Lo16                 equ   $7a8
Lo17                 equ   $450
Lo18                 equ   $4d0
Lo19                 equ   $550
Lo20                 equ   $5d0
* the "plus four" lines
Lo21                 equ   $650
Lo22                 equ   $6d0
Lo23                 equ   $750
Lo24                 equ   $7d0


Alt01                 equ   $800
Alt02                 equ   $880
Alt03                 equ   $900
Alt04                 equ   $980
Alt05                 equ   $A00
Alt06                 equ   $A80
Alt07                 equ   $B00
Alt08                 equ   $B80
Alt09                 equ   $828
Alt10                 equ   $8a8
Alt11                 equ   $928
Alt12                 equ   $9a8
Alt13                 equ   $A28
Alt14                 equ   $Aa8
Alt15                 equ   $B28
Alt16                 equ   $Ba8
Alt17                 equ   $850
Alt18                 equ   $8d0
Alt19                 equ   $950
Alt20                 equ   $9d0
* the "plus four" lines
Alt21                 equ   $A50
Alt22                 equ   $Ad0
Alt23                 equ   $B50
Alt24                 equ   $Bd0




LoLineTable          da    	Lo01,Lo02,Lo03,Lo04
                     da    	Lo05,Lo06,Lo07,Lo08
                     da		Lo09,Lo10,Lo11,Lo12
                     da    	Lo13,Lo14,Lo15,Lo16
                     da		Lo17,Lo18,Lo19,Lo20
                     da		Lo21,Lo22,Lo23,Lo24

AltLineTable         da    	Alt01,Alt02,Alt03,Alt04
                     da    	Alt05,Alt06,Alt07,Alt08
                     da		Alt09,Alt10,Alt11,Alt12
                     da    	Alt13,Alt14,Alt15,Alt16
                     da		Alt17,Alt18,Alt19,Alt20
                     da		Alt21,Alt22,Alt23,Alt24


** Here we split the table for an optimization
** We can directly get our line numbers now
** Without using ASL
LoLineTableH         db    >Lo01,>Lo02,>Lo03
                     db    >Lo04,>Lo05,>Lo06
                     db    >Lo07,>Lo08,>Lo09
                     db    >Lo10,>Lo11,>Lo12
                     db    >Lo13,>Lo14,>Lo15
                     db    >Lo16,>Lo17,>Lo18
                     db    >Lo19,>Lo20,>Lo21
                     db    >Lo22,>Lo23,>Lo24
LoLineTableL         db    <Lo01,<Lo02,<Lo03
                     db    <Lo04,<Lo05,<Lo06
                     db    <Lo07,<Lo08,<Lo09
                     db    <Lo10,<Lo11,<Lo12
                     db    <Lo13,<Lo14,<Lo15
                     db    <Lo16,<Lo17,<Lo18
                     db    <Lo19,<Lo20,<Lo21
                     db    <Lo22,<Lo23,<Lo24

AltLineTableH        db    >Alt01,>Alt02,>Alt03
                     db    >Alt04,>Alt05,>Alt06
                     db    >Alt07,>Alt08,>Alt09
                     db    >Alt10,>Alt11,>Alt12
                     db    >Alt13,>Alt14,>Alt15
                     db    >Alt16,>Alt17,>Alt18
                     db    >Alt19,>Alt20,>Alt21
                     db    >Alt22,>Alt23,>Alt24
AltLineTableL        db    <Alt01,<Alt02,<Alt03
                     db    <Alt04,<Alt05,<Alt06
                     db    <Alt07,<Alt08,<Alt09
                     db    <Alt10,<Alt11,<Alt12
                     db    <Alt13,<Alt14,<Alt15
                     db    <Alt16,<Alt17,<Alt18
                     db    <Alt19,<Alt20,<Alt21
                     db    <Alt22,<Alt23,<Alt24

