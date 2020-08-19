/*
 ___           _        __ ___ _  __  
/ __|_ _  __ _| |_____ / /| __/ |/  \ 
\__ \ ' \/ _` | / / -_) _ \__ \ | () |
|___/_||_\__,_|_\_\___\___/___/_|\__/ 

FIX: Add here an explanation of how the pointers work as it is quite complex and 6502's zeropage indirect-indexed
and indexed-indirect addressing modes are not obvious and also require sometimes superfluous value 0 in X register.

*/                             


// Constants:
    .const w_pressed    = $57  // "w": Up      
    .const a_pressed    = $41  // "a": Left
    .const s_pressed    = $53  // "s": Down
    .const d_pressed    = $44  // "d": Right

    // FIX: Add uppercase WASD key constants. At least with emulators player could accidentally
    // press caps lock key while playing the game resulting in non-responsive keyboard.

    .const up_pressed   = $91  // Up arrow      
    .const left_pressed = $9d  // Left arrow
    .const down_pressed = $11  // Down arrow
    .const right_pressed = $1d  // Right arrow

    .const p_pressed    = $50   // "p": Pause

    .const moving_up    = 1     // Using 2^0, 2^1, 2^3, 2^4 for easy bit testing 
    .const moving_right = 2     
    .const moving_down  = 4
    .const moving_left  = 8

    .const char_apple   = $40   // Diamond character
    .const char_space   = $20   // Space character
    .const char_body    = $50   // Horizontal body character

    .const screen_ram   = $0400 // Standard screen ram address
    .const color_ram    = $d800 // Standard color ram address

    .const green_color  = 5    

// Variables
    .var apple_low          = $02   // Apple's position in screen RAM 
    .var apple_high         = $03
    .var color_low          = $04   // Position in color RAM
    .var color_high         = $05
    .var direction          = $06   // Direction of movement
    .var previous_direction = $07 
    .var speed              = $08
    .var score_low          = $09   // 16-bit counter for score
    .var score_high         = $0a
    .var hi_score_low       = $0b  // 16-bit high score
    .var hi_score_high      = $0c
    .var temp_low           = $0d   // Temporary zeropage address
    .var temp_high          = $0e
    .var head_low           = $0f   // Pointer to head's memory address
    .var head_high          = $10
    .var tail_low           = $11   // Pointer to tail's memory address
    .var tail_high          = $12
    .var frame_counter      = $13   // Frame counter for the head and tail animation 
    .var head_table_low     = $14   // Table of characters for head animation
    .var head_table_high    = $15
    .var tail_table_low     = $16   // Table of characters for tail animation
    .var tail_table_high    = $17
    .var apple_collision_flag = $18 // Flag for collision with an apple


    * = $3800 "Characters"       // Character map
    .import binary "snake_charmap.bin"


    BasicUpstart2(start)            // Kick Assembler macro for BASIC start
    * = $0810 "Game"

start:
            jsr init_hi_score       // Init high score just once per session     
            jsr init_charmap        // Init animated characters       
new_game:      
            jsr init_game           // Game setup  
            jsr init_screen
            jsr init_snake
            jsr generate_apple
            jsr print_score
            jsr print_hi_score

game_loop:
            jsr draw_snake          // Game loop 
            jsr read_keys
            jsr update_snake        
            jsr check_collision      
            jmp game_loop

init_hi_score:                       
            lda #0
            sta hi_score_low
            sta hi_score_high

init_charmap:
            lda $d018               // Charmap address
            and #%11110000          // Mask for lower 4 bits
            ora #14                 // Point memory to $3800
            sta $d018

init_game:
            lda #0                  // Zero out counters and flags
            sta score_low           // Set score to zero
            sta score_high     
            sta frame_counter       // Frame counter for head and tail animation
            sta apple_collision_flag

            lda #$ff                // init SID for pseudo random numbers
            sta $d40e 
            sta $d40f 
            lda #$80  
            sta $d412
            rts

init_screen:
            sta $d020               // Black screen and background
            sta $d021       

            ldx #0                 // Loop counter
