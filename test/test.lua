local tester
local test = {}
local msize = 100
local minsize = 100
local maxsize = 1000
local nloop = 100
local times = {}

--e.g. unit test cmd: th -lcutorch -e "cutorch.test{'view','viewAs'}"

local function float(x)
   if type(x) == 'number' then
      return x
   else
      return x:float()
   end
end

local function isEqual(a, b, tolerance, ...)
   local diff = a-b
   tolerance = tolerance or 0.000001
   if type(a) == 'number' then
      return math.abs(diff) < tolerance
   else
      return diff:abs():max() < tolerance
   end
end

local function compareFloatAndCuda(x, fn, ...)
   x_cpu    = x:float()
   x_cuda   = x_cpu:cuda()
   local res_cpu, res_cuda
   if type(fn) == 'string' then
      tester:assertne(x_cuda[fn], nil,
         string.format("Missing function CudaTensor.%s", fn))
      res_cpu  = x_cpu[fn](x_cpu, ...)
      res_cuda = float(x_cuda[fn](x_cuda, ...))
   elseif type(fn) == 'function' then
      res_cpu  = fn(x_cpu, ...)
      res_cuda = float(fn(x_cuda, ...))
   else
      error("Incorrect function type")
   end
   local tolerance = 1e-5
   tester:assert(isEqual(res_cpu, res_cuda, tolerance),
      string.format("Divergent results between CPU and CUDA for function '%s'", fn))
end

local function compareFloatAndCudaTensorArgs(x, fn, ...)
   local x_cpu = x:float()
   local x_cuda = x_cpu:cuda()
   local res_cpu, res_cuda
   -- Transformation of args 
   local tranform_args = function(t, type)
      for k,v in pairs(t) do
         local v_type = torch.Tensor.type(v)
         if v_type == 'torch.FloatTensor' or v_type == 'torch.CudaTensor' or v_type == 'torch.DoubleTensor' then
            t[k] = v:type(type)
         end
      end
      return t
   end
   local cpu_args = tranform_args({...}, 'torch.FloatTensor')
   local cuda_args = tranform_args({...}, 'torch.CudaTensor')
   if type(fn) == 'string' then
      tester:assertne(x_cuda[fn], nil,
         string.format("Missing function CudaTensor.%s", fn))
      res_cpu  = x_cpu[fn](x_cpu, unpack(cpu_args))
      res_cuda = float(x_cuda[fn](x_cuda, unpack(cuda_args)))
   elseif type(fn) == 'function' then
      res_cpu  = fn(x_cpu, unpack(cpu_args))
      res_cuda = float(fn(x_cuda, unpack(cuda_args)))
   else
      error("Incorrect function type")
   end
   local tolerance = 1e-5
   tester:assert(isEqual(res_cpu, res_cuda, tolerance),
      string.format("Divergent results between CPU and CUDA for function '%s'", fn))
end

function test.expand()
   local sz = math.floor(torch.uniform(minsize,maxsize))
   local x = torch.FloatTensor():rand(sz, 1)
   compareFloatAndCuda(x, 'expand', sz, sz)

   x = torch.FloatTensor():rand(1, sz)
   compareFloatAndCuda(x, 'expand', sz, sz)
end

function test.view()
   local sz = math.floor(torch.uniform(minsize,maxsize))
   local x = torch.FloatTensor():rand(sz, 3)
   compareFloatAndCuda(x, 'view', sz, 3, 1)

   x = x:cuda()
   compareFloatAndCuda(x, 'view', sz, 3, 1)
end

function test.viewAs()
   local sz = math.floor(torch.uniform(minsize,maxsize))
   local x = torch.FloatTensor():rand(sz, 3)
   local y = torch.FloatTensor():rand(sz, 3, 1)
   compareFloatAndCuda(x, 'viewAs', y)

   x = x:cuda()
   y = y:cuda()
   compareFloatAndCuda(x, 'viewAs', y)
end

function test.repeatTensor()
   local sz = math.floor(torch.uniform(minsize,maxsize))
   local x = torch.FloatTensor():rand(sz, 3)
   compareFloatAndCuda(x, 'repeatTensor', sz, 2)

   x = x:cuda()
   compareFloatAndCuda(x, 'repeatTensor', sz, 2)
