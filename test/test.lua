local runtests = false
if not cutorch then
   require 'cutorch'
   runtests = true
end
local tester
local test = {}
local msize = 100
local minsize = 100
local maxsize = 1000
local minvalue = 2
local maxvalue = 20
local nloop = 100
local times = {}

--e.g. unit test cmd: th -lcutorch -e "cutorch.test{'view','viewAs'}"

local function isEqual(a, b, tolerance, ...)
   if a == nil and b == nil then return true end
   if a == nil and b ~= nil then return false end
   if a ~= nil and b == nil then return false end
   if torch.type(b) ~= torch.type(a) then
      b = b:typeAs(a) -- TODO: remove the need for this (a-b doesnt work for bytetensor, cudatensor pairs)
   end
   local diff = a-b
   tolerance = tolerance or 0.000001
   if type(a) == 'number' then
      return math.abs(diff) < tolerance
   else
      if torch.type(diff) ~= 'torch.FloatTensor' then
         diff = diff:float() -- TODO: remove the need for this (byteTensor and abs)
      end
      return diff:abs():max() < tolerance
   end
end

local function compareFloatAndCuda(x, fn, ...)
   x_cpu    = x:float()
   x_cuda   = x_cpu:cuda()
   local res1_cpu, res2_cpu, res3_cpu, res4_cpu
   local res1_cuda, res2_cuda, res3_cuda, res4_cuda
   if type(fn) == 'string' then
      tester:assertne(x_cuda[fn], nil,
         string.format("Missing function CudaTensor.%s", fn))
      res1_cpu, res2_cpu, res3_cpu, res4_cpu  = x_cpu[fn](x_cpu, ...)
      res1_cuda, res2_cuda, res3_cuda, res4_cuda = x_cuda[fn](x_cuda, ...)
   elseif type(fn) == 'function' then
      res1_cpu, res2_cpu, res3_cpu, res4_cpu  = fn(x_cpu, ...)
      res1_cuda, res2_cuda, res3_cuda, res4_cuda = fn(x_cuda, ...)
   else
      error("Incorrect function type")
   end
   local tolerance = 1e-5
   tester:assert(isEqual(res1_cpu, res1_cuda, tolerance),
      string.format("Divergent results between CPU and CUDA for function '%s'", tostring(fn)))
   tester:assert(isEqual(res2_cpu, res2_cuda, tolerance),
                 string.format("Divergent results between CPU and CUDA for function '%s'", tostring(fn)))
   tester:assert(isEqual(res3_cpu, res3_cuda, tolerance),
                 string.format("Divergent results between CPU and CUDA for function '%s'", tostring(fn)))
   tester:assert(isEqual(res4_cpu, res4_cuda, tolerance),
                 string.format("Divergent results between CPU and CUDA for function '%s'", tostring(fn)))
end

local function compareFloatAndCudaTensorArgs(x, fn, ...)
   local x_cpu = x:float()
   local x_cuda = x_cpu:cuda()
   local res1_cpu, res2_cpu, res3_cpu, res4_cpu
   local res1_cuda, res2_cuda, res3_cuda, res4_cuda
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
      res1_cpu, res2_cpu, res3_cpu, res4_cpu  = x_cpu[fn](x_cpu, unpack(cpu_args))
      res1_cuda, res2_cuda, res3_cuda, res4_cuda = x_cuda[fn](x_cuda, unpack(cuda_args))
   elseif type(fn) == 'function' then
      res1_cpu, res2_cpu, res3_cpu, res4_cpu  = fn(x_cpu, unpack(cpu_args))
      res1_cuda, res2_cuda, res3_cuda, res4_cuda = fn(x_cuda, unpack(cuda_args))
   else
      error("Incorrect function type")
   end
   local tolerance = 1e-5
   tester:assert(isEqual(res1_cpu, res1_cuda, tolerance),
                 string.format("Divergent results between CPU and CUDA for function '%s'", fn))
   tester:assert(isEqual(res2_cpu, res2_cuda, tolerance),
                 string.format("Divergent results between CPU and CUDA for function '%s'", fn))
   tester:assert(isEqual(res3_cpu, res3_cuda, tolerance),
                 string.format("Divergent results between CPU and CUDA for function '%s'", fn))
   tester:assert(isEqual(res4_cpu, res4_cuda, tolerance),
                 string.format("Divergent results between CPU and CUDA for function '%s'", fn))
