# snake6510

 ___           _        __ ___ _  __  
/ __|_ _  __ _| |_____ / /| __/ |/  \ 
\__ \ ' \/ _` | / / -_) _ \__ \ | () |
|___/_||_\__,_|_\_\___\___/___/_|\__/ 

Snake 6510 game for C64 written in 6510 assembly. Your goal is to eat 
as many apples as possible and to avoid collision. The source code is 
written for Kick Assembler. The idea for the game came from Nick Morgan's 
tutorial on 6502 programming: https://skilldrick.github.io/easy6502/

This version is specific for C64 and fixes some bugs and inefficiences in the 
original code. For example, snake's body coordinates are not copied or shifted 
in the memory; rather, two pointers are incremented and looped over in a 3K memory 
block. Snake can be 1000 characters long (full screen). The original snake glitched 
after being 50-60 characters long because of a zero page overflow. Apples are not 
generated on the snake in this code. Biggest visual improvement has to do with the
character animation of the head and tail that produces smoother snake movement. 