end

function test.copyNoncontiguous()
   local sz = math.floor(torch.uniform(minsize,maxsize))
   local x = torch.FloatTensor():rand(sz, 1)
   local f = function(src)
      return src.new(sz, sz):copy(src:expand(sz, sz))
   end
   compareFloatAndCuda(x, f)
end

function test.largeNoncontiguous()
   local x = torch.FloatTensor():randn(20, 1, 60, 60)
   local sz = math.floor(torch.uniform(maxsize, 2*maxsize))
   local f = function(src)
      return src.new(20, sz, 60, 60):copy(src:expand(20, sz, 60, 60))
   end
   compareFloatAndCuda(x, f)
end

function test.add()
   local sz1 = math.floor(torch.uniform(minsize,maxsize))
   local sz2 = math.floor(torch.uniform(minsize,maxsize))
   local x = torch.FloatTensor():rand(sz1, sz2)
   local y = torch.FloatTensor():rand(sz1, sz2)
   local z = torch.FloatTensor():rand(sz1, sz2)
   compareFloatAndCudaTensorArgs(x, 'add', y)
   compareFloatAndCudaTensorArgs(x, 'add', y, z)
end

function test.cmul()
   local sz1 = math.floor(torch.uniform(minsize,maxsize))
   local sz2 = math.floor(torch.uniform(minsize,maxsize))
   local x = torch.FloatTensor():rand(sz1, sz2)
   local y = torch.FloatTensor():rand(sz1, sz2)
   compareFloatAndCudaTensorArgs(x, 'cmul', y)
end

function test.cdiv()
   local sz1 = math.floor(torch.uniform(minsize,maxsize))
   local sz2 = math.floor(torch.uniform(minsize,maxsize))
   local x = torch.FloatTensor():rand(sz1, sz2)
   local y = torch.FloatTensor():rand(sz1, sz2)
   compareFloatAndCudaTensorArgs(x, 'cdiv', y)
end

function test.addcmul()
   local sz1 = math.floor(torch.uniform(minsize,maxsize))
   local sz2 = math.floor(torch.uniform(minsize,maxsize))
   local x = torch.FloatTensor():rand(sz1, sz2)
   local y = torch.FloatTensor():rand(sz1, sz2)
   local z = torch.FloatTensor():rand(sz1, sz2)
   compareFloatAndCudaTensorArgs(x, 'addcmul', y, z)
end

function test.addcdiv()
   local sz1 = math.floor(torch.uniform(minsize,maxsize))
   local sz2 = math.floor(torch.uniform(minsize,maxsize))
   local x = torch.FloatTensor():rand(sz1, sz2)
   local y = torch.FloatTensor():rand(sz1, sz2)
   local z = torch.FloatTensor():rand(sz1, sz2)
   compareFloatAndCudaTensorArgs(x, 'addcdiv', y, z)
end

function test.logicalValue()
   local sz1 = math.floor(torch.uniform(minsize,maxsize))
   local sz2 = math.floor(torch.uniform(minsize,maxsize))
   local x = torch.FloatTensor():rand(sz1, sz2)
   local y = torch.FloatTensor():rand(sz1, sz2)
   compareFloatAndCudaTensorArgs(x, 'gt', y, 0.3)
end

function test.logicalTensor()
   local sz1 = math.floor(torch.uniform(minsize,maxsize))
   local sz2 = math.floor(torch.uniform(minsize,maxsize))
   local x = torch.FloatTensor():rand(sz1, sz2)
   local y = torch.FloatTensor():rand(sz1, sz2)
   local z = torch.FloatTensor():rand(sz1, sz2)
   compareFloatAndCudaTensorArgs(x, 'gt', y, z)
end

function test.mean()
   local sz1 = math.floor(torch.uniform(minsize,maxsize))
   local sz2 = math.floor(torch.uniform(minsize,maxsize))
   local x = torch.FloatTensor():rand(sz1, sz2)
   compareFloatAndCuda(x, 'mean')
   compareFloatAndCuda(x, 'mean', 1)
   compareFloatAndCuda(x, 'mean', 2)
