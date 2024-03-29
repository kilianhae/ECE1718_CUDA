import math

import torch
from torch.nn import functional as F
from torch.utils.cpp_extension import load

# Load the CUDA kernel as a python module
minimal_matmul = load(name='matmul', sources=['main.cpp', 'matmul.cu'], extra_cuda_cflags=['-O2'])

# Use small model params, otherwise slower than manual attention. See caveats in README.
# batch_size = 16
# n_head = 12
# seq_len = 128
# head_embd = 64
batch_size = 10
n_head = 1
seq_len = 5000
head_embd = 5000
torch.cuda.empty_cache()

q = torch.rand(batch_size, n_head, seq_len, head_embd).cuda()
k = torch.rand(batch_size, n_head, head_embd, seq_len).cuda()
#k = torch.rand([[[[1.0,3.0],[2.0,4.0]]]]).cuda()
print('=== profiling manual attention ===')

# Our minimal flash attention aims to be faster than this by avoiding HBM read/writes of N^2 matrices.
def manual_matmul(q, k):
    y = torch.matmul(q, k)
    return y

with torch.autograd.profiler.profile(use_cuda=True) as prof:
    manual_result = manual_matmul(q, k)
print(prof.key_averages().table(sort_by='cuda_time_total', row_limit=10))

print('=== profiling minimal flash attention === ')

with torch.autograd.profiler.profile(use_cuda=True) as prof:
    minimal_matmul = minimal_matmul.forward(q, k)
print(prof.key_averages().table(sort_by='cuda_time_total', row_limit=10))
print(minimal_matmul.cpu())
print(manual_result.cpu())
# print('attn values sanity check:', torch.allclose(minimal_matmul, manual_result, rtol=0, atol=1e-02))

