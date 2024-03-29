#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include "timer.h"
#include "files.h"

#define SOFTENING 1e-9f

/*
 * Each body contains x, y, and z coordinate positions,
 * as well as velocities in the x, y, and z directions.
 */

typedef struct { float x, y, z, vx, vy, vz; } Body;

/*This function updates the position of the bodies within the system*/

__global__ void updateBodies(Body *p, float dt, int n, int jump)
{
  int id = threadIdx.x + blockIdx.x * blockDim.x;
  for(int i = id; i<n ; i+=jump)
  {
      p[i].x += p[i].vx*dt;
      p[i].y += p[i].vy*dt;
      p[i].z += p[i].vz*dt;
  }
}

/*
 * The bodyForce function calculates the gravitational force of all bodies in the system
 * on all others, but does not update their positions.
 */

__global__ void bodyForce(Body *p, float dt, int n, int jump) 
{
  int id = threadIdx.x + blockIdx.x * blockDim.x;
  
  //change for loop to allow for parallelization of the calculation of BodyForces utilizing jump and id
  
  for(int i = id; i<n ; i+=jump)
  {
    float Fx = 0.0f; float Fy = 0.0f; float Fz = 0.0f;

    for (int j = 0; j < n; j++) 
    {
      float dx = p[j].x - p[i].x;
      float dy = p[j].y - p[i].y;
      float dz = p[j].z - p[i].z;
      float distSqr = dx*dx + dy*dy + dz*dz + SOFTENING;
      float invDist = rsqrtf(distSqr);
      float invDist3 = invDist * invDist * invDist;

      Fx += dx * invDist3; Fy += dy * invDist3; Fz += dz * invDist3;
    }

    p[i].vx += dt*Fx; p[i].vy += dt*Fy; p[i].vz += dt*Fz;
  }
}

int main(const int argc, const char** argv) 
{

  // The assessment will test against both 2<11 and 2<15.
  // Feel free to pass the command line argument 15 when you generate ./nbody report files
  
  //New variables, deviceId allows you to get the cuda device you are using as well as the attributes
  //Number of SMs allows you to store the number of streaming multiprocessors anmd use it for the number of blocks
  int deviceId;
  int numberOfSMs;

  cudaGetDevice(&deviceId);
  cudaDeviceGetAttribute(&numberOfSMs, cudaDevAttrMultiProcessorCount, deviceId);

  int nBodies = 2<<11;
  if (argc > 1) nBodies = 2<<atoi(argv[1]); //atoi() converts a character string to an integer value

  // The assessment will pass hidden initialized values to check for correctness.
  // You should not make changes to these files, or else the assessment will not work.
  const char * initialized_values;
  const char * solution_values;

  if (nBodies == 2<<11) {
    initialized_values = "09-nbody/files/initialized_4096";
    solution_values = "09-nbody/files/solution_4096";
  } else { // nBodies == 2<<15
    initialized_values = "09-nbody/files/initialized_65536";
    solution_values = "09-nbody/files/solution_65536";
  }

  if (argc > 2) initialized_values = argv[2];
  if (argc > 3) solution_values = argv[3];
  
  const float dt = 0.01f; // Time step
  const int nIters = 10;  // Simulation iterations

  int bytes = nBodies * sizeof(Body); //Allows you to understand the amount of bytes you need to allocate mem for
  float *buf;
  
  cudaMallocManaged(&buf, bytes); 
  //This is a new type of memory allocation, you are allocated unified memory
  //Unified Memory is a single memory address space accessible from any processor in a system
  //This is an allocation function that returns a pointer accessible from any processor
  
  Body *p = (Body*)buf;

  read_values_from_file(initialized_values, buf, bytes);
  
  double totalTime = 0.0;

  /*
   * This simulation will run for 10 cycles of time, calculating gravitational
   * interaction amongst bodies, and adjusting their positions to reflect.
   */

  for (int iter = 0; iter < nIters; iter++) {
    StartTimer();

  /*
   * You will likely wish to refactor the work being done in `bodyForce`,
   * as well as the work to integrate the positions.
   */
   
  cudaMemPrefetchAsync(buf, bytes, deviceId); 
  //Prefetches memory to the specified destination
  //In this case it prefetches it to the CUDA Device we are using
  
  cudaDeviceSynchronize(); //wait for the computing device to finish
  int threadNum = 256;
  int blockNum = numberOfSMs;
  int jump = threadNum * blockNum;
  bodyForce<<<blockNum,threadNum>>>(p, dt, nBodies,jump); // compute interbody forces

  /*
   * This position integration cannot occur until this round of `bodyForce` has completed.
   * Also, the next round of `bodyForce` cannot begin until the integration is complete.
   */
   
  cudaDeviceSynchronize();
  updateBodies<<<blockNum,threadNum>>>(p,dt,nBodies,jump); //updates the positions of the bodies using the velocities
  cudaDeviceSynchronize();
  
    //for (int i = 0 ; i < nBodies; i++) { // integrate position
    //  p[i].x += p[i].vx*dt;
    //  p[i].y += p[i].vy*dt;
    //  p[i].z += p[i].vz*dt;
    //}

    const double tElapsed = GetTimer() / 1000.0;
    totalTime += tElapsed;
  }

  double avgTime = totalTime / (double)(nIters);
  float billionsOfOpsPerSecond = 1e-9 * nBodies * nBodies / avgTime;
  write_values_to_file(solution_values, buf, bytes);

  // You will likely enjoy watching this value grow as you accelerate the application,
  // but beware that a failure to correctly synchronize the device might result in
  // unrealistically high values.
  
  printf("%0.3f Billion Interactions / second\n", billionsOfOpsPerSecond);

  cudaFree(buf);
}
