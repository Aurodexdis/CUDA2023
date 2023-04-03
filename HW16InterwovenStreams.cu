// nvcc HW16InterwovenStreams.cu -o temp

#include <sys/time.h>
#include <stdio.h>
#include "./ErrorCode.h"

#define DATA_CHUNKS (1024*1024) 
#define ENTIRE_DATA_SET (21*DATA_CHUNKS)
#define MAX_RANDOM_NUMBER 1000
#define BLOCK_SIZE 256

//Function prototypes
void setUpCudaDevices();
void allocateMemory();
void loadData();
void cleanUp();
__global__ void trigAdditionGPU(float *, float *, float *, int );

//Globals
dim3 BlockSize; //This variable will hold the Dimensions of your block
dim3 GridSize; //This variable will hold the Dimensions of your grid
float *NumbersOnGPU, *PageableNumbersOnCPU, *PageLockedNumbersOnCPU;
float *A_CPU, *B_CPU, *C_CPU; //CPU pointers
float *A0_GPU, *B0_GPU, *C0_GPU, *A1_GPU, *B1_GPU, *C1_GPU, *A2_GPU, *B2_GPU, *C2_GPU;; //GPU pointers
cudaEvent_t StartEvent, StopEvent;
cudaStream_t Stream0, Stream1, Stream2;

//This will be the layout of the parallel space we will be using.
void setUpCudaDevices()
{
	cudaEventCreate(&StartEvent);
	errorCheck(__FILE__, __LINE__);
	cudaEventCreate(&StopEvent);
	errorCheck(__FILE__, __LINE__);
	
	cudaDeviceProp prop;
	int whichDevice;
	
	cudaGetDevice(&whichDevice);
	errorCheck(__FILE__, __LINE__);
	
	cudaGetDeviceProperties(&prop, whichDevice);
	errorCheck(__FILE__, __LINE__);
	
	if(prop.deviceOverlap != 1)
	{
		printf("\n GPU will not handle overlaps so no speedup from streams");
		printf("\n Good bye.");
		exit(0);
	}
	
	cudaStreamCreate(&Stream0);
	errorCheck(__FILE__, __LINE__);
	cudaStreamCreate(&Stream1);
	errorCheck(__FILE__, __LINE__);
	cudaStreamCreate(&Stream2);
	errorCheck(__FILE__, __LINE__);
	
	BlockSize.x = BLOCK_SIZE;
	BlockSize.y = 1;
	BlockSize.z = 1;
	
	if(DATA_CHUNKS%BLOCK_SIZE != 0)
	{
		printf("\n Data chunks do not divide evenly by block size, sooo this program will not work.");
		printf("\n Good bye.");
		exit(0);
	}
	GridSize.x = DATA_CHUNKS/BLOCK_SIZE;
	GridSize.y = 1;
	GridSize.z = 1;	
}

//Sets a side memory on the GPU and CPU for our use.
void allocateMemory()
{	
	//Allocate Device (GPU) Memory
	cudaMalloc(&A0_GPU,DATA_CHUNKS*sizeof(float));
	errorCheck(__FILE__, __LINE__);
	cudaMalloc(&B0_GPU,DATA_CHUNKS*sizeof(float));
	errorCheck(__FILE__, __LINE__);
	cudaMalloc(&C0_GPU,DATA_CHUNKS*sizeof(float));
	errorCheck(__FILE__, __LINE__);
	cudaMalloc(&A1_GPU,DATA_CHUNKS*sizeof(float));
	errorCheck(__FILE__, __LINE__);
	cudaMalloc(&B1_GPU,DATA_CHUNKS*sizeof(float));
	errorCheck(__FILE__, __LINE__);
	cudaMalloc(&C1_GPU,DATA_CHUNKS*sizeof(float));
	errorCheck(__FILE__, __LINE__);
	cudaMalloc(&A2_GPU,DATA_CHUNKS*sizeof(float));
	errorCheck(__FILE__, __LINE__);
	cudaMalloc(&B2_GPU,DATA_CHUNKS*sizeof(float));
	errorCheck(__FILE__, __LINE__);
	cudaMalloc(&C2_GPU,DATA_CHUNKS*sizeof(float));
	errorCheck(__FILE__, __LINE__);
	
	//Allocate page locked Host (CPU) Memory
	cudaHostAlloc(&A_CPU, ENTIRE_DATA_SET*sizeof(float), cudaHostAllocDefault);
	errorCheck(__FILE__, __LINE__);
	cudaHostAlloc(&B_CPU, ENTIRE_DATA_SET*sizeof(float), cudaHostAllocDefault);
	errorCheck(__FILE__, __LINE__);
	cudaHostAlloc(&C_CPU, ENTIRE_DATA_SET*sizeof(float), cudaHostAllocDefault);
	errorCheck(__FILE__, __LINE__);
}

void loadData()
{
	time_t t;
	srand((unsigned) time(&t));
	
	for(int i = 0; i < ENTIRE_DATA_SET; i++)
	{		
		A_CPU[i] = MAX_RANDOM_NUMBER*rand()/RAND_MAX;
		B_CPU[i] = MAX_RANDOM_NUMBER*rand()/RAND_MAX;	
	}
}