clear_loop:
            lda #5                 // Green color for the color RAM
            sta color_ram,x
            sta color_ram+$100,x
            sta color_ram+$200,x
            sta color_ram+$2e8,x

            lda #char_space         // Clear all characters
            sta screen_ram,x
            sta screen_ram+$100,x
            sta screen_ram+$200,x
            sta screen_ram+$2e8,x
            inx 
            bne clear_loop

draw_borders:
            // Lines
            lda #80                 // Horizontal line char
            ldx #38                 // Counter to 38

horizontal_line_loop:
            sta screen_ram,x
            sta screen_ram+40*24,x
            dex
            bne horizontal_line_loop

            ldx #0
vertical_line_loop:
            lda #98                 // Vertical line char
            sta screen_ram+40,x
            sta screen_ram+280,x
            sta screen_ram+520,x
            sta screen_ram+760,x

            sta screen_ram+40+39,x
            sta screen_ram+280+39,x
            sta screen_ram+520+39,x
            sta screen_ram+760+39,x

            txa
            clc
            adc #40
            tax 
            cmp #240            
            bne vertical_line_loop

            // Corners
            lda #68
            sta screen_ram
            lda #67
            sta screen_ram+39
            lda #66
            sta screen_ram+40*24
            lda #65
            sta screen_ram+40*24+39
            
            // Heads and tails
            lda #76
            sta screen_ram+6
            sta screen_ram+25

            lda #85
            sta screen_ram+17
            sta screen_ram+33
            rts       

init_snake:     
            lda #moving_right       // Initial direction
            sta direction
            sta previous_direction  // Initial previous direction

            lda #<animate_head_right // Head and tail animation table start
            sta head_table_low
            lda #>animate_head_right
            sta head_table_high

            lda #<animate_tail_right
            sta tail_table_low
            lda #>animate_tail_right
            sta tail_table_high            

            lda #$ff                // Starting speed
            sta speed
            
            lda #$06                // Initial pointer addresses 
            sta head_low
            lda #$10
            sta head_high
            lda #$10                // Set to one three bytes lower 
            sta tail_high
            lda #$00
            sta tail_low

            // Head and tail initial positions
            lda #char_body
            sta $05f3               // Draw initial middle segment that is not drawn by draw_snake
                                    // CHECK: Perhaps this is not needed after fixing the draw routing
                                    // to draw a segment in the head's previous pointer position. 

            lda #$f4                // Low screen ram bytes
            sta $1006
            lda #$f3
            sta $1003
            lda #$f2
            sta $1000

            lda #$05                // High screen RAM bytes
            sta $1007
            sta $1004
            sta $1001

            lda #moving_right       // Set direction right to all
            sta $1002
            sta $1005
            sta $1008

            rts

generate_apple:                 // Random position between $0400-$07e7 and $d800-$dbe7
            lda $d41b           // Get random number 0-255 from SID, low byte
            sta apple_low
            sta color_low            
            lda $d41b           // Random high byte
            and #%00000011      // Mask with #00000011 to get 0-3
            cmp #3              // If not 3 then... 
            bne high_else       // ...skip to high_else
            ldx apple_low       // Use X register, so that A keeps intact
            cpx #$e8            // If low byte is <= e7...
            bcc high_else       // ...skip to high_else, if carry is clear (cmp doesn't set carry)
            txa                 // Copy X to A
            clc                 // Set carry
            adc #$18            // Add 18 to get $0-$e7
            sta apple_low
            sta color_low
            lda #3              // Load back 3

high_else:  clc
            adc #4              // Add 4 to get $04-$07
            sta apple_high
            clc
            adc #$d4            // Add $d4 to get $d8-$db
            sta color_high

            // Check snake collision
            ldx #0
            lda (apple_low,x)
            cmp #char_space
            bne generate_apple

            // Paint apple
            ldx #0              // Offset 0
            lda #char_apple     // Apple
            sta (apple_low,x)   // Screen ram
            lda #2              // Red color
            sta (color_low,x)   // Color ram
            rts

