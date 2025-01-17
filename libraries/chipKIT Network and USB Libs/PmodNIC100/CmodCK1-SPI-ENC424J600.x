/************************************************************************/
/*																		*/
/*	Uno32-SPI-ENC424J600.x                                              */
/*																		*/
/*	ENC424J600	configuration for the MX3cK                     		*/
/*																		*/
/************************************************************************/
/*	Author: 	Keith Vogel 											*/
/*	Copyright 2011, Digilent Inc.										*/
/************************************************************************/
/*
  This library is free software; you can redistribute it and/or
  modify it under the terms of the GNU Lesser General Public
  License as published by the Free Software Foundation; either
  version 2.1 of the License, or (at your option) any later version.

  This library is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
  Lesser General Public License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with this library; if not, write to the Free Software
  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
*/
/************************************************************************/
/*  Revision History:													*/
/*																		*/
/*	5/2/2012(KeithV): Created											*/
/*																		*/
/************************************************************************/
#ifndef UNO32_SPI_ENC424J600_X
#define UNO32_SPI_ENC424J600_X

// Digilent defined values for the MLA build
#define __Digilent_Build__
#define __PIC32MX1XX__ 

// ENC624J600 Interface Configuration
// Comment out ENC100_INTERFACE_MODE if you don't have an ENC624J600 or 
// ENC424J600.  Otherwise, choose the correct setting for the interface you 
// are using.  Legal values are:
//  - Commented out: No ENC424J600/624J600 present or used.  All other 
//                   ENC100_* macros are ignored.
//	- 0: SPI mode using CS, SCK, SI, and SO pins
//  - 1: 8-bit demultiplexed PSP Mode 1 with RD and WR pins
//  - 2: *8-bit demultiplexed PSP Mode 2 with R/Wbar and EN pins
//  - 3: *16-bit demultiplexed PSP Mode 3 with RD, WRL, and WRH pins
//  - 4: *16-bit demultiplexed PSP Mode 4 with R/Wbar, B0SEL, and B1SEL pins
//  - 5: 8-bit multiplexed PSP Mode 5 with RD and WR pins
//  - 6: *8-bit multiplexed PSP Mode 6 with R/Wbar and EN pins
//  - 9: 16-bit multiplexed PSP Mode 9 with AL, RD, WRL, and WRH pins
//  - 10: *16-bit multiplexed PSP Mode 10 with AL, R/Wbar, B0SEL, and B1SEL 
//        pins
// *IMPORTANT NOTE: DO NOT USE PSP MODE 2, 4, 6, OR 10 ON EXPLORER 16! 
// Attempting to do so will cause bus contention with the LCD module which 
// shares the PMP.  Also, PSP Mode 3 is risky on the Explorer 16 since it 
// can randomly cause bus contention with the 25LC256 EEPROM.
#define ENC100_INTERFACE_MODE			0

// Use connector JC on the Pmod Shield, INT 4, SPI1

#define ENC100_CS_TRIS			(TRISAbits.TRISA0)	
#define ENC100_CS_IO			(LATAbits.LATA0)
#define ENC100_ISR_ENABLE		(IEC0bits.INT4IE)
#define ENC100_ISR_FLAG			(IFS0bits.INT4IF)
#define ENC100_ISR_POLARITY		(INTCONbits.INT4EP)
#define ENC100_ISR_PRIORITY		(IPC2bits.INT4IP)
#define ENC100_SPI_ENABLE		(ENC100_SPICON1bits.ON)
#define ENC100_SPI_IF			(IFS0bits.SPI1RXIF)
#define ENC100_SSPBUF			(SPI1BUF)
#define ENC100_SPICON1			(SPI1CON)
#define ENC100_SPISTATbits		(SPI1STATbits)
#define ENC100_SPICON1bits		(SPI1CONbits)
#define ENC100_SPIBRG			(SPI1BRG)

static inline void __attribute__((always_inline)) DNETcKInitNetworkHardware(void)
{
	unsigned int dma_status;
	unsigned int int_status;
	
	mSYSTEMUnlock(int_status, dma_status);

    // clear my WiFi bits to make them digital
    ANSELACLR   = 0b0000000000000011;
    ANSELBCLR   = 0b0100000000000110;

    // set up the PPS
    RPB2R = 3;      // SDO1
    SDI1R = 6;      // SDI1          
    INT4R = 2;      // ~INT4

    mSYSTEMLock(int_status, dma_status);	

    // INT4 as input
    TRISBbits.TRISB4        = 1;

    // Enable the ENC100
    ENC100_CS_IO            = 1;
    ENC100_CS_TRIS          = 0;
}

#endif // UNO32_SPI_ENC424J600_X

