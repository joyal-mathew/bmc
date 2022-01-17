# Big Man Compiler

A simple compiler for the [Little Man Computer](https://www.peterhigginson.co.uk/LMC/).

## Grammar

The program is composed out of a series of commands

| Description      | Command                |
|------------------|------------------------|
| Set Memory       | `set ADDR to VALUE`    |
| Add              | `add VALUE to ADDR`    |
| Subtract         | `sub VALUE from ADDR`  |
| Assembly         | `asm STRING`           |
| If               | `if CONDITION ADDR`    |
| Else             | `else`                 |
| End if           | `end`                  |
| While            | `while CONDITION ADDR` |
| End While        | `loop`                 |
| Halt             | `halt`                 |
| Input Number     | `input to ADDR`        |
| Output Number    | `outn from ADDR`       |
| Output Character | `outc from ADDR`       |

`ADDR` can either be a letter `a` to `z`, which is interpreted as a memory address `74` to `99` (earlier letters are stored higher in memory), or an `INTEGER` which is interpreted directly as an address

`VALUE` can either be a letter, which is interpreted as the value in the address it specifies, or an `INTEGER`

`INTEGER` can either be a literal integer in the range `-999` to `999` or a character in the same range between single quotes

`CONDITION` is either `true`, which check if the address contains a nonzero value, or `negative`, which checks if the address contains a value is less than zero.

`STRING` is a series of characters in between quotes

## Example

A program to take two numbers `a` and `b` as input and comput `a` to the power of `b`

	input to a
	input to b

	set c to a

	sub 1 from b

	while true b do
	 sub 1 from b

	 set d to a
	 set e to 0

	 while true d do
	  sub 1 from d
	  add c to e
	 loop

	 set c to e
	loop
	
	outn from c