end

function test.squeeze()
   local sz = math.floor(torch.uniform(minsize,maxsize))
   local x = torch.FloatTensor():rand(sz, 1, sz, 1)
   compareFloatAndCuda(x, 'squeeze')

   local y = x:cuda():squeeze()
   tester:assert(y:dim() == 2, "squeeze err")

   x = torch.FloatTensor():rand(sz, 1, 1, sz)
   compareFloatAndCuda(x, 'squeeze', 2)

   local y = x:cuda():squeeze(2)
   tester:assert(y:dim() == 3, "squeeze1d err")
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
end

function test.viewAs()
   local sz = math.floor(torch.uniform(minsize,maxsize))
   local x = torch.FloatTensor():rand(sz, 3)
   local y = torch.FloatTensor():rand(sz, 3, 1)
   compareFloatAndCudaTensorArgs(x, 'viewAs', y)
end

function test.repeatTensor()
   local sz = math.floor(torch.uniform(minsize,maxsize))
   local x = torch.FloatTensor():rand(sz, 3)
   compareFloatAndCuda(x, 'repeatTensor', sz, 2)
end

function test.copyNoncontiguous()
   local sz = math.floor(torch.uniform(minsize,maxsize))
   local x = torch.FloatTensor():rand(sz, 1)
   local f = function(src)
      return src.new(sz, sz):copy(src:expand(sz, sz))
   end
   compareFloatAndCuda(x, f)

   x = torch.FloatTensor():rand(sz, sz, 2)
   local f = function(src)
      return src.new(sz, sz):copy(src[{{},{},{2}}])
   end
   compareFloatAndCuda(x, f)

   x = torch.FloatTensor():rand(2, sz, sz)
   local f = function(src)
      return src.new(sz, sz):copy(src[{{2},{},{}}])
   end
   compareFloatAndCuda(x, f)

   x = torch.FloatTensor():rand(sz, 2, sz)
   local f = function(src)
      return src.new(sz, sz):copy(src[{{},{2},{}}])
   end
   compareFloatAndCuda(x, f)

   x = torch.FloatTensor():rand(sz, 2, sz)
   local f = function(src)
      return src.new(sz, 1, sz):copy(src[{{},{2},{}}])
   end
   compareFloatAndCuda(x, f)

   x = torch.FloatTensor():rand(sz, sz):transpose(1,2)
   local f = function(src)
      return src.new(sz, sz):copy(src)
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

function test.zero()
   local sz1 = math.floor(torch.uniform(minsize,maxsize))
   local sz2 = math.floor(torch.uniform(minsize,maxsize))
   local x = torch.FloatTensor():rand(sz1, sz2)
   compareFloatAndCudaTensorArgs(x, 'zero')
end

function test.fill()
   local sz1 = math.floor(torch.uniform(minsize,maxsize))
   local sz2 = math.floor(torch.uniform(minsize,maxsize))
   local x = torch.FloatTensor():rand(sz1, sz2)
   local v = torch.uniform()
   compareFloatAndCudaTensorArgs(x, 'fill', v)
end

function test.reshape()
   local sz1 = math.floor(torch.uniform(minsize,maxsize))*2
   local sz2 = math.floor(torch.uniform(minsize,maxsize))
   local x = torch.FloatTensor():rand(sz1, sz2)
   compareFloatAndCudaTensorArgs(x, 'reshape', sz1/2, sz2*2)
end

function test.zeros()
   local sz1 = math.floor(torch.uniform(minsize,maxsize))
   local sz2 = math.floor(torch.uniform(minsize,maxsize))
   local t = torch.getdefaulttensortype()
   torch.setdefaulttensortype('torch.CudaTensor')
   local x = torch.zeros(sz1, sz2)
   assert(x:sum() == 0)
   torch.setdefaulttensortype(t)
end

function test.ones()
   local sz1 = math.floor(torch.uniform(minsize,maxsize))
   local sz2 = math.floor(torch.uniform(minsize,maxsize))
   local t = torch.getdefaulttensortype()
   torch.setdefaulttensortype('torch.CudaTensor')
   local x = torch.ones(sz1, sz2)
   assert(x:sum() == x:nElement())
   torch.setdefaulttensortype(t)
