# Protocols

In these repo we will design some different protocols, like UART, SPI, I2C, with 
maybe some more advanced protocols will be added.

This document will try and describe the basics of each protocol. So it will
be easier to design them in code later.

## UART

UART (universal asynchronous receiver-transmitter) is one of the most used
device-to-device communication protocols. 

We mostly use UART as a form of device-to-device hardware communication protocol. UART uses only two wires for its transmitting and receiving ends.

UART is a hardware communication protocol that uses asynchronous serial
communication with configurable speed. Asynchronous means there is no clock
signal to synchronize the output bits from the transmitting device going
to the receiving end.

### Interface

The two signals of each UART device are named:
- Transmitter (Tx)
- Receiver (Rx)

For each device the transmitter and receiver will transmit and receive 
serial data intended for serial communication.

The transmitting UART is connected to a controlling data bus that sends data
in a parallel from. From this, the data will now be transmitted on the
transmission line (wire) serially, bit by bit, to the receiving UART.
This, in turn will convert the serial data into parallel for the reveiving
device.

The UART lines serve as the communication medium to transmit and receive one data to another.

For UART (and most serial communications), the baud rate nneds to be set 
the same one both the transmitting and receiving device. The baud rate is
the rate at which information is transferred to a communication channel.

| UART summary| |
|-------|----|
| Wires | 2 |
| Speed | 9600, 19200, 38400, 57600, 115200, 230400, 460800, 921600, 1000000, 1500000 |
| Methods of Transmission | Asynchronous |
| Maximum Number of Masters | 1 |
| Maximum Number of Slaves | 1 |

The UART interface does not use a clock signal to synchronize the transmitter
and receiver devices; it transmits data asynchronously. Instead of a clock
signa, the transmitter generates a bitstream based on its clock signal while the receiver is using its internal clock signal to sample the incoming data. 

## Data Transmission

In UART, the mode of transmission is in the form of a packet. 
A packet consists of a start bit, data frame, a parity bit, and
a stop bits.

```text
+-------+---------------------------------------+--------+----------+
| START |                 DATA                  | PARITY |   STOP   |
+-------+---------------------------------------+--------+----------+
| 1 bit |               5–9 bits                | 0–1 bit| 1–2 bits |
+-------+---------------------------------------+--------+----------+
```

### Start Bit

The UART data transmission line is normally helt at a high voltage level when it's
not transmitting data. To start the transfer of data, the transmitting UART pulls
the transmission line from high to low for one (1) clock cycle. When the 
receiving UART detects the high to low voltage transition, it begins reading the
bits in the data frame at the frequency of the baud rate.

### Data Frame

The data frame contains the actual data being transferred. It can be fire (5) bits up to eight (8) bits long if a parity bit is used. In most cases, the data
is sent with the least significant bit first.

### Parity

The parity bit is a way for the receiving UART to tell if any data has changed 
during transmission. Bits can be changed by electromagnetic radiation,
mismatched baud rates, or long-distance data transfers.

After the receiving UART reads the data frame, it counts the number of bits with
a value of 1 and checks if the total is an even or odd number. If the parity bit
is a 0 (even parity), the 1 or logic-high bit in the data frame should total to
an even number. If the parity bit is a 1 (odd parity), the 1 bit or logic highs
in the data frame should total to and odd number.

When the parity bit matches the data, the UART knows that the transmission was
free of errors. But if the parity bit is a 0, and the total is odd, or the parity
bit is a 1, and the total is even the UART knows that bits in the data frame 
have changed.

### Stop Bits

To signal the end of the data packet, the sending UART drives the data
transmission line from a low voltage to a high voltage of one (1) to two (2) 
bit(s) duration.

## Steps of UART Transmission

1. The transmitting UART receives data in parallel from the data bus.
2. The transmitting UART adds the start bit, parity bit, and the stop bit(s) 
to the data frame.
3. The entire packet is sent serially starting fromstart bit to stop bit from the
transmitting UART to the receiving UART. The receiving UART samples the data line
at the preconfigured baud rate.
4. The receiving UART discards the start bit, parity bit, and stop bit from the
data frame.
5. The receiving UART converts the serial data back into parallel and transfers
it to the data bus on the receiving end.

[link](https://www.analog.com/en/resources/analog-dialogue/articles/uart-a-hardware-communication-protocol.html)

## SPI



## I2C