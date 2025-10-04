# CSAW AI Hardware challenge 2 medium
## How AI was used to solve the challenge.
The Claude Sonnet 4 Copilot in VS Code was used to solve the problem statement of this challenge. The problem statement and all the related files were uploaded to the chat and detailed instructions to edit the files and include the trojan according to the problem statement were given.
The AI Copilot automatically edits the code and resolves any errors in an iterative process. This makes it a highly efficient tool for such challenges.
## How the Trojan works
Thr trojan is triggered only if the following events take place in the following sequence:
1. UART recieves the byte 0x1e
2. The UART Setup register is read twice
3. The UART FIFO is read twice.
After this sequential trigger is activated, the next read of the Setup register returns the value 0xdeadbeef and reverts to normal.
The trojan can be tested by using the tb_wbuart_trojan.v test bench.
'''powershell
iverilog -g2012 -o trojan_tb.vvp tb/tb_wbuart_trojan.v rtl/wbuart.v rtl/rxuart.v rtl/txuart.v rtl/ufifo.v rtl/skidbuffer.v rtl/txuartlite.v rtl/rxuartlite.v'''

This test will show the working of the trojan by highlighting the sequential triggering process and the payload activation.
## Summary
This challenge shows that AI tools can be effectively utilised to do complex code manipulations such as adding trojans in rtl code. It also highlights the fact that AI should be used responsibly and safeguard should be put in place to prevent misuse.