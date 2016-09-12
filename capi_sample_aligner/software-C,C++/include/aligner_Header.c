/*
 * Author: Ilir Likalla
 */
 

#include <linux/types.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <math.h>
#include "aligner_Header.h"

void charTo2bit(char *seqchar, __u8 *seq2bit) // encodes bases from ASCII into 2-bit representation
{
	// check for valid arguments:
	if(seqchar == NULL || seq2bit == NULL)
	{
		printf("charTo2bit: Invalid argumets!\n");
		return;
	}
	int i= 0, j;
	int len= strlen(seqchar); // get length of sequence
    
	while(i< len && (i< (SEQ_LENGTH*4)))
	{
		j=i/4;
    #ifdef _DEBUGGING_
		if(i==0) printf("============= charTo2bit:===========\n\n");
		printf("i: %d, base: %c, pos: %d valb: %02x ",i,toupper(seqchar[i]),((i*2)%8),seq2bit[j]);
    #endif
		switch(seqchar[i])
		{
			case 'a': case'A': seq2bit[j] |= 0b10<<((i*2)%8); break; // 'A'= 0b10;
			case 'c': case'C': seq2bit[j] |= 0b01<<((i*2)%8); break; // 'C'= 0b01;
			case 'g': case'G': seq2bit[j] |= 0b11<<((i*2)%8); break; // 'G'= 0b11;
			case 't': case'T': seq2bit[j] |= 0b00<<((i*2)%8); break; // 'T'= 0b00;
			default:
				seq2bit[j] |= 0b00<<((i*2)%8); break; // treat 'N' bases as 'A';
		}
    #ifdef _DEBUGGING_
		printf("vala: %02x\n",seq2bit[j]);
    #endif
		i++;
	}
	
}