//Cleaning up memory after we are finished.
void cleanUp()
{
	cudaFree(A0_GPU); 
	errorCheck(__FILE__, __LINE__);
	cudaFree(B0_GPU); 
	errorCheck(__FILE__, __LINE__);
	cudaFree(C0_GPU); 
	errorCheck(__FILE__, __LINE__);
	cudaFree(A1_GPU); 
	errorCheck(__FILE__, __LINE__);
	cudaFree(B1_GPU); 
	errorCheck(__FILE__, __LINE__);
	cudaFree(C1_GPU); 
	errorCheck(__FILE__, __LINE__);
	cudaFree(A2_GPU); 
	errorCheck(__FILE__, __LINE__);
	cudaFree(B2_GPU); 
	errorCheck(__FILE__, __LINE__);
	cudaFree(C2_GPU); 
	errorCheck(__FILE__, __LINE__);
	
	cudaFreeHost(A_CPU);
	errorCheck(__FILE__, __LINE__);
	cudaFreeHost(B_CPU);
	errorCheck(__FILE__, __LINE__);
	cudaFreeHost(C_CPU);
	errorCheck(__FILE__, __LINE__);
	
	cudaEventDestroy(StartEvent);
	errorCheck(__FILE__, __LINE__);
	cudaEventDestroy(StopEvent);
	errorCheck(__FILE__, __LINE__);
	
	cudaStreamDestroy(Stream0);
	errorCheck(__FILE__, __LINE__);
	cudaStreamDestroy(Stream1);
	errorCheck(__FILE__, __LINE__);
	cudaStreamDestroy(Stream2);
	errorCheck(__FILE__, __LINE__);
}

__global__ void trigAdditionGPU(float *a, float *b, float *c, int n)
{
	int id = blockIdx.x*blockDim.x + threadIdx.x;
	
	if(id < n)
	{
		c[id] = sin(a[id]) + cos(b[id]);
	}
}

int main()
{
	float timeEvent;
	
	setUpCudaDevices();
	allocateMemory();
	loadData();
	
	cudaEventRecord(StartEvent, 0);
	errorCheck(__FILE__, __LINE__);
	
	for(int i = 0; i < ENTIRE_DATA_SET; i += DATA_CHUNKS*3)
	{
	//************************************************************************************************
		//copy the locked memory to the device for both streams
		cudaMemcpyAsync(A0_GPU, A_CPU+i, DATA_CHUNKS*sizeof(float), cudaMemcpyHostToDevice, Stream0);
		errorCheck(__FILE__, __LINE__);
		cudaMemcpyAsync(B0_GPU, B_CPU+i, DATA_CHUNKS*sizeof(float), cudaMemcpyHostToDevice, Stream0);
		errorCheck(__FILE__, __LINE__);
		cudaMemcpyAsync(A1_GPU, A_CPU+i+DATA_CHUNKS, DATA_CHUNKS*sizeof(float), cudaMemcpyHostToDevice, Stream1);
		errorCheck(__FILE__, __LINE__);
		cudaMemcpyAsync(B1_GPU, B_CPU+i+DATA_CHUNKS, DATA_CHUNKS*sizeof(float), cudaMemcpyHostToDevice, Stream1);
		errorCheck(__FILE__, __LINE__);
		cudaMemcpyAsync(A2_GPU, A_CPU+i+2*DATA_CHUNKS, DATA_CHUNKS*sizeof(float), cudaMemcpyHostToDevice, Stream2);
		errorCheck(__FILE__, __LINE__);
		cudaMemcpyAsync(B2_GPU, B_CPU+i+2*DATA_CHUNKS, DATA_CHUNKS*sizeof(float), cudaMemcpyHostToDevice, Stream2);
		errorCheck(__FILE__, __LINE__);
		
		//calling the kernel to do the trig addition for both streams
		trigAdditionGPU<<<GridSize,BlockSize,0,Stream0>>>(A0_GPU, B0_GPU, C0_GPU, DATA_CHUNKS);
		errorCheck(__FILE__, __LINE__);
		trigAdditionGPU<<<GridSize,BlockSize,0,Stream1>>>(A1_GPU, B1_GPU, C1_GPU, DATA_CHUNKS);
		errorCheck(__FILE__, __LINE__);
		trigAdditionGPU<<<GridSize,BlockSize,0,Stream1>>>(A2_GPU, B2_GPU, C2_GPU, DATA_CHUNKS);
		errorCheck(__FILE__, __LINE__);
		
		//copy the data from device to locked memory for both streams
		cudaMemcpyAsync(C_CPU+i, C0_GPU, DATA_CHUNKS*sizeof(float), cudaMemcpyDeviceToHost, Stream0);
		errorCheck(__FILE__, __LINE__);
		cudaMemcpyAsync(C_CPU+i+DATA_CHUNKS, C1_GPU, DATA_CHUNKS*sizeof(float), cudaMemcpyDeviceToHost, Stream1);
		errorCheck(__FILE__, __LINE__);
		cudaMemcpyAsync(C_CPU+i+2*DATA_CHUNKS, C2_GPU, DATA_CHUNKS*sizeof(float), cudaMemcpyDeviceToHost, Stream2);
		errorCheck(__FILE__, __LINE__);
	//************************************************************************************************
	}
	
	// Make the CPU wait until the Streams have finishd before it continues.
	cudaStreamSynchronize(Stream0);
	cudaStreamSynchronize(Stream1);
	cudaStreamSynchronize(Stream2);
	
	cudaEventRecord(StopEvent, 0);
	errorCheck(__FILE__, __LINE__);
	// Make the CPU wiat until this event finishes so the timing will be correct.
	cudaEventSynchronize(StopEvent); 
	errorCheck(__FILE__, __LINE__);
	cudaEventElapsedTime(&timeEvent, StartEvent, StopEvent);
	errorCheck(__FILE__, __LINE__);
	printf("\n Time on GPU = %3.1f milliseconds", timeEvent);
	
	
	printf("\n");
	//You're done so cleanup your mess.
	cleanUp();	
	
	return(0);
}
