//nvcc SimpleJuliaSetGPU.cu -o SimpleJuliaSetGPU -lglut -lGL -lm
// This is a simple Julia set which is repeated iterations of 
// Znew = Zold + C whre Z and Care imaginary numbers.
// After so many tries if Zinitial escapes color it black if it stays around color it red.

#include <GL/glut.h>
#include <stdlib.h>
#include <stdio.h>
#include <math.h>
#include <time.h>
#include "../cudaError.h"

void Init();


#define A  -0.824  //real
#define B  -0.1711   //imaginary

unsigned int window_width = 1024;
unsigned int window_height = 1024;

int N = window_height*window_width;

dim3 BlockSize; //This variable will hold the Dimensions of your block
dim3 GridSize; //This variable will hold the Dimensions of your grid

float *pixels, *pixelsGPU; 

void SetUpCudaDevices()
{
	BlockSize.x = 1024;
	BlockSize.y = 1;
	BlockSize.z = 1;
	
	GridSize.x = 1024;
	GridSize.y = 1;
	GridSize.z = 1;
}

float xMin = -2.0;
float xMax =  2.0;
float yMin = -2.0;
float yMax =  2.0;

float stepSizeX = (xMax - xMin)/((float)window_width);
float stepSizeY = (yMax - yMin)/((float)window_height);

__global__ void compute(float *pixels, float stepSizeX, float stepSizeY, float xMin, float yMin, int N) 
{
	int id = 3*(threadIdx.x + blockDim.x*blockIdx.x); 
	float mag = 0.0;
	float maxmag = 10.0;
	float temp;
	int count = 0;
	int maxCount = 1000;

	float x = xMin + stepSizeX*threadIdx.x;
	float y = yMin + stepSizeY*blockIdx.x;

	if(id<3*N)
	{
		while(count < maxCount)
		{
			temp = x;
			x = x*x-y*y + A;
			y = (2.0*temp*y) + B;
			
			mag += sqrt(x*x + y*y);
			count++;
		}
		if(mag > maxmag)
		{
			pixels[id] = 1.0;
			pixels[id+1] = 0.0;
			pixels[id+2] = 0.0;
		}
		else
		{
			pixels[id] = 0.0;
			pixels[id+1] = 0.0;
			pixels[id+2] = 0.0;
		}
	}
}

void Display()
{
	Init();
	errorCheck(__FILE__, __LINE__);
	cudaMemcpyAsync(pixelsGPU, pixels, N*3*sizeof(float), cudaMemcpyHostToDevice);
	errorCheck(__FILE__, __LINE__);
	compute<<<GridSize, BlockSize>>>(pixelsGPU, stepSizeX, stepSizeY, xMin, yMin, N);
	errorCheck(__FILE__, __LINE__);
	cudaMemcpyAsync(pixels, pixelsGPU, N*3*sizeof(float), cudaMemcpyDeviceToHost);
	errorCheck(__FILE__, __LINE__);
	glDrawPixels(window_width, window_height, GL_RGB, GL_FLOAT, pixels); 
	glFlush(); 
}

void Init()
{
	pixels = (float*)malloc(N*3*sizeof(float));
	cudaMalloc(&pixelsGPU, N*3*sizeof(float));
}

void CleanUp()
{
	free(pixels);
	cudaFree(pixelsGPU);
}

int main(int argc, char** argv)
{ 
	SetUpCudaDevices();
	
   	glutInit(&argc, argv);
	glutInitDisplayMode(GLUT_RGB | GLUT_SINGLE);
   	glutInitWindowSize(window_width, window_height);
	glutCreateWindow("Fractals man, fractals.");
//	Init();
   	glutDisplayFunc(Display);	
	CleanUp();
   	glutMainLoop();
}