end


function test.add()
   local sz1 = math.floor(torch.uniform(minsize,maxsize))
   local sz2 = math.floor(torch.uniform(minsize,maxsize))
   local x = torch.FloatTensor():rand(sz1, sz2)
   local y = torch.FloatTensor():rand(sz1, sz2)
   local z = torch.FloatTensor():rand(sz1, sz2)
   local v = torch.uniform()
   compareFloatAndCudaTensorArgs(x, 'add', z)
   compareFloatAndCudaTensorArgs(x, 'add', z, v)
   compareFloatAndCudaTensorArgs(x, 'add', y, z)
   compareFloatAndCudaTensorArgs(x, 'add', y, v, z)
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

function test.cdiv3()
   local sz1 = math.floor(torch.uniform(minsize,maxsize))
   local sz2 = math.floor(torch.uniform(minsize,maxsize))
   local x = torch.FloatTensor():rand(sz1, sz2)
   local y = torch.FloatTensor():rand(sz1, sz2)
   local z = torch.FloatTensor(sz1, sz2)
   compareFloatAndCudaTensorArgs(z, 'cdiv', x, y)
end

function test.addcmul()
   local sz1 = math.floor(torch.uniform(minsize,maxsize))
   local sz2 = math.floor(torch.uniform(minsize,maxsize))
   local x = torch.FloatTensor():rand(sz1, sz2)
   local y = torch.FloatTensor():rand(sz1, sz2)
   local z = torch.FloatTensor():rand(sz1, sz2)
   compareFloatAndCudaTensorArgs(x, 'addcmul', y, z)
   compareFloatAndCudaTensorArgs(x, 'addcmul', torch.uniform(), y, z)

   local r = torch.zeros(sz1, sz2)
   compareFloatAndCudaTensorArgs(r, 'addcmul', x, y, z)
   compareFloatAndCudaTensorArgs(r, 'addcmul', x, torch.uniform(), y, z)
end

function test.addcdiv()
   local sz1 = math.floor(torch.uniform(minsize,maxsize))
   local sz2 = math.floor(torch.uniform(minsize,maxsize))
   local x = torch.FloatTensor():rand(sz1, sz2)
   local y = torch.FloatTensor():rand(sz1, sz2)
   local z = torch.FloatTensor():rand(sz1, sz2)
   compareFloatAndCudaTensorArgs(x, 'addcdiv', y, z)
   compareFloatAndCudaTensorArgs(x, 'addcdiv', torch.uniform(), y, z)

   local r = torch.zeros(sz1, sz2)
   compareFloatAndCudaTensorArgs(r, 'addcdiv', x, y, z)
   compareFloatAndCudaTensorArgs(r, 'addcdiv', x, torch.uniform(), y, z)
end

function test.logicalValue()
   local sz1 = math.floor(torch.uniform(minsize,maxsize))
   local sz2 = math.floor(torch.uniform(minsize,maxsize))
   local x = torch.FloatTensor():rand(sz1, sz2)
   local y = torch.FloatTensor():rand(sz1, sz2)
   compareFloatAndCudaTensorArgs(x, 'gt', y, 0.3)
   compareFloatAndCuda(x, 'gt', 0.3)
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

function test.max()
   local sz1 = math.floor(torch.uniform(minsize,maxsize))
   local sz2 = math.floor(torch.uniform(minsize,maxsize))
   local x = torch.FloatTensor():rand(sz1, sz2)
   compareFloatAndCuda(x, 'max')
   compareFloatAndCuda(x, 'max', 1)
   compareFloatAndCuda(x, 'max', 2)
end

function test.min()
   local sz1 = math.floor(torch.uniform(minsize,maxsize))
   local sz2 = math.floor(torch.uniform(minsize,maxsize))
   local x = torch.FloatTensor():rand(sz1, sz2)
   compareFloatAndCuda(x, 'min')
   compareFloatAndCuda(x, 'min', 1)
   compareFloatAndCuda(x, 'min', 2)
end

function test.sum()
   local minsize = 10
   local maxsize = 20
   local sz1 = math.floor(torch.uniform(minsize,maxsize))
   local sz2 = math.floor(torch.uniform(minsize,maxsize))
   local x = torch.FloatTensor():rand(sz1, sz2)
   compareFloatAndCuda(x, 'sum')
   compareFloatAndCuda(x, 'sum', 1)
   compareFloatAndCuda(x, 'sum', 2)
