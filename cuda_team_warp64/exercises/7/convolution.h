#ifndef CONVOLUTION_H
#define CONVOLUTION_H

// for standard sizes
#include <stdint.h>

// gaussian (CPU)
void gaussian_kernel(float *h_gaussian, float sigma);

// convolution kernel with dynamic shared memory for image and global memory for kernel
__global__ void convolution_dsm_gk(float *d_a, float *d_b, float *d_c, int width, int height, int wGaussian, int hGaussian, int nc);

// calls convolution kernel with a kernel generator
void gaussian_convolve_GPU(float *h_imgIn, float *h_gaussian, float *h_imgOut, uint32_t w, uint32_t h, uint32_t nc, uint32_t wKernel, uint32_t hKernel);

#endif