check_collision:
            ldx #0                  // Check collision by char
            lda (head_low,x)        // Copy head's address to zeropage temp
            sta temp_low
            ldy #1
            lda (head_low),y
            sta temp_high
            lda (temp_low,x)
            cmp #char_space
            beq collision_else
            cmp #char_apple
            beq apple_collision
        
            jmp gameover            // Snake/wall collision, jump to gameover routine

apple_collision:
            // collided with an apple
            lda #1                  // Set apple collision flag
            sta apple_collision_flag
            sed                     // Count score in decimal mode
            lda score_low
            clc
            adc #1
            sta score_low
            lda score_high
            adc #0                  // Adds 0 + carry
            sta score_high
            cld
            lda #2
            cmp speed               // Increase speed
            beq speed_else
            dec speed
            // dec speed            // Redundant; one is enough
speed_else:                      
            jsr print_score
            jsr generate_apple      // Create new apple   
          
collision_else:
            rts

draw_snake:
            // Wait for vertical blank before drawing to eliminate screen tearing
            lda #250                // Raster line 250
check_raster_line:
            cmp $d012
            bne check_raster_line

            // raster timer
            // inc $d020

            lda apple_collision_flag
            bne apple_collision_else    // If collided with an apple, skip tail erase

            // Erase tail
            ldx #0            
            lda (tail_low,x)        // Copy tail pointer's address to zeropage temp
            sta temp_low
            ldy #1                  
            lda (tail_low),y        // High byte, 2nd byte
            sta temp_high

            ldy #2                  // Read tail's direction
            lda (tail_low),y        // Tail's direction, 3rd byte

            lsr                     // Direction can be 1 (up), 2 (right), 4 (down), 8 (left)
            bcs tail_up             // Logical shift right to test for direction
            lsr                     // Branch if carry is set
            bcs tail_right
            lsr
            bcs tail_down
            lsr
            bcs tail_left      

tail_up:
            lda #<animate_tail_up
            ldy #>animate_tail_up
            jmp erase_tail_else    

tail_right:
            lda #<animate_tail_right
            ldy #>animate_tail_right
            jmp erase_tail_else

tail_down:
            lda #<animate_tail_down
            ldy #>animate_tail_down
            jmp erase_tail_else

tail_left:
            lda #<animate_tail_left
            ldy #>animate_tail_left

erase_tail_else:
            sta tail_table_low
            sty tail_table_high  
            ldy frame_counter       // Read frame counter
            lda (tail_table_low),y  // Read char from the tail animation table
            sta (temp_low,x)        // Draw char 

            cpy #0                  // If frame counter == 1 then
            bne apple_collision_else
            ldy tail_high           // e.g. $10
            lda tail_low            // e.g. $08
            jsr decrease_pointer    // Decrease tail pointer
            sty tail_high           // Copy tail's pointer position to temp
            sta tail_low            // e.g. $00
            ldx #0
            lda (tail_low,x)
            sta temp_low
            ldy #1
            lda (tail_low),y
            sta temp_high
            lda #char_space         // Space char
            //ldx #0                // Possibly redundant
            sta (temp_low,x)        // Draw body
                                    // Draw solid body with correct direction
            ldy tail_high           // e.g. $10
            lda tail_low            // e.g. $08
            jsr increase_pointer    // Increase tail pointer
            sty tail_high           // Save back old value
            sta tail_low                         
 

apple_collision_else:
            // Draw head
            ldx #0                  // Redundant; here just for code readability
            lda (head_low,x)        // Copy head's pointer position to temp
            sta temp_low            // e.g. $00
            ldy #1
            lda (head_low),y
            sta temp_high           // e.g. $f4

            ldy frame_counter       // Animation frame counter
            lda (head_table_low),y  // Char by frame from animation table
            sta (temp_low,x)        // Draw char to screen    

