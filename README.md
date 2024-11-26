# Advent of Code - December 1st 2023

## Introduction
I'm apparently a masochist.

I haven't written assembly in anger since my Computer Science Degree more than 20 years ago; and even then it was directly against hardware, or in C using standard libraries.

As an academic exercise I decided to try replicate my Advent of Code solution from December 1st 2023 in pure x86_x64 assembly on Linux.  No libraries, no macros, no nothing.  Just pure talking to the CPU directly, or OS via syscalls.

The solutions for the two parts use a lot of common chunks of code.  It's probably not as optimised as it could be, in terms of both instruction count and instruction size - but it works.

There are some `TODO` elements floating around - mainly tests for edge cases that I just couldn't be bothered finishing up once it actually spat out the right answers.

---

## Common Components

### Command Line Argument Processing

* Retrieves `argc` and `**argv` from the stack.
* Checks that `argc` is `2` and exits with an error message otherwise.
* Retrieves the string value `argv[1]` and finds the length of it.

### File Path Processing

* Reserves 256 bytes for the file path on the stack.
* Gets the Current Working Directory (`cwd`) and the length of the `cwd` string value using the `sys_getcwd` syscall.
* Checks that the length of the filename (from `argv[1]`) plus the length of `cwd` is less than 256 - exits with an error message otherwise.
* Concatenates the filename (from `argv[1]`) to the cwd to get the full file path.

### File Reading

* Uses the `sys_stat` syscall to get the size of the file - if this fails (e.g. because of an invalid path) exit with an error message.
* Uses the `sys_open` syscall to get a file descriptor for the file.
* Uses the `sys_mmap` syscall to map the file into memory.

### File Closing

* Uses the `sys_munmap` syscall to release the file memory mapping.
* Uses the `sys_close` syscall to release the file descriptor for the file.

### Convert a number to string bytes
* Divide the number by 10, push the value of the remainder plus 48 onto the stack (0 + 48 = 48 = ASCII code for 0; 9 + 48 = 57 = ASCII code for 9)
* Repeat until the number is zero.
* Treat consecutive bytes on the stack as the string.

### stdout
* Uses the `sys_write` syscall to write a buffer to file descriptor 1 - `stdout`

### stderr
* Uses the `sys_write` syscall to write a buffer to file descriptor 2 - `stderr`

### exit
* Uses the `sys_exit` syscall to exit the process with a specified return code

---

## Part One
* Start off with registers for:
  * the First Digit on each line
  * the Last Digit on each line
  * the current position in the file
  * the cumulative answer
* Initialise the First/Last digit with an impossible value (128) to signify that it hasn't been populated yet.
* Read the character at the current position in the file
  * If we're at the end of the file, add the value of the Last Digit to the cumulative answer, and stop processing - we have the answer.
  * If the character is >57 then it's not a number, skip to the next character in the file
  * If the character is a newline, then:
    * Add the value of the Last Digit to the cumulative answer
    * Reset the First Digit and Last Digit to 128
    * Skip to the next character
  * If the character is <48 then it's not a number, skip to the next character in the file
  * The character is a digit:
    * Set the Last Digit to the value of the digit
    * If the First Digit is undefined (128), then:
        * Set the First Digit to the value of the digit
        * Multiply the First Digit by 10
        * Add the First Digit to the cumulative answer
        * Skip to the next character in the file

---

## Part Two
Part Two works similarly to Part One, but additionally we use a State Machine to process any alphabetical characters.

The detail of the State Machine is in a separate section below.

* Start off with registers for:
  * the First Digit on each line
  * the Last Digit on each line
  * the current position in the file
  * the cumulative answer
  * the current State Machine offset
* Initialise the First/Last digit with an impossible value (128) to signify that it hasn't been populated yet.
* Read the character at the current position in the file
  * If we're at the end of the file, add the value of the Last Digit to the cumulative answer, and stop processing - we have the answer.
  * If the character is a newline, then:
    * Add the value of the Last Digit to the cumulative answer
    * Reset the First Digit and Last Digit to 128
    * Skip to the next character in the file and reset the State Machine offset to 0
  * If the character is <48 then it's not a number, skip to the next character in the file and reset the State Machine offset to 0
  * If the character is >57 then it's not a number, process it using the State Machine
  * The character is a digit:
    * Set the Last Digit to the value of the digit
    * If the First Digit is undefined (128), then:
        * Set the First Digit to the value of the digit
        * Multiply the First Digit by 10
        * Add the First Digit to the cumulative answer
    * Skip to the next character in the file and reset the State Machine offset to 0
