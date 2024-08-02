// Loads  PRU0 and PRU1 memory. Initialises buffer and displays (system-wide) DDR memory written by PRU0
// TODO: load data.bin also.
//  
// Pass in the filename of the .bin file on the command line, eg:  
// $ ./tm-arm pru0-text.bin  pru1-text.bin
//  
// Compile with:  
// gcc -std=gnu99 -o tm-arm tm-arm.c -lprussdrv 
#include <unistd.h>  
#include <stdlib.h>
#include <stdio.h> 
#include <string.h>
#include <inttypes.h>  
#include <prussdrv.h>  
#include <pruss_intc_mapping.h>  
#include <time.h>
#include <pthread.h>
#include <netdb.h>  
#include <sys/socket.h> 
#include <sys/types.h>
#include <arpa/inet.h>
#include <signal.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <semaphore.h> 
#include <time.h>


#define	false	0
#define	true	!false
#define	FRAMELEN	128
#define PREAMBLE	0xF9A42BB1
#define SAMPLINGFREQ	7		//If changed, code masking patterns also need to be changed
#define NOISEMARGIN	2
#define OUTBUFFNUMFRAME 50
#define TCPPACKLENGTH	(OUTBUFFNUMFRAME*FRAMELEN)
#define PORT1 8070
#define PORT2 8074
#define PORT3 8078 
#define MAXTCPRETRYCNT	3
#define SA struct sockaddr 

 static void *pru0DataMemory;  
 static unsigned int *pru0DataMemory_int;
 
 
volatile void *shared_ddr = NULL;
volatile void *pingStartAddress = NULL;
volatile void *pongStartAddress = NULL;
unsigned int *localMemory;
unsigned char lookupArray[0xffff] = {0};
union StreamUnion {
	unsigned long long int bitStream;
	unsigned int bitStreamInt[2];
} currStreamA, currStreamB;


const char* get_process_name_by_pid(const int pid) {
	char *name = (char*)calloc(1024,sizeof(char));
	char *name1 = (char*)calloc(1024,sizeof(char));
	if (name) {
		sprintf(name,"/proc/%d/cmdline",pid);
		FILE *f = NULL;
		f = fopen(name,"r");
		if (f != NULL) {
			fscanf (f,"%s\n",name1);			
			fclose(f);
		}	
	}	
	return name1;
}

void CheckMultipleInstances() {
	FILE *fp = NULL;	
	int prevPid = 0, currPid = 0;
	fp = fopen("pid.tm", "r");
	if (fp != NULL) {
		fscanf(fp,"%d", &prevPid);	
		currPid = getpid();		
		if (strcmp(get_process_name_by_pid(prevPid),get_process_name_by_pid(currPid)) == 0) {	
			printf("Another instance is running\n");
			fclose (fp);
			exit(0);
		}
		else {
			fclose (fp);
			fp = NULL;
			fp = fopen("pid.tm", "w");
			if (fp != NULL) {
				fprintf(fp,"%d", currPid);
				fclose(fp);
			}
		}
	}
	else {
		fp = fopen("pid.tm", "w");
		if (fp != NULL) {
			currPid = getpid();
			fprintf(fp,"%d", currPid);
			fclose(fp);
		}
	}	
}

int main(int argc, char **argv) 
{ 	

	CheckMultipleInstances(); 
	if (argc != 3) 
	{  
		printf("Usage: %s pru0_code.bin pru1_code\n", argv[0]);  
		return 1;  
	} 	

	sleep(1);


	prussdrv_init();  
	if (prussdrv_open(PRU_EVTOUT_0) == -1) 
	{  
		printf("prussdrv_open() event 0 failed\n");  
		return 1;  
	}
	

	tpruss_intc_initdata pruss_intc_initdata = PRUSS_INTC_INITDATA;  

    // Map PRU's INTC    
	prussdrv_pruintc_init(&pruss_intc_initdata);
    // Copy data to PRU memory - different way     
	prussdrv_map_prumem(PRUSS0_PRU1_DATARAM, &pru0DataMemory);   
	pru0DataMemory_int = (unsigned int *) pru0DataMemory;



	prussdrv_exec_program(1, argv[2]);  
	sleep(.5);  	
	prussdrv_exec_program(0, argv[1]);  
	sleep (1.);
	time_t rawtime;
	struct tm *timeinfo;
	system("clear");
	int current_event_no=0;
	int prev_event_no=0;
	int miss_interrupt=-1;
	unsigned int millisec=0;
	printf("\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n");
	do 
	{       	
		prev_event_no=current_event_no;
		current_event_no=prussdrv_pru_wait_event (PRU_EVTOUT_0); 
		/*if((current_event_no-prev_event_no)!=1)
			{miss_interrupt++;
			printf("Current event no:%d\nPrevious event no:%d",current_event_no,prev_event_no);
			}*/
		unsigned int ByteCounter = *(pru0DataMemory_int);
		unsigned int Hour = *(pru0DataMemory_int+1);   
		unsigned int Minute = *(pru0DataMemory_int+2);
		unsigned int Second = *(pru0DataMemory_int+3);
		unsigned int Count = *(pru0DataMemory_int+4);
		unsigned int Hold = *(pru0DataMemory_int+5);
		time(&rawtime);
		timeinfo= localtime(&rawtime);
		if(Hold!=1)
			if(Count==0x09)
				millisec=1000-(ByteCounter*100);
			else if(Count==0x50)
				millisec=(ByteCounter*100)-100;
	printf("\r\t\t\t\tPCTime : \x1b[31m %02d:%02d:%02d \x1b[0m CDT PRU Time : \x1b[32m %02x:%02x:%02x.%03d \x1b[0m Count Status :\x1b[33m %02x \x1b[0m Hold Status :\x1b[34m %02x \x1b[0m",
	timeinfo->tm_hour,timeinfo->tm_min,timeinfo->tm_sec,Hour,Minute,Second,millisec,Count,Hold);
	//printf("\nNo of interrupts missed:%d",miss_interrupt);
	//printf("\nCount Status:%x Hold Status:%x",);
        fflush(stdout);		
		prussdrv_pru_clear_event (PRU_EVTOUT_0, PRU0_ARM_INTERRUPT);   

	}
	while (1);
	prussdrv_pru_disable(0);  
	prussdrv_pru_disable(1);  
	prussdrv_exit();  

	printf ("Program exited\n");
	return 0;  
}  