/*
            In the beginning of each character animation (frame 0) we need also to 
            draw body character to the previous snake segment. We get the previous 
            segment by decreaseing the head's pointer. Then we just draw the character
            and increase the pointer back to where it was. We also need to note that
            increase and decrease routines use registers Y, A and X. Especially in the
            X register is garbage after the routine. 
            
            HACK: We should fix this by pushing X to stack and pulling it back in the routines.
*/

            cpy #0                  // If frame counter == 0 (we have frame_counter in the Y register already) 
            bne color_head          // 
            ldy head_high           // e.g. $10
            lda head_low            // e.g. $08
            jsr decrease_pointer    // Decrease head pointer
            sty head_high            
            sta head_low
            ldx #0                  // HACK: We should have the drawing of a character as a routine  
            lda (head_low,x)        // as it is repeated 2 or 3 times here
            sta temp_low
            ldy #1
            lda (head_low),y
            sta temp_high
            
            // Determine the orientation of the segment

            // Check if we need a turn segment

            // Check which turn we should use 
            
            // Previous direction OR current direction

            // If the result is 1 (up), 2 (right), 4 (down), 8 (left) it's a straight line

            /*
            Four valid combinations of bits that result in a certain turn segment

            %00000011   up + right (or right + up)
            %00001001   up + left
            %00000110   down + right
            %00001100   down + left

            Other combinations are illegal and are filtered in the read_keys routine

            */

            // If not draw a straight segment

            lda #char_body          // Horizontal body char



            //ldx #0                // Redundant; just for readability
            sta (temp_low,x)        // Draw body
                                    // Draw solid body with correct direction
            ldy head_high           // e.g. $10
            lda head_low            // e.g. $08
            jsr increase_pointer    // Increase head pointer
            sty head_high           // Copy head's pointer position to temp
            sta head_low            // e.g. $00     


color_head:
            // Color head           
            lda temp_high
            clc
            adc #$d4                // Add $d4 to high screen address to get color RAM address
            sta temp_high
            lda #green_color        
            ldx #0                  // Redundant; here just for code readability       
            sta (temp_low,x)

            // raster timer
            // dec $d020

            // Frame counter for head and tail animation
            jsr wait_loop            
            inc frame_counter
            lda #8
            cmp frame_counter
            beq animation_done
            jmp draw_snake

animation_done:
            lda #0
            sta frame_counter   

            rts

update_snake:                     
            // Make a copy of the head pointer to temp ($1000-$1bb8)
            // It will be the previous pointer position after increasing the pointer
            lda head_low            // e.g. "$00"
            sta temp_low
            ldy head_high           // e.g. "$10"
            sty temp_high
            jsr increase_pointer
            sta head_low            // Save the new pointer position
            sty head_high

increase_tail_pointer:
            // If apple collision flag is set, skip tail pointer increase (snake grows)
            lda #1
            cmp apple_collision_flag
            beq update_snake_else

            // Load tail pointer into A and Y registers for the increase pointer routine
            lda tail_low            // e.g. "$00"
            ldy tail_high           // e.g. "$10"
            jsr increase_pointer
            sta tail_low            // Save the new pointer position
            sty tail_high

update_snake_else:
            lda #0
            sta apple_collision_flag    // Clear apple collision flag; HACK: required only after collision

            // Move head in right direction
            lda direction

            ldy #2                      // Save direction to the previous head pointer position 
            sta (temp_low),y            // Temp still has the last head pointer position
                                            
            lsr                         // Logical shift right to test direction 1 (up), 2 (right), 4 (down), 8 (left)
            bcs direction_up
            lsr
            bcs direction_right
            lsr
            bcs direction_down
            lsr
            bcs direction_left

            rts   

increase_pointer:
            // Low byte in A register and high byte in Y register
            // Uses X register for saving A register

            // Increase pointer by three bytes
            clc
            adc #3                  // Add tree to low byte
            tax                     // Move A register to X
            tya                     // Move Y register to A
            adc #0                  // Add potential carry
            tay                     // Move A register back to Y
            txa                     // Move X regiser back to A

            // Wrap around after $1bb8 (3000 bytes); pointer == $1bb8 
            cpy #$1b                // High byte in Y register
            bne increase_pointer_done       

            cmp #$b8                // Low byte in A register
            bne increase_pointer_done       

            // Load $1000 into A and Y registers
            lda #$00                
            ldy #$10

