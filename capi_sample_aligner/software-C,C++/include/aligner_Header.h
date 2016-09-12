/*
 * Author: Ilir Likalla
 */
 
#ifndef _ALIGNER_HEADER_H_
#define _ALIGNER_HEADER_H_

#include <linux/types.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <math.h>

#define _DEBUGGING_

#define SEQ_LENGTH 58	// number of bases per sequence
// #define SEQ8to2(x) // find the length 

typedef struct S_E_Q
{
	__u32 ID : 32; // sequence ID
	__u16 length : 16; // sequence length 
	__u8 data[SEQ_LENGTH]; // holds at max 232 bases in 2-bit encoding
} sequence_t; // 512 bits in total


struct seq_WED{
  __u16 endian;			// Always = 1
  __u16 volatile status;	// Status bits
  __u16 volatile major;		// Logic version major #
  __u16 volatile minor;		// Logic version minor #;
  __u8 *sequences;			// sequence array address
  __u8 *result;			// result
  __u64 size;			// size of sequences
  struct seq_WED *__next;		// Next WED struct
  __u64 error;			// Error bits
  // Reserve entire 128 byte cacheline for WED
  __u64 reserved01;
  __u64 reserved02;
  __u64 reserved03;
  __u64 reserved04;
  __u64 reserved05;
  __u64 reserved06;
  __u64 reserved07;
  __u64 reserved08;
  __u64 reserved09;
  __u64 reserved10;
} ;

void charTo2bit(char *seqchar, __u8 *seq2bit); // encodes bases from ASCII into 2-bit representation
//int read_sequences(FILE *f, 


#endif