end

function test.cumsum()
   local sz1 = math.floor(torch.uniform(minsize,maxsize))
   local sz2 = math.floor(torch.uniform(minsize,maxsize))
   local x = torch.FloatTensor():rand(sz1, sz2)
   compareFloatAndCuda(x, 'cumsum')
   compareFloatAndCuda(x, 'cumsum', 1)
   compareFloatAndCuda(x, 'cumsum', 2)
end

function test.prod()
   local minsize = 10
   local maxsize = 20
   local sz1 = math.floor(torch.uniform(minsize,maxsize))
   local sz2 = math.floor(torch.uniform(minsize,maxsize))
   local x = torch.FloatTensor():rand(sz1, sz2)
   compareFloatAndCuda(x, 'prod')
   compareFloatAndCuda(x, 'prod', 1)
   compareFloatAndCuda(x, 'prod', 2)
end

function test.cumprod()
   local sz1 = math.floor(torch.uniform(minsize,maxsize))
   local sz2 = math.floor(torch.uniform(minsize,maxsize))
   local x = torch.FloatTensor():rand(sz1, sz2)
   compareFloatAndCuda(x, 'cumprod')
   compareFloatAndCuda(x, 'cumprod', 1)
   compareFloatAndCuda(x, 'cumprod', 2)
end

function test.round()
   local sz1 = math.floor(torch.uniform(minsize,maxsize))
   local sz2 = math.floor(torch.uniform(minsize,maxsize))
   local x = torch.FloatTensor():rand(sz1, sz2)
   compareFloatAndCuda(x, 'round')
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

-- Test element-wise unary operators with both one and two arguments.
local function testUnary1(fn)
   local function test()
      local sz1 = math.floor(torch.uniform(minsize,maxsize))
      local sz2 = math.floor(torch.uniform(minsize,maxsize))
      local x = torch.FloatTensor():rand(sz1, sz2)
      compareFloatAndCudaTensorArgs(x, fn)
   end
   return test
end

local function testUnary2(fn)
   local function test()
      local sz1 = math.floor(torch.uniform(minsize,maxsize))
      local sz2 = math.floor(torch.uniform(minsize,maxsize))
      local x = torch.FloatTensor():rand(sz1, sz2)
      local y = torch.FloatTensor()
      compareFloatAndCudaTensorArgs(y, fn, x)
   end
   return test
end

for _,name in ipairs({"log", "log1p", "exp",
                      "cos", "acos", "cosh",
                      "sin", "asin", "sinh",
                      "tan", "atan", "tanh",
                      "sqrt",
                      "ceil", "floor",
                      "abs", "sign"}) do

   test[name .. "1"] = testUnary1(name)
   test[name .. "2"] = testUnary2(name)

end

function test.atan2(fn)
   local sz1 = math.floor(torch.uniform(minsize,maxsize))
   local sz2 = math.floor(torch.uniform(minsize,maxsize))
   local x = torch.FloatTensor():rand(sz1, sz2)
   local y = torch.FloatTensor():rand(sz1, sz2)
   local z = torch.FloatTensor()
   compareFloatAndCudaTensorArgs(z, 'atan2', x, y)
end

function test.pow1()
   local sz1 = math.floor(torch.uniform(minsize,maxsize))
   local sz2 = math.floor(torch.uniform(minsize,maxsize))
   local x = torch.FloatTensor():rand(sz1, sz2)
   local pow = torch.uniform(minvalue,maxvalue)
   compareFloatAndCudaTensorArgs(x, 'pow', pow)
end

function test.pow2()
   local sz1 = math.floor(torch.uniform(minsize,maxsize))
   local sz2 = math.floor(torch.uniform(minsize,maxsize))
   local x = torch.FloatTensor():rand(sz1, sz2)
   local y = torch.FloatTensor()
   local pow = torch.uniform(minvalue,maxvalue)
   compareFloatAndCudaTensorArgs(y, 'pow', x, pow)
end