end

function test.var()
   local sz1 = math.floor(torch.uniform(minsize,maxsize))
   local sz2 = math.floor(torch.uniform(minsize,maxsize))
   local x = torch.FloatTensor():rand(sz1, sz2)
   compareFloatAndCuda(x, 'var')
   -- multi-dim var is not implemented
   -- compareFloatAndCuda(x, 'var', 1, true)
   -- compareFloatAndCuda(x, 'var', 1, false)
   -- compareFloatAndCuda(x, 'var', 2, true)
   -- compareFloatAndCuda(x, 'var', 2, false)
end

function test.std()
   local sz1 = math.floor(torch.uniform(minsize,maxsize))
   local sz2 = math.floor(torch.uniform(minsize,maxsize))
   local x = torch.FloatTensor():rand(sz1, sz2)
   compareFloatAndCuda(x, 'std')
   -- multi-dim std is not implemented
   -- compareFloatAndCuda(x, 'std', 1, true)
   -- compareFloatAndCuda(x, 'std', 1, false)
   -- compareFloatAndCuda(x, 'std', 2, true)
   -- compareFloatAndCuda(x, 'std', 2, false)
end

function test.index()
   local sz1 = math.floor(torch.uniform(minsize,maxsize))
   local sz2 = math.floor(torch.uniform(minsize,maxsize))
   local sz3 = math.floor(torch.uniform(10,20))
   local x = torch.FloatTensor():rand(sz1, sz2)

   local longIndex = torch.LongTensor{math.floor(torch.uniform(1, sz1)), math.floor(torch.uniform(1, sz1))}
   local index = 1
   compareFloatAndCuda(x, 'index', index, longIndex)
   
   index = 2
   longIndex =  torch.LongTensor{math.floor(torch.uniform(1, sz2)), math.floor(torch.uniform(1, sz2))}
   compareFloatAndCuda(x, 'index', index, longIndex)
   
   x = torch.FloatTensor():rand(sz1)
   index = 1
   longIndex = torch.LongTensor{math.floor(torch.uniform(1, sz1)), math.floor(torch.uniform(1, sz1))}
   compareFloatAndCuda(x, 'index', index, longIndex)

   x = torch.FloatTensor():rand(sz1,sz2,sz3)
   index = 3
   longIndex = torch.randperm(sz3):long()
   compareFloatAndCuda(x, 'index', index, longIndex)
end

local function testReduce(name)
   local sz1 = math.floor(torch.uniform(minsize,maxsize)) -- dim1
   local sz2 = math.floor(torch.uniform(minsize,maxsize)) -- dim2
   local x = torch.FloatTensor():rand(sz1, sz2) -- input

   -- Case 1: 2D tensor, indexCopy over first dimension, 2 indices
   -- choose two indices from the first dimension, i.e. [1,sz1]
   local longIndex = torch.LongTensor{math.floor(torch.uniform(1, sz1)), math.floor(torch.uniform(1, sz1))}
   local index = 1
   local src = torch.Tensor(2, sz2):uniform()
   compareFloatAndCudaTensorArgs(x, name, index, longIndex, src)

   -- Case 2: 2D tensor, indexCopy over second dimension, 2 indices
   index = 2
   longIndex =  torch.LongTensor{math.floor(torch.uniform(1, sz2)), math.floor(torch.uniform(1, sz2))}
   src = torch.Tensor(sz1, 2):uniform():cuda()
   compareFloatAndCudaTensorArgs(x, name, index, longIndex, src)

   -- Case 3: 1D tensor, indexCopy over 1st dimension, 2 indices
   x = torch.FloatTensor():rand(sz1)
   index = 1
   longIndex = torch.LongTensor{math.floor(torch.uniform(1, sz1)), math.floor(torch.uniform(1, sz1))}
   src = torch.Tensor(2):uniform()
   compareFloatAndCudaTensorArgs(x, name, index, longIndex, src)
end

function test.testCopy(name)
  testReduce('indexCopy')
end

