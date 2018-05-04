/*
 * Copyright 1993-2010 NVIDIA Corporation.  All rights reserved.
 *
 * NVIDIA Corporation and its licensors retain all intellectual property and 
 * proprietary rights in and to this software and related documentation. 
 * Any use, reproduction, disclosure, or distribution of this software 
 * and related documentation without an express license agreement from
 * NVIDIA Corporation is strictly prohibited.
 *
 * Please refer to the applicable NVIDIA end user license agreement (EULA) 
 * associated with this source code for terms and conditions that govern 
 * your use of this NVIDIA software.
 * 
 */

#include "cuda.h"
#include "../common/book.h"
#include "../common/cpu_anim.h"

#define DIM 512
#define PI 3.1415926535897932f
#define MAX_TEMP 1.0f
#define MIN_TEMP 0.0001f
#define SPEED 0.25f

__global__ void copy_const_kernel(float *iptr, const float *cptr){
	// 2D grid, 2D block
	int x = blockIdx.x * blockDim.x + threadIdx.x;
	int y = blockIdx.y * blockDim.y + threadIdx.y;
	int offset = y * blockDim.x * gridDim.x + x;

	if(cptr[offset] != 0)
		iptr[offset] = cptr[offset];
}

__global__ void blend_kernel( float *outSrc, const float *inSrc){
	int x = blockIdx.x * blockDim.x + threadIdx.x;
	int y = blockIdx.y * blockDim.y + threadIdx.y;
	int offset = y * blockDim.x*gridDim.x + x;

	int left = offset -1;
	int right = offset + 1;
	if (x == 0)  left++;
	if (right == DIM-1) right--;
	
	// the top and bottom cells are in the lines
	// above or below current line in a 2D rect
	int top = offset-DIM;
	int bottom = offset + DIM;
	if ( y == 0) top += DIM;
	if ( y == DIM-1) bottom -= DIM;

	outSrc[offset] = inSrc[offset] + SPEED*(inSrc[top] + inSrc[bottom]+
											inSrc[left]+ inSrc[right]-
											inSrc[offset]*4);
}
struct DataBlock{
	unsigned char	*output_bitmap;
	float			*dev_inSrc;
	float			*dev_outSrc;
	float			*dev_constSrc;
	CPUAnimBitmap	*bitmap;
	cudaEvent_t		start, stop;
	float			totalTime;
	float			frames;
};

void anim_gpu(DataBlock *d, int ticks){
	HANDLE_ERROR( cudaEventRecord( d->start, 0) );
	int threadsPerBlock=16;
	dim3 threads(threadsPerBlock, threadsPerBlock);
	dim3 blocks(DIM/threadsPerBlock, DIM/threadsPerBlock);
	CPUAnimBitmap *bitmap = d->bitmap;
	
	// 1、 保持有heater source的区域heat不变
	// 2、 根据公式更新grid
	// 3、 将本次更新后的grid作为下一次的输入
	for(int i=0; i < 90; i++){
		copy_const_kernel<<<blocks, threads>>>(d->dev_inSrc, d->dev_constSrc);
		blend_kernel<<<blocks, threads>>>(d->dev_outSrc, d->dev_inSrc);
		swap(d->dev_inSrc, d->dev_outSrc);
	}
	float_to_color<<<blocks, threads>>>(d->output_bitmap, d->dev_inSrc);

	HANDLE_ERROR( cudaMemcpy(bitmap->get_ptr(), d->output_bitmap,
							 bitmap->image_size(), cudaMemcpyDeviceToHost));

	HANDLE_ERROR( cudaEventRecord( d->stop, 0));
	HANDLE_ERROR( cudaEventSynchronize( d->stop));
	float elapsedTime;
	HANDLE_ERROR( cudaEventElapsedTime( &elapsedTime, d->start, d->stop));
	d->totalTime += elapsedTime;
	++d->frames;
	printf("Average Time per frame: %3.1f ms\n", d->totalTime/d->frames);
}

void anim_exit( DataBlock *d){
	cudaFree( d->dev_inSrc);
	cudaFree( d->dev_outSrc);
	cudaFree( d->dev_constSrc);

	HANDLE_ERROR( cudaEventDestroy( d->start));
	HANDLE_ERROR( cudaEventDestroy( d->stop));
}


int main(void){
	DataBlock data;
	CPUAnimBitmap bitmap(DIM, DIM, &data);
	data.bitmap = &bitmap;
	data.totalTime = 0;
	data.frames = 0;

	HANDLE_ERROR( cudaEventCreate(&data.start));
	HANDLE_ERROR( cudaEventCreate(&data.stop));

	// image has DIM*DIM cells, each cell's color represented by 4 chars (rgba)
	// bitmap.image_size() == DIM*DIM*4
	HANDLE_ERROR( cudaMalloc( (void**) &data.output_bitmap, bitmap.image_size()));
	HANDLE_ERROR( cudaMalloc( (void**) &data.dev_inSrc, bitmap.image_size()));
	HANDLE_ERROR( cudaMalloc( (void**) &data.dev_outSrc, bitmap.image_size()));
	HANDLE_ERROR( cudaMalloc( (void**) &data.dev_constSrc, bitmap.image_size()));


	float *temp = (float*) malloc(bitmap.image_size());
	for(int i = 0; i < DIM*DIM; i++){
		temp[i] = 0;
		int x = i % DIM;
		int y = i / DIM;
		if ((x>150) && (x<300) && (y>160) && (y<300))
			temp[i] = MAX_TEMP;
	}
	
	temp[DIM*50+50] = (MAX_TEMP + MIN_TEMP)/2;
    temp[DIM*350+50] = MIN_TEMP;
    temp[DIM*150+150] = MIN_TEMP;
    temp[DIM*100+350] = MIN_TEMP;
	for (int y=400; y<450; y++) {
		for (int x=200; x<250; x++) { 
			temp[x+y*DIM] = MIN_TEMP;
		}
	}
	
	HANDLE_ERROR( cudaMemcpy( data.dev_constSrc, temp, bitmap.image_size(),
							cudaMemcpyHostToDevice));

	for (int y=400; y<DIM; y++) { 
		for (int x=0; x<100; x++) {
        	temp[x+y*DIM] = MAX_TEMP;
         }
     }

	HANDLE_ERROR( cudaMemcpy( data.dev_inSrc, temp,
                                 bitmap.image_size(),
                                 cudaMemcpyHostToDevice ) );
	free( temp );
	
	bitmap.anim_and_exit( (void (*)(void*,int))anim_gpu,
					(void (*)(void*))anim_exit );
}

