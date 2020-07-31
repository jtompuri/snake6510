# Snake 6510

Snake 6510 game for C64 written in 6510 assembly. Your goal is to eat as many apples as possible and to avoid collision. You can control the snake with "w", "a", "s", "d" keys or cursor keys. Press "p" for pause. The source code is written for Kick Assembler. The idea for the game came from Nick Morgan's tutorial on 6502 programming: https://skilldrick.github.io/easy6502/

## Fixes to original code

This version is specific for C64 and fixes some bugs and inefficiences in the original code. For example, snake's body coordinates are not copied or shifted in the memory; rather, two pointers are incremented and looped over in a 3K memory block. Snake can be 1000 characters long (full screen). The original snake glitched after being 50-60 characters long because of a zero page overflow. Apples are not generated on the snake in this code. Biggest visual improvement has to do with the character animation of the head and tail that produces smoother snake movement. 

## Pre-built prg file

You can find pre-built prg file in the [c64_files](https://github.com/jtompuri/snake6510/tree/master/c64_files) folder.

## Kick Assembler

You can download Kick Assembler here:
http://www.theweb.dk/KickAssembler/

## Backlog

- Start screen PETSCII art
- Levels with walls, 3 lives, 10 apples per level
- Commander X16 port of the game
- Powerups

## TODO

- Sound effects for moving and eating
- Custom chars for apple, head, tail, body  
- Improve text print routine: add zero byte and check for it
- Add support for uppercase WASD keys