function test.clamp1()
   local sz1 = math.floor(torch.uniform(minsize,maxsize))
   local sz2 = math.floor(torch.uniform(minsize,maxsize))
   local x = torch.FloatTensor():rand(sz1, sz2):mul(5):add(-2.5)
   local min_val = -1
   local max_val = 1
   x[1][1] = min_val - 1
   if sz2 >= 2 then
     x[1][2] = max_val + 1
   end
   compareFloatAndCudaTensorArgs(x, 'clamp', min_val, max_val)
end

function test.clamp2()
   local sz1 = math.floor(torch.uniform(minsize,maxsize))
   local sz2 = math.floor(torch.uniform(minsize,maxsize))
   local x = torch.FloatTensor():rand(sz1, sz2):mul(5):add(-2.5)
   local min_val = -1
   local max_val = 1
   x[1][1] = min_val - 1
   if sz2 >= 2 then
     x[1][2] = max_val + 1
   end
   local y = torch.FloatTensor():resizeAs(x)
   compareFloatAndCudaTensorArgs(y, 'clamp', x, min_val, max_val)
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

function test.addmv()
   --[[ Size ]]--
   local sizes = {
      {2,1},
      {1,2},
      {1,1},
      {3,4},
      {3,3},
      {15,18},
      {19,15}
   }
   for _, size in pairs(sizes) do
      local n, m = unpack(size)
      local c = torch.zeros(n)
      local a = torch.randn(n, m)
      local b = torch.randn(m)
      compareFloatAndCudaTensorArgs(c, 'addmv', torch.normal(), torch.normal(), a, b)
   end
end

function test.mv()
   --[[ Size ]]--
   local sizes = {
      {2,1},
      {1,2},
      {1,1},
      {3,4},
      {3,3},
      {15,18},
      {19,15}
   }
   for _, size in pairs(sizes) do
      local n, m = unpack(size)
      local c = torch.zeros(n)
      local a = torch.randn(n, m)
      local b = torch.randn(m)
      compareFloatAndCudaTensorArgs(c, 'mv', a, b)
   end
end

function test.addr()
   --[[ Size ]]--
   local sizes = {
      {2,1},
      {1,2},
      {1,1},
      {3,4},
      {3,3},
      {15,18},
      {19,15}
   }
   for _, size in pairs(sizes) do
      local n, m = unpack(size)
      local c = torch.zeros(n,m)
      local a = torch.randn(n)
      local b = torch.randn(m)
      compareFloatAndCudaTensorArgs(c, 'addr', torch.normal(), a, b)
   end
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
      compareFloatAndCudaTensorArgs(c, 'addmm', torch.normal(), torch.normal(), a, b)
   end
end

function test.mm()
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
      compareFloatAndCudaTensorArgs(c, 'mm', a, b)
   end
end

function test.ger()
   --[[ Size ]]--
   local sizes = {
      {16, 1},
      {1, 12},
      {24, 23},
      {1, 1},
      {33, 7},
      {12, 14},
      {10, 10},
   }
   for _, size in pairs(sizes) do
      local n, m = unpack(size)
      local c = torch.zeros(n, m)
      local a = torch.randn(n)
      local b = torch.randn(m)
      compareFloatAndCudaTensorArgs(c, 'ger', a, b)
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

-- Test random number generation.
local function checkIfUniformlyDistributed(t, min, max)
   tester:assertge(t:min(), min - 1e-6, "values are too low")
   tester:assertle(t:max(), max + 1e-6, "values are too high")
   tester:assertalmosteq(t:mean(), (min + max) / 2, 0.1, "mean is wrong")
end

function test.uniform()
   local sz1 = math.floor(torch.uniform(minsize,maxsize))
   local sz2 = math.floor(torch.uniform(minsize,maxsize))
   local min = torch.uniform()
   local max = min + torch.uniform()
   local t = torch.CudaTensor(sz1, sz2)

   t:uniform(min, max)
   checkIfUniformlyDistributed(t, min, max, tolerance)
end

function test.bernoulli()
   local sz1 = math.floor(torch.uniform(minsize,maxsize))
   local sz2 = math.floor(torch.uniform(minsize,maxsize))
   local p = torch.uniform()
   local t = torch.CudaTensor(sz1, sz2)

   t:bernoulli(p)
   tester:assertalmosteq(t:mean(), p, 0.1, "mean is not equal to p")
   local f = t:float()
   tester:assertTensorEq(f:eq(1):add(f:eq(0)):float(),
                         torch.FloatTensor(sz1, sz2):fill(1),
                         1e-6,
                         "each value must be either 0 or 1")
