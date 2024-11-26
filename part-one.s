.global _start

.section .data
usage:
    .asciz    "Usage: part-one filename\n"
    usage_len = (. - usage)
file_path_too_long:
    .asciz    "File path too long (>255 chars)\n"
    file_path_too_long_len = (. - file_path_too_long)
could_not_access_file:
    .asciz    "Could not access file\n"
    could_not_access_file_len = (. - could_not_access_file)
answer:
    .asciz    "Answer: "
    answer_len = (. - answer)

.section .text
_start:
    # Record initial stack pointer as base pointer
        movq %rsp, %rbp

    # Check argc == 2 or show usage and quit
        movq (%rbp), %rax
        cmp $2, %rax
        jne show_usage
    
    # Allocate stack buffer for input file path
        sub $256, %rsp
    
    # Read CWD into input file path stack buffer
        movq %rsp, %rdi # Buffer Address
        movq $256, %rsi # Buffer Length
        movq $79, %rax # Syscall type: sys_getcwd
        syscall # Execute syscall
        movq %rax, %r13 # Length of file path

    # Read argv[1] (filename relative to CWD) and get length of filename 
        leaq 16(%rbp), %rax # Pointer to address of filename string
        movq (%rax), %r12 # Address of filename string
        movq %r12, %r14 # Address of current byte

    # Process filename byte
    next_filename_char:
        inc %r14 # Increment current byte pointer
        movb -1(%r14), %sil # Read current byte
        
        # If current byte <> 0, process next byte 
        or %sil, %sil
        jnz next_filename_char

    # Otherwise subtract start address from current byte address to get length
        sub %r12, %r14

    # If combined CWD plus filename > 256 (stack buffer size), output error and quit
        movq %r13, %r11
        add %r14, %r11
        and $0xffffffffffffff00, %r11
        jnz show_file_path_too_long

    # Concatenate CWD, '/', and filename in stack buffer
        leaq -256(%rbp), %r11 # Pointer to stack buffer
        add %r13, %r11 # Shift pointer to end of CWD
        movb $'/', -1(%r11) # Concatenate '/' to end of CWD (over the top of existing \0)
        movq %r12, %rsi # Set base address to copy filename from
        movq %r11, %rdi # Target address to copy to - stack buffer immediately after '/'
        cld # Ensure we're going forwards
        movq %r14, %rcx # Number of bytes to copy (length of filename including terminating \0)
        rep movsb # Execute copy

    # Get File Size
        sub $144, %rsp # Make space for stat struct on stack
        leaq -256(%rbp), %rdi # File path address
        movq %rsp, %rsi # Stat struct address
        movq $4, %rax # Syscall type: sys_stat
        syscall # Execute syscall
        
        # If syscall return code != 0, output error and quit
        test %rax, %rax
        jnz file_error

        add $144, %rsp # Reset stack pointer
        movq -96(%rsp), %r15 # File Size

    # Open File
        # RDI - File path address - as above
        movq $0, %rsi # Read-Only
        movq $0, %rdx # (ignored for Read-Only files)
        movq $2, %rax # Syscall type: sys_open
        syscall # Execute syscall
        # TODO - Check RAX is a valid File Descriptor
        movq %rax, %r8 # File Descriptor

    # Map file into memory
        movq $0, %rdi # No Address Hint
        movq %r15, %rsi # Buffer Size (File Size)
        movq $1, %rdx # PROT_READ
        movq $2, %r10 # MAP_PRIVATE
        movq $0, %r9  # File Offset - Start
        # R8 - File Descriptor from above
        movq $9, %rax # Syscall type: sys_mmap
        syscall # Execute syscall
        # TODO - Check RAX is a valid address
        movq %rax, %r9 # Address of first byte

    add %r9, %r15 # Address of last byte + 1
    movq $0, %rsi # Clear down RSI
    movq $128, %r10 # Initialise first digit as Undefined (128)
    movq $128, %r11 # Initialise second digit as Undefined (128)
    movq $0, %r12 # Initialise result

    # Process current byte
    proc_nextchar:
        # If current byte = last byte + 1, then finish processing
        cmp %r9, %r15
        je proc_done

        movb (%r9), %sil # Read current byte (a read into SIL is a 1 byte read into RSI)
        inc %r9 # Increment current byte pointer

        # If current byte value is greater than ASCII value corresponding to '9', skip to next byte
        cmp $57, %rsi
        jg proc_nextchar

        # If current byte value is equal to \n then complete end-of-line processing
        cmp $0x0A, %rsi 
        jz proc_nextline

        # If current byte value is less than ASCII value corresponding to '0', skip to next byte
        cmp $48, %rsi
        jl proc_nextchar

        sub $48, %rsi # Shift the ASCII value of '0' thru '9' to the numeric value
        movq %rsi, %r11 # Set the Second Digit to the numeric value

        # If the First Digit is NOT Undefined (128), skip to processing next byte
        cmp $128, %r10
        jne proc_nextchar

        # Otherwise...
        movq %rsi, %r10 # Set the First Digit to the numeric value
        imul $10, %r10, %r10 # And multiply by 10
        add %r10, %r12 # And add the First Digit *10 to the overall result
        jmp proc_nextchar # And then process the next byte

    # End of Line Processing
    proc_nextline:
        add %r11, %r12 # Add the Second Digit to the overall result
        movq $128, %r10 # Reset the First Digit to Undefined (128)
        movq $128, %r11 # Reset the Second Digit to Undefined (128)
        jmp proc_nextchar # And then process the next byte

    # Finished Processing (file doesn't end with \n)
    proc_done:
        # TODO - Check if this next command is necessary - with the files included it isn't
        #        because the file is not terminated with a newline.
        add %r11, %r12 # Add the Second Digit to the overall result

        sub %rax, %r15 # Calculate Length
        movq %rax, %rdi # Location
        movq %r15, %rsi # Length
        movq $11, %rax # Syscall type: sys_munmap
        syscall
        # TODO - Check RAX for errors

        movq %r8, %rdi # File Descriptor
        movq $3, %rax # Syscall type: sys_close
        syscall
        # TODO - Check RAX for errors

        # Output 'Answer: '
            movq $answer, %rsi
            movq $answer_len, %rdx
            call stdout

        # Convert the answer from a number to a string of numbers by repeated division by 10
            movq $1, %r11 # Counter
            movq $10, %r13 # Divisor
            movq %r12, %rax # Quotient

            # Push trailing newline byte onto stack
            movb $'\n', (%rsp)
            dec %rsp

            # Push ASCII value of next most significant digit onto stack
            next_number:
                movq $0, %rdx # Remainder
                idiv %r13 # Divide RAX by 10; Quotient -> RAX; Remainder -> RDX
                add $48, %dl # Lowest byte of RDX, add 48 for ASCII value of number
                # Push ASCII byte onto stack
                    movb %dl, (%rsp) # Push byte onto stack
                    dec %rsp
                inc %r11 # Increment counter
                # If Quotient != 0 process the next most significant digit
                or %rax, %rax
                jnz next_number
        
        # Output string pointer is stack pointer + 1
            movq %rsp, %rsi
            inc %rsi

        # Set string length, and write string to stdout
            movq %r11, %rdx
            call stdout 
        movq $0, %rdi # Exit Code
        jmp exit
    
    # Print Usage and Exit with code 1
    show_usage:
        movq $usage, %rsi
        movq $usage_len, %rdx
        call stderr
        movq $1, %rdi # Exit Code
        jmp exit

    # Print File Path Too Long error and Exit with code 1
    show_file_path_too_long:
        movq $file_path_too_long, %rsi
        movq $file_path_too_long_len, %rdx
        call stderr
        movq $1, %rdi # Exit Code
        jmp exit

    # Print File Access error and Exit with code 1
    file_error:
        movq $could_not_access_file, %rsi
        movq $could_not_access_file_len, %rdx
        call stderr
        movq $1, %rdi # Exit Code
        jmp exit

    # Write string at %rsi, length %rdx, to stdout
    stdout:
        movq $1, %rdi # File Descriptor - stdout
        #rsi = buffer - set before call
        #rdx = length - set before call
        movq $1, %rax # Syscall type: sys_write
        syscall # Execute syscall
        ret
    
    # Write string at %rsi, length %rdx, to stderr
    stderr:
        movq $2, %rdi # File Descriptor - stderr
        #rsi = buffer - set before call
        #rdx = length - set before call
        movq $1, %rax # Syscall type: sys_write
        syscall # Execute syscall
        ret
    
    # Exit with a returncode from %rdi
    exit:
        mov $60, %rax # Syscall type: sys_exit
        syscall # Execute syscall
