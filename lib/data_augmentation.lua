require 'image'
local iproc = require 'iproc'

local data_augmentation = {}

local function pcacov(x)
   local mean = torch.mean(x, 1)
   local xm = x - torch.ger(torch.ones(x:size(1)), mean:squeeze())
   local c = torch.mm(xm:t(), xm)
   c:div(x:size(1) - 1)
   local ce, cv = torch.symeig(c, 'V')
   return ce, cv
end
function data_augmentation.color_noise(src, factor)
   factor = factor or 0.1
   local src, conversion = iproc.byte2float(src)
   local src_t = src:reshape(src:size(1), src:nElement() / src:size(1)):t():contiguous()
   local ce, cv = pcacov(src_t)
   local color_scale = torch.Tensor(3):uniform(1 / (1 + factor), 1 + factor)
   
   pca_space = torch.mm(src_t, cv):t():contiguous()
   for i = 1, 3 do
      pca_space[i]:mul(color_scale[i])
   end
   local dest = torch.mm(pca_space:t(), cv:t()):t():contiguous():resizeAs(src)
   dest[torch.lt(dest, 0.0)] = 0.0
   dest[torch.gt(dest, 1.0)] = 1.0

   if conversion then
      dest = iproc.float2byte(dest)
   end
   return dest
end
function data_augmentation.shift_1px(src)
   -- reducing the even/odd issue in nearest neighbor scaler.
   local direction = torch.random(1, 4)
   local x_shift = 0
   local y_shift = 0
   if direction == 1 then
      x_shift = 1
      y_shift = 0
   elseif direction == 2 then
      x_shift = 0
      y_shift = 1
   elseif direction == 3 then
      x_shift = 1
      y_shift = 1
   elseif flip == 4 then
      x_shift = 0
      y_shift = 0
   end
   local w = src:size(3) - x_shift
   local h = src:size(2) - y_shift
   w = w - (w % 4)
   h = h - (h % 4)
   local dest = iproc.crop(src, x_shift, y_shift, x_shift + w, y_shift + h)
   return dest
end
function data_augmentation.flip(src)
   local flip = torch.random(1, 4)
   local src, conversion = iproc.byte2float(src)
   local dest
   
   src = src:contiguous()
   if flip == 1 then
      dest = image.hflip(src)
   elseif flip == 2 then
      dest = image.vflip(src)
   elseif flip == 3 then
      dest = image.hflip(image.vflip(src))
   elseif flip == 4 then
      dest = src
   end
   if conversion then
      dest = iproc.float2byte(dest)
   end
   return dest
end
function data_augmentation.overlay(src, p)
   p = p or 0.25
   if torch.uniform() < p then
      local r = torch.uniform(0.2, 0.8)
      local src, conversion = iproc.byte2float(src)
      src = src:contiguous()
      local flip = data_augmentation.flip(src)
      flip:mul(r):add(src * (1.0 - r))
      if conversion then
	 flip = iproc.float2byte(flip)
      end
      return flip
   else
      return src
   end
end
return data_augmentation