increase_pointer_done:
            rts                     // Return new pointer in A and Y register

decrease_pointer:
            // Low byte in A register and high byte in Y register
            // Uses X register for saving A register

            // Decrease pointer by three bytes
            sec
            sbc #3                  // Substract tree to low byte
            tax                     // Move A register to X
            tya                     // Move Y register to A
            sbc #0                  // Substract potential carry
            tay                     // Move A register back to Y
            txa                     // Move X regiser back to A

            rts                     // Return new pointer in A and Y register

            // Wrap around after $0000 (3000 bytes); pointer == $0000 
            cpy #$00                // High byte in Y register
            bne decrease_pointer_done       

            cmp #$00                // Low byte in A register
            bne decrease_pointer_done       

            // Load $1000 into A (low byte) and Y registers (high byte)
            lda #$00                
            ldy #$10

decrease_pointer_done:
            rts    

direction_up:    

            ldx #0
            lda (temp_low,x)        // Temp has the previous pointer position

            sec
            sbc #$28                // Substract 40 to get to the position above
            sta (head_low,x)        // Save new low byte to new pointer position

            ldy #1
            lda (temp_low),y        // High byte
            sbc #0                  // Substract potential carry 
            sta (head_low),y        // Save new high byte to new pointer position

            lda #<animate_head_up   // Set head animation table address
            sta head_table_low
            lda #>animate_head_up
            sta head_table_high
            rts

direction_right:

            // Add one to the value held in old pointer address e.g. $1000
            ldx #0
            lda (temp_low,x)        // $f4

            clc
            adc #1                  // $f5                        
            sta (head_low,x)        // Store new low byte to new pointer position

            ldy #1
            lda (temp_low),y        // $05         
            adc #0                  // Add potential carry 
            sta (head_low),y        // Store new high byte to new pointer position

            lda #<animate_head_right
            sta head_table_low
            lda #>animate_head_right
            sta head_table_high

            rts

direction_down:            
            ldx #0
            lda (temp_low,x)

            clc
            adc #$28                // Add 40 to go to the char below
            sta (head_low,x)

            ldy #1
            lda (temp_low), y
            adc #0                  // Add potential carry 
            sta (head_low),y

            lda #<animate_head_down
            sta head_table_low
            lda #>animate_head_down
            sta head_table_high

            rts

direction_left:       
            ldx #0
            lda (temp_low,x)

            sec
            sbc #1                  // Substract 1 to go left one char 
            sta (head_low,x)

            ldy #1
            lda (temp_low),y
            sbc #0                  // Substract potential carry
            sta (head_low),y

            lda #<animate_head_left
            sta head_table_low
            lda #>animate_head_left
            sta head_table_high        

            rts

gameover:

            jsr print_hi_score

            // Print "Game over!"
            ldx #0
gameover_loop:
            lda gameover_text,x
            sta $05c7,x
            lda #5
            sta $d9c7,x
            inx
            cpx #$0a
            bne gameover_loop

press_space:            
            jsr $ffe4
            beq press_space         // Loop until a key is pressed
            cmp #$20
            bne press_space         // Loop back if it is not space
            jmp new_game

print_score:
            ldx #0
print_score_loop:            
            lda score_text,x
            sta $0407,x
            lda #5
            sta $d807,x
            inx
            cpx #$06
            bne print_score_loop

            ldy #3
            ldx #0
score_loop:
            lda score_low,x
            pha                 // Save a copy to stack
            and #$0f
            jsr print_score_digit

            pla                 // Pull score from stack
            lsr                 // Logical shift right x4 shifts high nybble to low
            lsr 
            lsr 
            lsr 
            jsr print_score_digit

            inx 
            cpx #2
            bne score_loop
            rts

print_score_digit:
            clc
            adc #48             // Add 48 to the digit to get the right PETSCII code
            sta $040d,y
            dey
            rts

