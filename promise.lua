-- Port of https://github.com/rhysbrettbowen/promise_impl/blob/master/promise.js
-- and https://github.com/rhysbrettbowen/Aplus
--
local pack = table.pack or _G.pack

local queue = {}

local State = {
  PENDING   = 'pending',
  FULFILLED = 'fulfilled',
  REJECTED  = 'rejected',
}

local passthrough = function(x) return x end
local errorthrough = function(x) error(x) end

local function callable_table(callback)
  local mt = getmetatable(callback)
  return type(mt) == 'table' and type(mt.__call) == 'function'
end

local function is_callable(value)
  local t = type(value)
  return t == 'function' or (t == 'table' and callable_table(value))
end

local transition, resolve, run

local Promise = {
  is_promise = true,
  state = State.PENDING
}
Promise.mt = { __index = Promise }

local do_async = function(callback)
  if Promise.async then
    Promise.async(callback)
  else
    table.insert(queue, callback)
  end
end

local reject = function(promise, reason)
  transition(promise, State.REJECTED, reason)
end

local fulfill = function(promise, value)
  transition(promise, State.FULFILLED, value)
end

transition = function(promise, state, value)
  if promise.state == state
    or promise.state ~= State.PENDING
    or ( state ~= State.FULFILLED and state ~= State.REJECTED )
  then
    return
  end

  promise.state = state
  promise.value = value
  run(promise)
end

function Promise:next(on_fulfilled, on_rejected)
  local promise = Promise.new()

  table.insert(self.queue, {
    fulfill = is_callable(on_fulfilled) and on_fulfilled or nil,
    reject = is_callable(on_rejected) and on_rejected or nil,
    promise = promise
  })

  run(self)

  return promise
end

resolve = function(promise, x)
  if promise == x then
    reject(promise, 'TypeError: cannot resolve a promise with itself')
    return
  end
  
  local x_type = type(x)

  if x_type ~= 'table' then
    fulfill(promise, x)
    return
  end
  
  -- x is a promise in the current implementation
  if x.is_promise then 
    -- 2.3.2.1 if x is pending, resolve or reject this promise after completion
    if x.state == State.PENDING then
      x:next(
        function(value)
          resolve(promise, value)
        end,
        function(reason)
          reject(promise, reason)
        end
      )
      return
    end
    -- if x is not pending, transition promise to x's state and value
    transition(promise, x.state, x.value)
    return
  end

  local called = false
  -- 2.3.3.1. Catches errors thrown by __index metatable
  local success, reason = pcall(function()
    local next = x.next
    if is_callable(next) then
      next(
        x,
        function(y) 
          if not called then
            resolve(promise, y)
            called = true
          end
        end,
        function(r)
          if not called then
            reject(promise, r)
            called = true
          end
        end
      )
    else
      fulfill(promise, x)
    end
  end)

  if not success then
    if not called then
      reject(promise, reason)
    end
  end
end

run = function(promise)
  if promise.state == State.PENDING then return end

  do_async(function()
    -- drain promise.queue while allowing pushes from within callbacks
    local q = promise.queue
    local i = 0
    while i < #q do
      i = i + 1
      local obj = q[i]
      local success, result = pcall(function()
        local success = obj.fulfill or passthrough
        local failure = obj.reject or errorthrough
        local callback = promise.state == State.FULFILLED and success or failure
        return callback(promise.value)
      end)

      if not success then
        reject(obj.promise, result)
      else
        resolve(obj.promise, result)
      end
    end
    for j = 1, i do
      q[j] = nil
    end
  end)
end

function Promise.new(callback)
  local instance = {
    queue = {}
  }
  setmetatable(instance, Promise.mt)

  if callback then
    callback(
      function(value)
        resolve(instance, value)
      end,
      function(reason)
        reject(instance, reason)
      end
    )
  end

  return instance
end

function Promise:catch(callback)
  return self:next(nil, callback)
end

function Promise:resolve(value)
  fulfill(self, value)
end

function Promise:reject(reason)
  reject(self, reason)
end

function Promise.update()
  while true do
    local async = table.remove(queue, 1)

    if not async then
      break
    end

    async()
  end
end

-- resolve when all promises complete
-- see https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise/all
function Promise.all(...)
  local promises = pack(...)
  local results = {}
  local state = State.FULFILLED
  local remaining = promises.n

  local promise = Promise.new()

  local check_finished = function()
    if remaining > 0 then
      return
    end
    transition(promise, state, results)
  end

  for i = 1, promises.n do
    local p = promises[i]
    if type(p) == "table" and p.is_promise then
      p:next(
        function(value)
          results[i] = value
          remaining = remaining - 1
          check_finished()
        end,
        function(reason)
          reject(promise, reason)
        end
      )
    else
      results[i] = p
      remaining = remaining - 1
    end
  end

  check_finished()

  return promise
end

-- resolves after all of the given promises have either fulfilled or rejected, 
-- with an array of objects that each describes the outcome of each promise.
-- see https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise/allSettled
function Promise.all_settled(...)
  local promises = pack(...)
  local results = {}
  local remaining = promises.n

  local promise = Promise.new()
  if remaining <= 0 then
    fulfill(promise, results)
    return promise
  end

  local check_finished = function()
    if remaining > 0 then
      return
    end
    fulfill(promise, results)
  end

  for i = 1, promises.n do
    local p = promises[i]
    if type(p) == "table" and p.is_promise then
      p:next(
        function(value)
          results[i] = { status = State.FULFILLED, value = value }
          remaining = remaining - 1
          check_finished()
        end,
        function(reason)
          results[i] = { status = State.REJECTED, reason = reason }
          remaining = remaining - 1
          check_finished()
        end
      )
    else
      results[i] = { status = State.FULFILLED, value = p }
      remaining = remaining - 1
    end
  end

  check_finished()

  return promise
end

-- resolve when any promises complete, reject when all promises are rejected
-- see https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise/any
function Promise.any(...)
  local promises = pack(...)
  local state = State.FULFILLED
  local remaining = promises.n

  local promise = Promise.new()

  for i = 1, promises.n do
    local p = promises[i]
    if type(p) == "table" and p.is_promise then
      p:next(
        function(value)
          fulfill(promise, value)
        end,
        function(reason)
          remaining = remaining - 1

          if remaining <= 0 then
            reject(promise, "AggregateError: All promises were rejected")
          end
        end
      )
    else
      -- resolve immediately if a non-promise provided
      fulfill(promise, p)
      break
    end
  end

  return promise
end

-- returns a promise that fulfills or rejects as soon as one of the promises in an iterable fulfills or rejects, 
-- with the value or reason from that promise
-- see https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise/race
function Promise.race(...)
  local promises = pack(...)
  local promise = Promise.new()

  local success = function(value)
    promise:resolve(value)
  end

  local fail = function(reason)
    promise:reject(reason)
  end

  for i = 1, promises.n do
    local p = promises[i]
    if type(p) == "table" and p.is_promise then
      p:next(success, fail)
    else
      -- resolve immediately if a non-promise provided
      promise:resolve(p)
      break
    end
  end

  return promise
end

return Promise
