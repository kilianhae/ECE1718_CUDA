#include <iostream>
#include <cmath>
#include <cstdlib>
#include <cuda_runtime.h>
#include <cuda.h>

__global__ void softmax2D_kernel(float *d_in, float *d_out, int M, int N) {
    int row = blockIdx.y * blockDim.y + threadIdx.y;
    int col = blockIdx.x * blockDim.x + threadIdx.x;

    if (row < M && col < N) {
        // Find max value in the row
        float max_val = d_in[row * N];
        for (int i = 1; i < N; ++i) {
            max_val = fmaxf(max_val, d_in[row * N + i]);
        }
        
        // Subtract max value from each element for numerical stability
        float sum_exp = 0.0f;
        for (int i = 0; i < N; ++i) {
            sum_exp += expf(d_in[row * N + i] - max_val);
        }

        // Calculate softmax for each element in the row
        d_out[row * N + col] = expf(d_in[row * N + col] - max_val) / sum_exp;
    }
}

void softmax2D_cpu(float *d_in, float *d_out, int M, int N) {
    for (int row = 0; row < M; ++row) {
        // Find max value in the row
        float max_val = d_in[row * N];
        for (int i = 1; i < N; ++i) {
            max_val = fmaxf(max_val, d_in[row * N + i]);
        }
        
        // Subtract max value from each element for numerical stability
        float sum_exp = 0.0f;
        for (int i = 0; i < N; ++i) {
            sum_exp += expf(d_in[row * N + i] - max_val);
        }

        // Calculate softmax for each element in the row
        for (int col = 0; col < N; ++col) {
            d_out[row * N + col] = expf(d_in[row * N + col] - max_val) / sum_exp;
        }
    }
}

int main() {
    const int M = 4096; // Example: large number of rows
    const int N = 4096; // Example: large number of columns

    // Allocate memory on host
    float *input_host = (float*)malloc(M * N * sizeof(float));
    float *output_host_cpu = (float*)malloc(M * N * sizeof(float));
    float *output_host_gpu = (float*)malloc(M * N * sizeof(float));

    // Initialize input data
    for (int i = 0; i < M * N; i++) {
        input_host[i] = static_cast<float>(rand()) / RAND_MAX;
    }

    // Allocate memory on device
    float *input_device, *output_device;
    cudaMalloc(&input_device, M * N * sizeof(float));
    cudaMalloc(&output_device, M * N * sizeof(float));

    // Transfer input data from host to device
    cudaMemcpy(input_device, input_host, M * N * sizeof(float), cudaMemcpyHostToDevice);

    // Define grid and block size
    dim3 blockSize(16, 16);
    dim3 gridSize((N + blockSize.x - 1) / blockSize.x, (M + blockSize.y - 1) / blockSize.y);

    // Launch kernel
    softmax2D_kernel<<<gridSize, blockSize>>>(input_device, output_device, M, N);

    // Transfer output data from device to host
    cudaMemcpy(output_host_gpu, output_device, M * N * sizeof(float), cudaMemcpyDeviceToHost);

    // Perform softmax on CPU for verification
    softmax2D_cpu(input_host, output_host_cpu, M, N);
	cudaDeviceSynchronize();

    // Compare CPU and GPU results
    bool passed = true;
    for (int i = 0; i < M * N; i++) {
        if (fabs(output_host_cpu[i] - output_host_gpu[i]) > 1e-5) {
            std::cout << "CPU and GPU results mismatch at index " << i << ": "
                      << output_host_cpu[i] << " != " << output_host_gpu[i] << std::endl;
            passed = false;
            break;
        }
    }

    if (passed) {
        std::cout << "CPU and GPU results match." << std::endl;
    } else {
        std::cout << "CPU and GPU results mismatch." << std::endl;
    }

    // Free memory
    free(input_host);
    free(output_host_cpu);
    free(output_host_gpu);
    cudaFree(input_device);
    cudaFree(output_device);

    return 0;
}