print_hi_score:
            // If score is higher than hi score, save new hi score

            lda score_high
            cmp hi_score_high
            bcc print_hi_score_else     // If score_high < hi_score_high             
            bne save_new_hi_score       // If score_high > hi_score_high
             
            lda score_low
            cmp hi_score_low
            bcc print_hi_score_else     // If score_low < hi_score_low
            beq print_hi_score_else     // If score_low == hi_score_low

            // Save score as new hi score
save_new_hi_score:
            lda score_high
            sta hi_score_high
            lda score_low
            sta hi_score_low

print_hi_score_else:

            // Print new hi score
            ldx #0
print_hi_score_loop:            
            lda hi_score_text,x
            sta $041a,x
            lda #5
            sta $d81a,x
            inx
            cpx #3
            bne print_hi_score_loop

            ldy #3
            ldx #0
hi_score_loop:
            lda hi_score_low,x
            pha                 // Save a copy to stack
            and #$0f
            jsr print_hi_score_digit

            pla                 // Pull score from stack
            lsr                 // Logical shift right x4 shifts high nybble to low
            lsr 
            lsr 
            lsr 
            jsr print_hi_score_digit

            inx 
            cpx #2
            bne hi_score_loop
            rts

print_hi_score_digit:
            clc
            adc #48
            sta $041d,y
            dey

hi_score_done:            
            rts

read_keys:
            jsr $ffe4               // Get char from a key press; KERNAL function                                

            cmp #w_pressed
            beq up_key
            cmp #up_pressed
            beq up_key

            cmp #d_pressed
            beq right_key
            cmp #right_pressed
            beq right_key

            cmp #s_pressed
            beq down_key
            cmp #down_pressed
            beq down_key

            cmp #a_pressed
            beq left_key
            cmp #left_pressed
            beq left_key

            cmp #p_pressed
            beq pause_key

            rts

up_key:
            lda #moving_down            // Test for illegal move; cannot turn 180 degrees
            bit direction               // Bit test for illegal move
            bne read_keys_done          // If illegal move, then don't change direction

            lda direction               // Save direction to previous direction
            sta previous_direction      

            lda #moving_up              // Change direction
            sta direction
            rts

right_key:
            lda #moving_left
            bit direction
            bne read_keys_done

            lda #moving_right
            sta direction
            rts            
down_key:
            lda #moving_up
            bit direction
            bne read_keys_done

            lda #moving_down
            sta direction
            rts
left_key:
            lda #moving_right
            bit direction
            bne read_keys_done

            lda #moving_left
            sta direction
            rts

pause_key:
            jsr $ffe4                   // KERNAL routine registering key presses
            beq pause_key               // If no key was pressed, loop back
            cmp #p_pressed              // Test for key "p" for pause
            bne pause_key               // If "p" was not pressed, loop back                     

read_keys_done:
            rts

wait_loop:  
            ldx #$ff                     // Busy loop for adujusting speed

spin_loop:  
            ldy speed
spin_inner_loop:
            dey
            bne spin_inner_loop
            dex
            bne spin_loop
            rts           

gameover_text:
            .text "game over!"
score_text:
            .text "score:"
hi_score_text:
            .text "hi:"

// Animation character tables for head and tail; 8 directions x 4 characters
animate_head_right:
            .byte 72, 73, 74, 75, 76, 77, 78, 79, 80
animate_head_left:
            .byte 81, 82, 83, 84, 85, 86, 87, 88, 80
animate_head_up:
            .byte 89, 90, 91, 92, 93, 94, 95, 97, 98
animate_head_down:
            .byte 99, 100, 101, 102, 103, 104, 105, 106, 98
animate_tail_right:
            .byte 88, 87, 86, 85, 84, 83, 82, 81, 32
animate_tail_left:
            .byte 79, 78, 77, 76, 75, 74, 73, 72, 32
animate_tail_up:
            .byte 106, 105, 104, 103, 102, 101, 100, 99, 32
animate_tail_down:
            .byte 97, 95, 94, 93, 92, 91, 90, 89, 32

animate_head_right_turn_up:
            .byte 72, 73, 74, 75, 76, 77, 78, 79, 65



