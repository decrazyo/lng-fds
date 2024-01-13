
;// definitions for the Famicom disk system (FDS) RAM adapter.

#ifndef _FDS_H
#define _FDS_H

;// #define FDS_REG           $4000
;// #define FDS_RAM           $6000
;// #define FDS_BIOS          $e000
;// #define FDS_VECTOR        $dff6
;// #define FDS_VECTOR_CTRL   $0100

;// FDS registers
#define FDS_TIMER_LO        $4020
#define FDS_TIMER_HI        $4021
#define FDS_TIMER_CTRL      $4022
#define FDS_IO_ENABLE       $4023
#define FDS_WRITE_DATA      $4024
#define FDS_CTRL            $4025
#define FDS_WRITE_EXT       $4026
#define FDS_DISK_STATUS     $4030
#define FDS_READ_DATA       $4031
#define FDS_DRIVE_STATUS    $4032
#define FDS_READ_EXT        $4033

;// FDS register bit masks
#define FDS_TIMER_CTRL_E    %00000010 ;// Timer IRQ Enabled
#define FDS_TIMER_CTRL_R    %00000001 ;// Timer IRQ Repeat Flag

#define FDS_IO_ENABLE_S    %00000010 ;// Enable sound I/O registers
#define FDS_IO_ENABLE_D    %00000001 ;// Enable disk I/O registers

#define FDS_CTRL_I    %10000000 ;// Interrupt Enabled (1: Generate an IRQ every time the byte transfer flag is raised)
#define FDS_CTRL_S    %01000000 ;// Transfer Behavior
#define FDS_CTRL_1    %00100000 ;// Always set to '1'
#define FDS_CTRL_B    %00010000 ;// CRC Control (1: transfer CRC values)
#define FDS_CTRL_M    %00001000 ;// Mirroring (0: vertical; 1: horizontal)
#define FDS_CTRL_R    %00000100 ;// Transfer Mode (0: write; 1: read)
#define FDS_CTRL_T    %00000010 ;// Transfer Reset (1: Reset transfer timing to the initial state)
#define FDS_CTRL_D    %00000001 ;// Drive Motor Control (0: stop, 1: start)

#define FDS_DISK_STATUS_I    %10000000 ;// Disk Data Read/Write Enable (1 when disk is readable/writeable)
#define FDS_DISK_STATUS_E    %01000000 ;// End of Head (1 when disk head is on the most inner track)
#define FDS_DISK_STATUS_B    %00010000 ;// CRC control (0: CRC passed; 1: CRC error)
#define FDS_DISK_STATUS_T    %00000010 ;// Byte transfer flag. Set every time 8 bits have been transferred between the RAM adaptor & disk drive (service $4024/$4031). Reset when $4024, $4031, or $4030 has been serviced.
#define FDS_DISK_STATUS_D    %00000001 ;// Timer Interrupt (1: an IRQ occurred)

#define FDS_DRIVE_STATUS_P    %00000100 ;// Protect flag (0: Not write protected; 1: Write protected or disk ejected)
#define FDS_DRIVE_STATUS_R    %00000010 ;// Ready flag (0: Disk readу; 1: Disk not ready)
#define FDS_DRIVE_STATUS_S    %00000001 ;// Disk flag  (0: Disk inserted; 1: Disk not inserted)

#define FDS_READ_EXT_B    %10000000 ;// Battery status (0: Voltage is low; 1: Good).

;// FDS pseudo-interrupt vectors
#define FDS_NMI1    $dff6
#define FDS_NMI2    $dff8
#define FDS_NMI3    $dffa
#define FDS_RESET   $dffc
#define FDS_IRQ     $dffe

;// FDS pseudo-interrupt vectors control
#define FDS_NMI_CTRL      $0100
#define FDS_IRQ_CTRL      $0101
#define FDS_RESET_CTRL    $0102 ;// 2 bytes

;// FDS pseudo-interrupt vectors control bit masks
#define FDS_NMI_CTRL_D    %00000000 ;// BIOS disable NMI
#define FDS_NMI_CTRL_1    %01000000 ;// Disk game NMI vector #1
#define FDS_NMI_CTRL_2    %10000000 ;// Disk game NMI vector #2
#define FDS_NMI_CTRL_3    %11000000 ;// Disk game NMI vector #3

#define FDS_IRQ_CTRL_S    %00000000 ;// BIOS disk skip bytes
#define FDS_IRQ_CTRL_X    %01000000 ;// BIOS disk transfer
#define FDS_IRQ_CTRL_A    %10000000 ;// BIOS acknowledge and delay
#define FDS_IRQ_CTRL_G    %11000000 ;// Disk game IRQ vector

#define FDS_RESET_CTRL_B    $00 ;// BIOS RESET
#define FDS_RESET_CTRL_1    $35 ;// Disk game RESET vector
#define FDS_RESET_CTRL_2    $53 ;// Disk game RESET vector

;// FDS BIOS data addresses
#define fds_write_ext_mirror     $f9
#define fds_ctrl_mirror          $fa
#define fds_joypad1_mirror       $fb
#define fds_ppu_scroll_y_mirror  $fc
#define fds_ppu_scroll_x_mirror  $fd
#define fds_ppu_mask_mirror      $fe
#define fds_ppu_ctrl_mirror      $ff

;// FDS BIOS functions

;// function: fds_delay_ms
;// <  Y = milliseconds to delay
;// changes: X, Y
#define fds_delay_ms $e153

#endif
