/*
 * Author: Ilir Likalla
 */

#include <errno.h>
#include <getopt.h>
#include <linux/types.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <math.h>
#include "libcxl.h"

#define DEVICE "/dev/cxl/afu0.0d"
//#define DEVICE "afu0.0"
#define CACHELINE_BYTES 128
#define AFU_MMIO_REG_SIZE 0x4000000
#define MMIO_STAT_CTL_REG_ADDR 0x0000000
#define MMIO_TRACE_ADDR   0x3FFFFF8   // is shifted right by 2 in 'ha_mmad' (ilir)

// =========================== Interventions =========================
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

void charTo2bit(char *seqchar, __u8 *seq2bit) // encodes bases from ASCII into 2-bit representation
{
	
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
// =========================== End of Interventions ==================
static int verbose;
static unsigned int buffer_cl = 64;
static unsigned int timeout = 1;

static void print_help (char *name)
{
  printf ("\nUSAGE: %s query target1 ... target(n)\n", name);
  // printf ("\t--cachelines\tCachelines to copy.  Default=%d\n", buffer_cl);
  // printf ("\t--timeout   \tDefault=%d seconds\n", timeout);
  // printf ("\t--verbose   \tVerbose output\n");
  printf ("\t--help      \tPrint this message\n");
  printf ("\n");
}

static int alloc_test (const char *msg, __u64 addr, int ret)
{
  if (ret==EINVAL) {
    fprintf (stderr, "Memory alloc failed for %s, ", msg);
    fprintf (stderr, "memory size not a power of 2\n");
    return -1;
  }
  else if (ret==ENOMEM) {
    fprintf (stderr, "Memory alloc failed for %s, ", msg);
    fprintf (stderr, "insufficient memory available\n");
    return -1;
  }

  if (verbose) {
    printf ("Allocated memory at 0x%016llx:%s\n", (long long) addr,
      msg);
  }
  return 0;
}
 
void check_errors (struct seq_WED *wed0)
{
  if (wed0->error) {
    if (wed0->error & 0x8000ull)
      printf ("AFU detected job code parity error\n");
    if (wed0->error & 0x4000ull)
      printf ("AFU detected job address parity error\n");
    if (wed0->error & 0x2000ull)
      printf ("AFU detected MMIO address parity error\n");
    if (wed0->error & 0x1000ull)
      printf ("AFU detected MMIO write data parity error\n");
    if (wed0->error & 0x0800ull)
      printf ("AFU detected buffer write parity error\n");
    if (wed0->error & 0x0400ull)
      printf ("AFU detected buffer read tag parity error\n");
    if (wed0->error & 0x0200ull)
      printf ("AFU detected buffer write tag parity error\n");
    if (wed0->error & 0x0100ull)
      printf ("AFU detected response tag parity error\n");
    if (wed0->error & 0x0080ull)
      printf ("AFU received AERROR response\n");
    if (wed0->error & 0x0040ull)
      printf ("AFU received DERROR response\n");
    if (wed0->error & 0x0020ull)
      printf ("AFU received NLOCK response\n");
    if (wed0->error & 0x0010ull)
      printf ("AFU received NRES response\n");
    if (wed0->error & 0x0008ull)
      printf ("AFU received FAULT response\n");
    if (wed0->error & 0x0004ull)
      printf ("AFU received FAILED response\n");
    if (wed0->error & 0x0002ull)
      printf ("AFU received CONTEXT response\n");
    if (wed0->error & 0x0001ull)
      printf ("AFU detected unsupported job code\n");
  }
}

void dump_trace (struct cxl_afu_h *afu_h,int command_lines, int response_lines, int control_lines)
{
  uint64_t trace_id, last_time, trace_time;
  uint64_t tdata0, tdata1, tdata2;
  int rc;
  int command_lines_outstanding = command_lines;
  int response_lines_outstanding = response_lines;
  int control_lines_outstanding = control_lines;
  // trace_id = 0x8000C00000000000ull;
  trace_id = 0x8000C00000000000;//rblack changing this line

  last_time = 0;
  printf ("Command events:\n");
  cxl_mmio_write64 (afu_h, MMIO_TRACE_ADDR, trace_id);
  rc = cxl_mmio_read64 (afu_h, MMIO_TRACE_ADDR, &tdata0);
  if ( rc != 0 ) {
    printf ( "mmio error: %d \n", rc );
  }
  rc = cxl_mmio_read64 (afu_h, MMIO_TRACE_ADDR, &tdata1);
  rc = cxl_mmio_read64 (afu_h, MMIO_TRACE_ADDR, &tdata2);
  command_lines_outstanding = command_lines_outstanding - 1;
  printf ("0x%016llx:0x%016llx:0x%016llx\n", (long long) tdata0, (long long) tdata1, (long long) tdata2);
  trace_time = (tdata0 >> 24) & 0xffffffffffull;
  printf ("0x%010llx:", (long long) trace_time);
  while (command_lines_outstanding != 0) {
    if (tdata0 & 0x0000000000800000ull) {
      printf (" Tag:0x%02x,%d Command:0x%04x,%d Addr:0x%016llx,%d abt:%d cch:0x%x size:%d\n",
              (unsigned) ((tdata0 >> 15) & 0xffull),
              (int) ((tdata0 >> 14) & 0x1ull),
              (unsigned) ((tdata0 >> 1) & 0x1fffull),
              (int) (tdata0 & 0x1ull),
              (long long) tdata1,
              (int) ((tdata2 >> 63) & 0x1ull),
              (int) ((tdata2 >> 60) & 0x7ull),
              (unsigned) ((tdata2 >> 44) & 0xffffull),
              (int) ((tdata2 >> 32) & 0xfffull)
      );
    }
    rc = cxl_mmio_read64 (afu_h, MMIO_TRACE_ADDR, &tdata0);
    rc = cxl_mmio_read64 (afu_h, MMIO_TRACE_ADDR, &tdata1);
    rc = cxl_mmio_read64 (afu_h, MMIO_TRACE_ADDR, &tdata2);
    command_lines_outstanding = command_lines_outstanding - 1;
    last_time = trace_time;
    trace_time = (tdata0 >> 24) & 0xffffffffffull;
    printf ("0x%010llx:", (long long) trace_time);
  }
  printf ("\n");

  ++trace_id;
  last_time = 0;
  printf ("Response events:\n");
  cxl_mmio_write64 (afu_h, MMIO_TRACE_ADDR, trace_id);
  rc = cxl_mmio_read64 (afu_h, MMIO_TRACE_ADDR, &tdata0);
  rc = cxl_mmio_read64 (afu_h, MMIO_TRACE_ADDR, &tdata1);
  response_lines_outstanding = response_lines_outstanding - 1;
  trace_time = (tdata0 >> 24) & 0xffffffffffull;
  printf ("0x%010llx:", (long long) trace_time);
  while (response_lines_outstanding != 0) {
    if (tdata0 & 0x0000000000800000ull) {
      printf (" Tag:0x%02x,%d Code:0x%02x credits:%d\n",
              (unsigned) ((tdata0 >> 15) & 0xffull),
              (int) ((tdata0 >> 14) & 0x1ull),
              (unsigned) ((tdata0 >> 6) & 0xffull),
              (unsigned) (((tdata0 & 0x3full) < 3) | ((tdata1 >> 61) & 0x7ull))
      );
    }
    rc = cxl_mmio_read64 (afu_h, MMIO_TRACE_ADDR, &tdata0);
    rc = cxl_mmio_read64 (afu_h, MMIO_TRACE_ADDR, &tdata1);
    response_lines_outstanding = response_lines_outstanding - 1;
    last_time = trace_time;
    trace_time = (tdata0 >> 24) & 0xffffffffffull;
    printf ("0x%010llx:", (long long) trace_time);
  }
  printf ("\n");

  ++trace_id;
  last_time = 0;
  printf ("Control events:\n");
  cxl_mmio_write64 (afu_h, MMIO_TRACE_ADDR, trace_id);
  rc = cxl_mmio_read64 (afu_h, MMIO_TRACE_ADDR, &tdata0);
  rc = cxl_mmio_read64 (afu_h, MMIO_TRACE_ADDR, &tdata1);
  rc = cxl_mmio_read64 (afu_h, MMIO_TRACE_ADDR, &tdata2);
  control_lines_outstanding = control_lines_outstanding - 1;
  trace_time = (tdata0 >> 24) & 0xffffffffffull;
  printf ("0x%010llx:", (long long) trace_time);
  while (control_lines_outstanding != 0) {
    if (tdata0 & 0x0000000000800000ull) {
      printf (" Command:0x%02x,%d Addr:0x%016llx,%d\n",
              (unsigned) ((tdata0 >> 15) & 0xffull),
              (int) ((tdata0 >> 14) & 0x1ull),
              (long long) ((tdata0 << 50) | (tdata1 >> 14)),
              (int) ((tdata1 >> 13) & 0x1ull)
      );
    }
    if (tdata1 & 0x0000000000000800ull) {
      printf ("0x%010llx:", (long long) trace_time);
      printf (" Done, Error:0x%016llx\n",
              (long long) ((tdata1 << 53) | (tdata2 >> 11))
      );
    }
    rc = cxl_mmio_read64 (afu_h, MMIO_TRACE_ADDR, &tdata0);
    rc = cxl_mmio_read64 (afu_h, MMIO_TRACE_ADDR, &tdata1);
    rc = cxl_mmio_read64 (afu_h, MMIO_TRACE_ADDR, &tdata2);
    control_lines_outstanding = control_lines_outstanding - 1;
    last_time = trace_time;
    trace_time = (tdata0 >> 24) & 0xffffffffffull;
    printf ("0x%010llx:", (long long) trace_time);
  }
  printf ("\n");

}

int main (int argc, char *argv[])
{
  int opt, ret;
  int option_index = 0;
  uint64_t stat_ctl_reg_wrdata = 0x0000000000000000;
  uint64_t stat_ctl_reg_rddata;
  int com_trace_reads = 3;
  int resp_trace_reads = 3;
  int ctl_trace_reads = 2;
  
  // get timeout:
  printf("Enter timeout:");
  scanf("%d",&timeout);

  sequence_t *sequences;
  unsigned int ID=0;
  if(argc < 3 ){
	  print_help("***");
	  return -1;
  }
  
  int i;
  // allocate aligned memory space for the sequences:
  size_t seq_size= (argc-1)*sizeof(sequence_t);
  ret= posix_memalign((sequence_t**)&sequences, CACHELINE_BYTES,seq_size); // alignment for reads should follow the chache width
  if(alloc_test("SEQ", (__u64) sequences, ret))
    return -1;
  for(i=0; i < (argc-1); i++)// get sequences
  {
	  sequences[i].ID = ID;
	  sequences[i].length = strlen(argv[i+1]);
	  charTo2bit(argv[i+1],sequences[i].data);
	  ID++;
  }
  
  // allocate memory for the result:
  __u64 *result;
  ret= posix_memalign((__u64**)&result, CACHELINE_BYTES, CACHELINE_BYTES); // alignment for writes must be a power of 2, and also a have the same value as the data size                    
  if(alloc_test("RES", (__u64) result, ret))
    return -1;
	#ifdef _DEBUGGING_
  // print sequences content:
  int k;
  printf("========== @Sequences: =============\n");
  printf("----result\t@0x%016llx\n",(long long)result);
  printf("----sequences\t@0x%016llx\n",(long long)sequences);
  printf("size= %d Bytes\n",(int)seq_size);
  for(k=0; k< argc-1; k++)
  {
	printf("ID: %010d:\n",sequences[k].ID);
	printf("length: %04d\n",sequences[k].length);
	for(i=0; i<(int)ceil((double)strlen(argv[1])/4); i++)
		printf("data[%2d]: 0x%02x\n",i,sequences[k].data[i]);
	printf("====================================\n");
  }
  printf("ceil test: %f\n",ceil(strlen(argv[1])/4));
	#endif 
	 
  // open AFU:
  struct cxl_afu_h *afu_h;
  afu_h = cxl_afu_open_dev (DEVICE);
  if (!afu_h) {
    perror("cxl_afu_open_dev:"DEVICE);
    return -1;
  }
  #ifdef _DEBUGGING_
  printf("AFU opended!\n");
  #endif 
  
  // allocate WED:
  struct seq_WED *wed0;
  ret= posix_memalign((struct seq_WED**)&wed0, CACHELINE_BYTES,sizeof(struct seq_WED));
  if(alloc_test("WED", (__u64) wed0, ret))
    return -1;
  // pass necessary values to WED:
  wed0->endian = 1; // set as in the memcpy example
  wed0->status = 0; 
  wed0->major = 0xFFFF;
  wed0->minor = 0xFFFF;
  wed0->sequences= sequences;
  wed0->result = result;
  wed0->size = seq_size;
  #ifdef _DEBUGGING_
  // print wed address:
  printf("WED @0x%016llx\n",(long long)wed0);
  #endif
    
  // Send start to AFU
  cxl_afu_attach (afu_h, (__u64) wed0);
  #ifdef _DEBUGGING_
  printf("AFU started!\n");
  #endif
  
   // Map AFU MMIO registers
  if ((cxl_mmio_map (afu_h, CXL_MMIO_BIG_ENDIAN)) < 0) {
    perror("cxl_mmio_map:"DEVICE);
    return -1;
  }
  #ifdef _DEBUGGING_
  printf("MMIO registers mapped!\n");
  #endif
  
  // Pre mmio section. Do mmio reads and writes. Set bit 0 to 1 when writing trace options register to kick off copy routine
  stat_ctl_reg_wrdata = 0x8000000000000000; 
  cxl_mmio_read64 (afu_h, MMIO_STAT_CTL_REG_ADDR, &stat_ctl_reg_rddata);
  #ifdef _DEBUGGING_
  printf("Trace Options register is %016llx after attach. Waiting for bit 32 to be a 1 (not including this read).\n", (long long) stat_ctl_reg_rddata);
  #endif
  for(i=0;i<20;i++) {
    cxl_mmio_read64 (afu_h, MMIO_STAT_CTL_REG_ADDR, &stat_ctl_reg_rddata);
    stat_ctl_reg_rddata = stat_ctl_reg_rddata >> 31;
    stat_ctl_reg_rddata = stat_ctl_reg_rddata % 2;
    #ifdef _DEBUGGING_
      printf("Pre mmio state bit is %08lx\n", stat_ctl_reg_rddata);
    #endif
    if(stat_ctl_reg_rddata == 1) 
      break;
    if(i==19){
      printf("ERROR: Never hit pre mmio state.\n");
      return -1;
    }
  }

  //Extra mmios here before starting copy function
      
  #ifdef _DEBUGGING_
    printf("Writing bit 0 of trace options register to 1 to end pre mmio stage\n");
  #endif

  //Leave pre-mmio state
  cxl_mmio_write64 (afu_h, MMIO_STAT_CTL_REG_ADDR, stat_ctl_reg_wrdata);

  // Wait for AFU to start or timeout.
  struct timespec start, now;
  double time_passed;
  if (clock_gettime(CLOCK_REALTIME, &start) == -1) {
    perror("clock_gettime");
    return -1;
  }
  now = start;
  while (wed0->major==0xFFFF) {
    struct timespec ts;
    ts.tv_sec = 0;
    ts.tv_nsec = 100;
    nanosleep(&ts, &ts);
    if (clock_gettime(CLOCK_REALTIME, &now) == -1) {
      perror("clock_gettime");
      return -1;
    }
    time_passed = (now.tv_sec - start.tv_sec) +
		   (double)(now.tv_nsec - start.tv_nsec) /
		   (double)(1000000000L);
    if (((int) time_passed) > timeout)
      break;
  }
  
  //wed0 major field untouched after timeout time? Error!
  if (wed0->major==0xFFFF) {
    fprintf (stderr, "Timeout after %d seconds waiting for AFU to start\n",
	     timeout);
    check_errors (wed0);
    dump_trace (afu_h, com_trace_reads, resp_trace_reads, ctl_trace_reads);
    return -1;
  }

  printf ("AFU has started, waiting for AFU to finish...\n");
  fflush (stdout);

  cxl_mmio_read64 (afu_h, MMIO_STAT_CTL_REG_ADDR, &stat_ctl_reg_rddata);
  #ifdef _DEBUGGING_
  printf("Trace Options register is %016llx shortly after start\n", (long long) stat_ctl_reg_rddata);
  #endif
  
  
  // Wait for AFU to signal job complete or timeout
  if (clock_gettime(CLOCK_REALTIME, &start) == -1) {
    perror("clock_gettime");
    return -1;
  }
  printf("wed status: %04x\n", wed0->status);
  now = start;
  while (!wed0->status) {
    struct timespec ts;
    ts.tv_sec = 0;
    ts.tv_nsec = 100;
    nanosleep(&ts, &ts);
    if (clock_gettime(CLOCK_REALTIME, &now) == -1) {
      perror("clock_gettime");
      return -1;
    }
    time_passed = (now.tv_sec - start.tv_sec) +
		   (double)(now.tv_nsec - start.tv_nsec) /
		   (double)(1000000000L);
    if (((int) time_passed) > timeout)
      break;
  }
  printf("wed status: %04x\n", wed0->status);
  cxl_mmio_read64 (afu_h, MMIO_STAT_CTL_REG_ADDR, &stat_ctl_reg_rddata);
  stat_ctl_reg_rddata = stat_ctl_reg_rddata >> 30;
  stat_ctl_reg_rddata = stat_ctl_reg_rddata % 2;
  #ifdef _DEBUGGING_
  printf("Post mmio state bit is %08lx\n", stat_ctl_reg_rddata);
  #endif
  //if(stat_ctl_reg_rddata != 1) {
  //  printf("ERROR! Trace options post mmio start bit still isn't set!\n");
  //  return -1;
  //}
  while (stat_ctl_reg_rddata != 1) {
    struct timespec ts;
    ts.tv_sec = 0;
    ts.tv_nsec = 100;
    nanosleep(&ts, &ts);
    if (clock_gettime(CLOCK_REALTIME, &now) == -1) {
      perror("clock_gettime");
      return -1;
    }
    time_passed = (now.tv_sec - start.tv_sec) +
                   (double)(now.tv_nsec - start.tv_nsec) /
                   (double)(1000000000L);
    if (((int) time_passed) > timeout) {
      printf("ERROR! Trace options post mmio start bit still isn't set!\n");
      return -1;
    }
	 cxl_mmio_read64 (afu_h, MMIO_STAT_CTL_REG_ADDR, &stat_ctl_reg_rddata);
    stat_ctl_reg_rddata = stat_ctl_reg_rddata >> 30;
    stat_ctl_reg_rddata = stat_ctl_reg_rddata % 2;
  } // end while
  cxl_mmio_read64 (afu_h, MMIO_STAT_CTL_REG_ADDR, &stat_ctl_reg_rddata);
  #ifdef _DEBUGGING_
  printf("Trace Options register is %016llx indicating post mmio stage. Dumping Trace Arrays....\n", (long long) stat_ctl_reg_rddata);
  #endif
  
  //Unconditional dump of trace arrays.
  dump_trace(afu_h,com_trace_reads,resp_trace_reads,ctl_trace_reads);
  #ifdef _DEBUGGING_
  printf("Finished Dumping Trace arrays. Writing bit of Trace options register to send memcpy back to idle\n");
  #endif 
  //Other mmios could be added here other than dumping the trace arrays.

  stat_ctl_reg_wrdata = 0x4000000000000000;
  cxl_mmio_write64 (afu_h, MMIO_STAT_CTL_REG_ADDR, stat_ctl_reg_wrdata);
  
/*  if (verbose) {*/
/*    check_errors (wed0);*/
/*  }*/
  
  printf("result: %d, biased: %d(0x%04x)\n",(*result-2048),*result,*result);
  // Unmap AFU
  cxl_mmio_unmap (afu_h);

  cxl_afu_free (afu_h);
  #ifdef _DEBUGGING_
  printf("AFU released!\n");
  #endif 
  return 0;
}