function test.indexFill()
   local sz1 = math.floor(torch.uniform(minsize,maxsize))
   local sz2 = math.floor(torch.uniform(minsize,maxsize))
   local x = torch.FloatTensor():rand(sz1, sz2)
   
   local longIndex = torch.LongTensor{math.floor(torch.uniform(1, sz1)), math.floor(torch.uniform(1, sz1))}
   local index = 1
   local val = torch.randn(1)[1]
   compareFloatAndCuda(x, 'indexFill', index, longIndex, val)

   index = 2
   longIndex =  torch.LongTensor{math.floor(torch.uniform(1, sz2)), math.floor(torch.uniform(1, sz2))}
   val = torch.randn(1)[1]
   compareFloatAndCuda(x, 'indexFill', index, longIndex, val)
   
   x = torch.FloatTensor():rand(sz1)
   index = 1
   longIndex = torch.LongTensor{math.floor(torch.uniform(1, sz1)), math.floor(torch.uniform(1, sz1))}
   val = torch.randn(1)[1]
   compareFloatAndCuda(x, 'indexFill', index, longIndex, val)
end

function test.renorm()
   local x = torch.randn(10,5):float()
   local maxnorm = x:norm(2,1):mean()
   
   compareFloatAndCuda(x, 'renorm', 2, 2, maxnorm)
   
   x = torch.randn(3,4,5)
   compareFloatAndCuda(x, 'renorm', 2, 2, maxnorm)
     
   x = torch.randn(3,4,5)
   compareFloatAndCuda(x, 'renorm', 3, 2, maxnorm)
    
   x = torch.randn(3,4,5,100)
   compareFloatAndCuda(x, 'renorm', 3, 2, maxnorm)
    
   x = torch.randn(3,4,5,100)
   compareFloatAndCuda(x, 'renorm', 4, 2, maxnorm)
end

function test.indexSelect()
   --  test for speed
   local n_row = math.random(minsize,maxsize)
   local n_col = math.random(minsize,maxsize)
   local n_idx = math.random(n_col)
   
   local x = torch.randn(n_row, n_col):float()
   local indices = torch.randperm(n_idx):long()
   local z = torch.FloatTensor()
   
   local tm = {}
   local title = string.format('indexSelect ')
   times[title] = tm

   z:index(x, 2, indices)
   local groundtruth = z:clone()
   local clock = torch.Timer()
   for i=1,nloop do
      z:index(x, 2, indices)
   end
   tm.cpu = clock:time().real
   
   x = x:cuda()
   z = torch.CudaTensor()
   
   z:index(x, 2, indices)
   local rescuda = z:clone():float()
   clock:reset()
   for i=1,nloop do
      z:index(x, 2, indices)
   end
   tm.gpu = clock:time().real
   
   tester:assertTensorEq(groundtruth, rescuda, 0.00001, "Error in indexSelect")
end

function test.addmm()
   --[[ Size ]]--
   local sizes = {
      {16, 3, 1},
      {1, 12, 1},
      {24, 23, 22},
      {1, 1, 1},
      {1, 1, 7},
      {12, 1, 12},
      {10, 10, 10},
   }
   for _, size in pairs(sizes) do
      local n, k, m = unpack(size)
      local c = torch.zeros(n, m)
      local a = torch.randn(n, k)
      local b = torch.randn(k, m)
      compareFloatAndCudaTensorArgs(c, 'addmm', 0, 1, a, b)
   end
end

function test.isSameSizeAs()
   local t1 = torch.CudaTensor(3, 4, 9, 10)
   local t2 = torch.CudaTensor(3, 4)
   local t3 = torch.CudaTensor(1, 9, 3, 3)
   local t4 = torch.CudaTensor(3, 4, 9, 10)

   tester:assert(t1:isSameSizeAs(t2) == false, "wrong answer ")
   tester:assert(t1:isSameSizeAs(t3) == false, "wrong answer ")
   tester:assert(t1:isSameSizeAs(t4) == true, "wrong answer ")
end

function cutorch.test(tests)
   math.randomseed(os.time())
   torch.manualSeed(os.time())
   tester = torch.Tester()
   tester:add(test)
   tester:run(tests)
   print ''
   for module,tm in pairs(times) do
      print(module .. ': \t average speedup is ' .. (tm.cpu / (tm.gpu or 1e6)))
   end
end