end

function test.normal()
   local sz1 = math.floor(torch.uniform(minsize,maxsize))
   local sz2 = math.floor(torch.uniform(minsize,maxsize))
   local mean, std = torch.uniform(), torch.uniform()
   local tolerance = 0.01
   local t = torch.CudaTensor(sz1, sz2)

   t:normal(mean, std)
   tester:assertalmosteq(t:mean(), mean, tolerance, "mean is wrong")
   tester:assertalmosteq(t:std(), std, tolerance, "standard deviation is wrong")
end

function test.logNormal()
   local sz1 = math.floor(torch.uniform(minsize,maxsize))
   local sz2 = math.floor(torch.uniform(minsize,maxsize))
   local mean, std = torch.uniform(), torch.uniform()
   local tolerance = 0.01
   local t = torch.CudaTensor(sz1, sz2)

   t:logNormal(mean, std)
   local logt = t:log()
   tester:assertalmosteq(logt:mean(), mean, tolerance, "mean is wrong")
   tester:assertalmosteq(logt:std(), std, tolerance, "standard deviation is wrong")
end

function test.geometric()
   local sz1 = math.floor(torch.uniform(minsize,maxsize))
   local sz2 = math.floor(torch.uniform(minsize,maxsize))
   local p = torch.uniform()
   local t = torch.CudaTensor(sz1, sz2)

   t:geometric(p)
   local u = torch.FloatTensor(sz1, sz2):fill(1) -
                 ((t:float() - 1) * math.log(p)):exp()
   checkIfUniformlyDistributed(u, 0, 1)
end

function test.exponential()
   local sz1 = math.floor(torch.uniform(minsize,maxsize))
   local sz2 = math.floor(torch.uniform(minsize,maxsize))
   local lambda = torch.uniform()
   local t = torch.CudaTensor(sz1, sz2)

   t:exponential(lambda)
   local u = torch.FloatTensor(sz1, sz2):fill(1) -
                 (t:float() * -lambda):exp()
   checkIfUniformlyDistributed(u, 0, 1)
end

function test.cauchy()
   local sz1 = math.floor(torch.uniform(minsize,maxsize))
   local sz2 = math.floor(torch.uniform(minsize,maxsize))
   local median, sigma = torch.uniform(), torch.uniform()
   local t = torch.CudaTensor(sz1, sz2)

   t:cauchy(median, sigma)
   local u = ((t:float() - median) / sigma):atan() / math.pi + 0.5
   checkIfUniformlyDistributed(u, 0, 1)
end

function test.random_seed()
   local sz1 = math.floor(torch.uniform(minsize,maxsize))
   local sz2 = math.floor(torch.uniform(minsize,maxsize))
   local mean, std = torch.uniform(), torch.uniform()
   local tolerance = 0.01
   local t = torch.CudaTensor(sz1, sz2)
   local u = torch.CudaTensor(sz1, sz2)

   local seed = cutorch.seed()
   t:normal(mean, std)
   cutorch.manualSeed(seed)
   u:normal(mean, std)
   tester:assertTensorEq(t:float(), u:float(), 1e-6, "values not equal after resetting the seed")
end

function test.restore_rng()
   local sz1 = math.floor(torch.uniform(minsize,maxsize))
   local sz2 = math.floor(torch.uniform(minsize,maxsize))
   local mean, std = torch.uniform(), torch.uniform()
   local tolerance = 0.01
   local t = torch.CudaTensor(sz1, sz2)
   local u = torch.CudaTensor(sz1, sz2)

   local seed = cutorch.seed()
   local rng = cutorch.getRNGState()
   t:normal(mean, std)
   -- Change the seed so we can check that restoring the RNG state also restores the seed.
   cutorch.manualSeed(seed + 123)
   cutorch.setRNGState(rng)
   u:normal(mean, std)
   tester:assertTensorEq(t:float(), u:float(), 1e-6, "values not equal after restoring the RNG state")
   tester:asserteq(cutorch.initialSeed(), seed, "seed was not restored")
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

if runtests then
   cutorch.test()
end
