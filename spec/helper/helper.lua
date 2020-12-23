local Promise = require('promise')
local ev = require('busted.loop.default')

Promise.async = function(callback)
  ev.create_timer(0, callback)
end

local Helper = {}

Helper.timeout = function(time, callback)
  assert(time, 'No timeout provided')
  assert(callback, 'No callback provided')
  ev.create_timer(time, callback)
end

--generate a pre-resolved promise
Helper.resolved = function(value)
  return Promise.new(function(res)
    res(value)
  end)
end

--generate a pre-rejected promise
Helper.rejected = function(reason)
  return Promise.new(function(res, rej)
    rej(reason)
  end)
end

Helper.test_fulfilled = function(it, value, test, name_suffix)
  name_suffix = name_suffix or ""
  it("already-fulfilled" .. name_suffix, function(done)
    test(Helper.resolved(value), done)
  end)

  it("immediately-fulfilled" .. name_suffix, function(done)
    local p = Promise.new()
    test(p, done)
    p:resolve(value)
  end)

  it("eventually-fulfilled" .. name_suffix, function(done)
    local p = Promise.new()
    test(p, done)
    Helper.timeout(0.05, function()
      p:resolve(value)
    end)
  end)
end

Helper.test_rejected = function(it, reason, test, name_suffix)
  name_suffix = name_suffix or ""
  it("already-rejected" .. name_suffix, function(done)
    test(Helper.rejected(reason), done)
  end)

  it("immediately-rejected" .. name_suffix, function(done)
    local p = Promise.new()
    test(p, done)
    p:reject(reason)
  end)

  it("eventually-rejected" .. name_suffix, function(done)
    local p = Promise.new()
    test(p, done)
    Helper.timeout(0.05, function()
      p:reject(reason)
    end)
  end)
end

return Helper