### State Machine Processing
* Read the three bytes at the current State Machine offset:
  * Byte 0 = Test Character
  * Byte 1 = Next State
  * Byte 2 = Value to Emit
* If Test Character is NUL (0), then:
  * Skip to the next character in the file and reset the State Machine offset to 0
* If Test Character matches the character read from the file, then:
  * Set the State Machine offset to (Next State * 3)
  * If Value to Emit == 0xFF (255) then:
    * Skip to the next character
    * DON'T reset the State Machine offset
  * Otherwise:
    * Set the Last Digit to the Value to Emit
    * If the First Digit is undefined (128), then:
        * Set the First Digit to the Value to Emit
        * Multiply the First Digit by 10
        * Add the First Digit to the cumulative answer
    * Skip to the next character in the file
    * DON'T reset the State Machine offset
* Otherwise, add 3 to the State Machine offset, and re-run the State Machine against the same file character

---

## State Machine Full Detail
| _State Machine Offset_ | _State_ | Test Char (O) | Next State (O+1) | Value to Emit (O+2) | _Notes_ |
|-|-|-|-|-|-|
|0|0|`0x7A` ('`z`')|8|`0xFF`| `z` - start of possible `zero`|
|3|1|`0x6F` ('`o`')|16|`0xFF`| `o` - start of possible `one`|
|6|2|`0x74` ('`t`')|24|`0xFF`| `t` - start of possible `two` or `three`|
|9|3|`0x66` ('`f`')|34|`0xFF`| `f` - start of possible `four` or `five`|
|12|4|`0x73` ('`s`')|43|`0xFF`| `s` - start of possible `six` or `seven`|
|15|5|`0x65` ('`e`')|52|`0xFF`| `e` - start of possible `eight`|
|18|6|`0x6E` ('`n`')|61|`0xFF`| `n` - start of possible `nine`|
|21|7|`0x0` (`NUL`)|0|`0xFF`| No valid matches, reset to offset `0`|
|24|8|`0x65` ('`e`')|70|`0xFF`| `ze` - start of possible `zero`|
|27|9|`0x7A` ('`z`')|8|`0xFF`| |
|30|10|`0x6F` ('`o`')|16|`0xFF`| |
|33|11|`0x74` ('`t`')|24|`0xFF`| |
|36|12|`0x66` ('`f`')|34|`0xFF`| |
|39|13|`0x73` ('`s`')|43|`0xFF`| |
|42|14|`0x6E` ('`n`')|61|`0xFF`| |
|45|15|`0x0` (`NUL`)|0|`0xFF`| No valid matches, reset to offset `0`|
|48|16|`0x6E` ('`n`')|80|`0xFF`| `on` - start of possible `one` |
|51|17|`0x7A` ('`z`')|8|`0xFF`| |
|54|18|`0x6F` ('`o`')|16|`0xFF`| |
|57|19|`0x74` ('`t`')|24|`0xFF`| |
|60|20|`0x66` ('`f`')|34|`0xFF`| |
|63|21|`0x73` ('`s`')|43|`0xFF`| |
|66|22|`0x65` ('`e`')|52|`0xFF`| |
|69|23|`0x0` (`NUL`)|0|`0xFF`| No valid matches, reset to offset `0`|
|72|24|`0x77` ('`w`')|89|`0xFF`| `tw` - start of possible `two`|
|75|25|`0x68` ('`h`')|97|`0xFF`| `th` - start of possible `three`|
|78|26|`0x7A` ('`z`')|8|`0xFF`| |
|81|27|`0x6F` ('`o`')|16|`0xFF`| |
|84|28|`0x74` ('`t`')|24|`0xFF`| |
|87|29|`0x66` ('`f`')|34|`0xFF`| |
|90|30|`0x73` ('`s`')|43|`0xFF`| |
|93|31|`0x65` ('`e`')|52|`0xFF`| |
|96|32|`0x6E` ('`n`')|61|`0xFF`| |
|99|33|`0x0` (`NUL`)|0|`0xFF`| No valid matches, reset to offset `0`|
|102|34|`0x6F` ('`o`')|106|`0xFF`| `fo` - start of possible `four`|
|105|35|`0x69` ('`i`')|115|`0xFF`| `fi` - start of possible `five`|
|108|36|`0x7A` ('`z`')|8|`0xFF`| |
|111|37|`0x74` ('`t`')|24|`0xFF`| |
|114|38|`0x66` ('`f`')|34|`0xFF`| |
|117|39|`0x73` ('`s`')|43|`0xFF`| |
|120|40|`0x65` ('`e`')|52|`0xFF`| |
|123|41|`0x6E` ('`n`')|61|`0xFF`| |
|126|42|`0x0` (`NUL`)|0|`0xFF`| No valid matches, reset to offset `0`|
|129|43|`0x69` ('`i`')|124|`0xFF`| `si` - start of possible `six`|
|132|44|`0x65` ('`e`')|133|`0xFF`| `se` - start of possible `seven`|
|135|45|`0x7A` ('`z`')|8|`0xFF`| |
|138|46|`0x6F` ('`o`')|16|`0xFF`| |
|141|47|`0x74` ('`t`')|24|`0xFF`| |
|144|48|`0x66` ('`f`')|34|`0xFF`| |
|147|49|`0x73` ('`s`')|43|`0xFF`| |
|150|50|`0x6E` ('`n`')|61|`0xFF`| |
|153|51|`0x0` (`NUL`)|0|`0xFF`| No valid matches, reset to offset `0`|
|156|52|`0x69` ('`i`')|143|`0xFF`| `ei` - start of possible `eight`|
|159|53|`0x7A` ('`z`')|8|`0xFF`| |
|162|54|`0x6F` ('`o`')|16|`0xFF`| |
|165|55|`0x74` ('`t`')|24|`0xFF`| |
|168|56|`0x66` ('`f`')|34|`0xFF`| |
|171|57|`0x73` ('`s`')|43|`0xFF`| |
|174|58|`0x65` ('`e`')|52|`0xFF`| |
|177|59|`0x6E` ('`n`')|61|`0xFF`| |
|180|60|`0x0` (`NUL`)|0|`0xFF`| No valid matches, reset to offset `0`|
|183|61|`0x69` ('`i`')|152|`0xFF`| `ni` - start of possible `nine`|
|186|62|`0x7A` ('`z`')|8|`0xFF`| |
|189|63|`0x6F` ('`o`')|16|`0xFF`| |
|192|64|`0x74` ('`t`')|24|`0xFF`| |
|195|65|`0x66` ('`f`')|34|`0xFF`| |
|198|66|`0x73` ('`s`')|43|`0xFF`| |
|201|67|`0x65` ('`e`')|52|`0xFF`| |
|204|68|`0x6E` ('`n`')|61|`0xFF`| |
|207|69|`0x0` (`NUL`)|0|`0xFF`| No valid matches, reset to offset `0`|
|210|70|`0x72` ('`r`')|160|`0xFF`| `zer` - start of possible `zero`|
|213|71|`0x69` ('`i`')|143|`0xFF`| `ei` - start of possible `eight`|
|216|72|`0x7A` ('`z`')|8|`0xFF`| |
|219|73|`0x6F` ('`o`')|16|`0xFF`| |
|222|74|`0x74` ('`t`')|24|`0xFF`| |
|225|75|`0x66` ('`f`')|34|`0xFF`| |
|228|76|`0x73` ('`s`')|43|`0xFF`| |
|231|77|`0x65` ('`e`')|52|`0xFF`| |
|234|78|`0x6E` ('`n`')|61|`0xFF`| |
|237|79|`0x0` (`NUL`)|0|`0xFF`| No valid matches, reset to offset `0`|
|240|80|`0x65` ('`e`')|52|`0x1`| `one` - emit value `1`<br>`e` - start of possible `eight`|
|243|81|`0x69` ('`i`')|152|`0xFF`| `ni` - start of possible `nine`|
|246|82|`0x7A` ('`z`')|8|`0xFF`| |
|249|83|`0x6F` ('`o`')|16|`0xFF`| |
|252|84|`0x74` ('`t`')|24|`0xFF`| |
|255|85|`0x66` ('`f`')|34|`0xFF`| |
|258|86|`0x73` ('`s`')|43|`0xFF`| |
|261|87|`0x6E` ('`n`')|61|`0xFF`| |
|264|88|`0x0` (`NUL`)|0|`0xFF`| No valid matches, reset to offset `0`|
|267|89|`0x6F` ('`o`')|16|`0x2`| `two` - emit value `2`<br>`o` - start of possible `one`|
|270|90|`0x7A` ('`z`')|8|`0xFF`| |
|273|91|`0x74` ('`t`')|24|`0xFF`| |
|276|92|`0x66` ('`f`')|34|`0xFF`| |
|279|93|`0x73` ('`s`')|43|`0xFF`| |
|282|94|`0x65` ('`e`')|52|`0xFF`| |
|285|95|`0x6E` ('`n`')|61|`0xFF`| |
|288|96|`0x0` (`NUL`)|0|`0xFF`| No valid matches, reset to offset `0`|
|291|97|`0x72` ('`r`')|168|`0xFF`| `thr` - start of possible `three`|
|294|98|`0x7A` ('`z`')|8|`0xFF`| |
|297|99|`0x6F` ('`o`')|16|`0xFF`| |
|300|100|`0x74` ('`t`')|24|`0xFF`| |
|303|101|`0x66` ('`f`')|34|`0xFF`| |
|306|102|`0x73` ('`s`')|43|`0xFF`| |
|309|103|`0x65` ('`e`')|52|`0xFF`| |
|312|104|`0x6E` ('`n`')|61|`0xFF`| |
|315|105|`0x0` (`NUL`)|0|`0xFF`| No valid matches, reset to offset `0`|
|318|106|`0x75` ('`u`')|176|`0xFF`| `fou` - start of possible `four`|
|321|107|`0x6E` ('`n`')|80|`0xFF`| `on` - start of possible `one`|
|324|108|`0x7A` ('`z`')|8|`0xFF`| |
|327|109|`0x6F` ('`o`')|16|`0xFF`| |
|330|110|`0x74` ('`t`')|24|`0xFF`| |
|333|111|`0x66` ('`f`')|34|`0xFF`| |
|336|112|`0x73` ('`s`')|43|`0xFF`| |
|339|113|`0x65` ('`e`')|52|`0xFF`| |
|342|114|`0x0` (`NUL`)|0|`0xFF`| No valid matches, reset to offset `0`|
|345|115|`0x76` ('`v`')|185|`0xFF`| `fiv` - start of possible `five`|
|348|116|`0x7A` ('`z`')|8|`0xFF`| |
|351|117|`0x6F` ('`o`')|16|`0xFF`| |
|354|118|`0x74` ('`t`')|24|`0xFF`| |
|357|119|`0x66` ('`f`')|34|`0xFF`| |
|360|120|`0x73` ('`s`')|43|`0xFF`| |
|363|121|`0x65` ('`e`')|52|`0xFF`| |
|366|122|`0x6E` ('`n`')|61|`0xFF`| |
|369|123|`0x0` (`NUL`)|0|`0xFF`| No valid matches, reset to offset `0`|
|372|124|`0x78` ('`x`')|0|`0x6`| `six` - emit value `6`<br>Reset to offset `0`|
|375|125|`0x7A` ('`z`')|8|`0xFF`| |
|378|126|`0x6F` ('`o`')|16|`0xFF`| |
|381|127|`0x74` ('`t`')|24|`0xFF`| |
|384|128|`0x66` ('`f`')|34|`0xFF`| |
|387|129|`0x73` ('`s`')|43|`0xFF`| |
|390|130|`0x65` ('`e`')|52|`0xFF`| |
|393|131|`0x6E` ('`n`')|61|`0xFF`| |
|396|132|`0x0` (`NUL`)|0|`0xFF`| No valid matches, reset to offset `0`|
|399|133|`0x76` ('`v`')|193|`0xFF`| `sev` - start of possible `seven`|
|402|134|`0x69` ('`i`')|143|`0xFF`| `ei` - start of possible `eight`|
|405|135|`0x7A` ('`z`')|8|`0xFF`| |
|408|136|`0x6F` ('`o`')|16|`0xFF`| |
|411|137|`0x74` ('`t`')|24|`0xFF`| |
|414|138|`0x66` ('`f`')|34|`0xFF`| |
|417|139|`0x73` ('`s`')|43|`0xFF`| |
|420|140|`0x65` ('`e`')|52|`0xFF`| |
|423|141|`0x6E` ('`n`')|61|`0xFF`| |
|426|142|`0x0` (`NUL`)|0|`0xFF`| No valid matches, reset to offset `0`|
|429|143|`0x67` ('`g`')|201|`0xFF`| `eig` - start of possible `eight`|
|432|144|`0x7A` ('`z`')|8|`0xFF`| |
|435|145|`0x6F` ('`o`')|16|`0xFF`| |
|438|146|`0x74` ('`t`')|24|`0xFF`| |
|441|147|`0x66` ('`f`')|34|`0xFF`| |
|444|148|`0x73` ('`s`')|43|`0xFF`| |
|447|149|`0x65` ('`e`')|52|`0xFF`| |
|450|150|`0x6E` ('`n`')|61|`0xFF`| |
|453|151|`0x0` (`NUL`)|0|`0xFF`| No valid matches, reset to offset `0`|
|456|152|`0x6E` ('`n`')|210|`0xFF`| `nin` - start of possible `nine`|
|459|153|`0x7A` ('`z`')|8|`0xFF`| |
|462|154|`0x6F` ('`o`')|16|`0xFF`| |
|465|155|`0x74` ('`t`')|24|`0xFF`| |
|468|156|`0x66` ('`f`')|34|`0xFF`| |
|471|157|`0x73` ('`s`')|43|`0xFF`| |
|474|158|`0x65` ('`e`')|52|`0xFF`| |
|477|159|`0x0` (`NUL`)|0|`0xFF`| No valid matches, reset to offset `0`|
|480|160|`0x6F` ('`o`')|16|`0x0`| `zero` - emit value `0`<br>`o` - start of possible `one`|
|483|161|`0x7A` ('`z`')|8|`0xFF`| |
|486|162|`0x74` ('`t`')|24|`0xFF`| |
|489|163|`0x66` ('`f`')|34|`0xFF`| |
|492|164|`0x73` ('`s`')|43|`0xFF`| |
|495|165|`0x65` ('`e`')|52|`0xFF`| |
|498|166|`0x6E` ('`n`')|61|`0xFF`| |
|501|167|`0x0` (`NUL`)|0|`0xFF`| No valid matches, reset to offset `0`|
|504|168|`0x65` ('`e`')|219|`0xFF`| `thre` - start of possible `three`|
|507|169|`0x7A` ('`z`')|8|`0xFF`| |
|510|170|`0x6F` ('`o`')|16|`0xFF`| |
|513|171|`0x74` ('`t`')|24|`0xFF`| |
|516|172|`0x66` ('`f`')|34|`0xFF`| |
|519|173|`0x73` ('`s`')|43|`0xFF`| |
|522|174|`0x6E` ('`n`')|61|`0xFF`| |
|525|175|`0x0` (`NUL`)|0|`0xFF`| No valid matches, reset to offset `0`|
|528|176|`0x72` ('`r`')|0|`0x4`| `four` - emit value `4`<br>Reset to offset `0`|
|531|177|`0x7A` ('`z`')|8|`0xFF`| |
|534|178|`0x6F` ('`o`')|16|`0xFF`| |
|537|179|`0x74` ('`t`')|24|`0xFF`| |
|540|180|`0x66` ('`f`')|34|`0xFF`| |
|543|181|`0x73` ('`s`')|43|`0xFF`| |
|546|182|`0x65` ('`e`')|52|`0xFF`| |
|549|183|`0x6E` ('`n`')|61|`0xFF`| |
|552|184|`0x0` (`NUL`)|0|`0xFF`| No valid matches, reset to offset `0`|
|555|185|`0x65` ('`e`')|52|`0x5`| `five` - emit value `5`<br>Reset to offset `0`|
|558|186|`0x7A` ('`z`')|8|`0xFF`| |
|561|187|`0x6F` ('`o`')|16|`0xFF`| |
|564|188|`0x74` ('`t`')|24|`0xFF`| |
|567|189|`0x66` ('`f`')|34|`0xFF`| |
|570|190|`0x73` ('`s`')|43|`0xFF`| |
|573|191|`0x6E` ('`n`')|61|`0xFF`| |
|576|192|`0x0` (`NUL`)|0|`0xFF`| No valid matches, reset to offset `0`|
|579|193|`0x65` ('`e`')|228|`0xFF`| `seve` - start of possible `seven`|
|582|194|`0x7A` ('`z`')|8|`0xFF`| |
|585|195|`0x6F` ('`o`')|16|`0xFF`| |
|588|196|`0x74` ('`t`')|24|`0xFF`| |
|591|197|`0x66` ('`f`')|34|`0xFF`| |
|594|198|`0x73` ('`s`')|43|`0xFF`| |
|597|199|`0x6E` ('`n`')|61|`0xFF`| |
|600|200|`0x0` (`NUL`)|0|`0xFF`| No valid matches, reset to offset `0`|
|603|201|`0x68` ('`h`')|237|`0xFF`| `eigh` - start of possible `eight`|
|606|202|`0x7A` ('`z`')|8|`0xFF`| |
|609|203|`0x6F` ('`o`')|16|`0xFF`| |
|612|204|`0x74` ('`t`')|24|`0xFF`| |
|615|205|`0x66` ('`f`')|34|`0xFF`| |
|618|206|`0x73` ('`s`')|43|`0xFF`| |
|621|207|`0x65` ('`e`')|52|`0xFF`| |
|624|208|`0x6E` ('`n`')|61|`0xFF`| |
|627|209|`0x0` (`NUL`)|0|`0xFF`| No valid matches, reset to offset `0`|
|630|210|`0x65` ('`e`')|52|`0x9`| `nine` - emit value `9`<br>`e` - start of possible `eight`|
|633|211|`0x69` ('`i`')|152|`0xFF`| `ni` - start of possible `nine`|
|636|212|`0x7A` ('`z`')|8|`0xFF`| |
|639|213|`0x6F` ('`o`')|16|`0xFF`| |
|642|214|`0x74` ('`t`')|24|`0xFF`| |
|645|215|`0x66` ('`f`')|34|`0xFF`| |
|648|216|`0x73` ('`s`')|43|`0xFF`| |
|651|217|`0x6E` ('`n`')|61|`0xFF`| |
|654|218|`0x0` (`NUL`)|0|`0xFF`| No valid matches, reset to offset `0`|
|657|219|`0x65` ('`e`')|52|`0x3`| `three` - emit value `3`<br>`e` - start of possible `eight`|
|660|220|`0x69` ('`i`')|143|`0xFF`| `ei` - start of possible `eight`|
|663|221|`0x7A` ('`z`')|8|`0xFF`| |
|666|222|`0x6F` ('`o`')|16|`0xFF`| |
|669|223|`0x74` ('`t`')|24|`0xFF`| |
|672|224|`0x66` ('`f`')|34|`0xFF`| |
|675|225|`0x73` ('`s`')|43|`0xFF`| |
|678|226|`0x6E` ('`n`')|61|`0xFF`| |
|681|227|`0x0` (`NUL`)|0|`0xFF`| No valid matches, reset to offset `0`|
|684|228|`0x6E` ('`n`')|61|`0x7`| `seven` - emit value `7`<br>`n` - start of possible `nine`|
|687|229|`0x69` ('`i`')|143|`0xFF`| `ei` - start of possible `eight`|
|690|230|`0x7A` ('`z`')|8|`0xFF`| |
|693|231|`0x6F` ('`o`')|16|`0xFF`| |
|696|232|`0x74` ('`t`')|24|`0xFF`| |
|699|233|`0x66` ('`f`')|34|`0xFF`| |
|702|234|`0x73` ('`s`')|43|`0xFF`| |
|705|235|`0x65` ('`e`')|52|`0xFF`| |
|708|236|`0x0` (`NUL`)|0|`0xFF`| No valid matches, reset to offset `0`|
|711|237|`0x74` ('`t`')|24|`0x8`| `eight` - emit value `8`<br>`t` - start of possible `two` or `three`|
|714|238|`0x7A` ('`z`')|8|`0xFF`| |
|717|239|`0x6F` ('`o`')|16|`0xFF`| |
|720|240|`0x66` ('`f`')|34|`0xFF`| |
|723|241|`0x73` ('`s`')|43|`0xFF`| |
|726|242|`0x65` ('`e`')|52|`0xFF`| |
|729|243|`0x6E` ('`n`')|61|`0xFF`| |
|732|244|`0x0` (`NUL`)|0|`0xFF`| No valid matches, reset to offset `0`|
