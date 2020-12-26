local Helper = require('spec.helper.helper')
local Promise = require('promise')

local dummy = { dummy = 'dummy' } -- we fulfill or reject with this when we don't intend to test against it
local sentinel = { sentinel = 'sentinel' }
local other = { other = 'other' }

-- see https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise/all
describe('.all', function()
  it("will resolve when all of the input's promises have resolved, or if the input iterable contains no promises", function(done)
    async()

    local result1 = { result = 1 }
    local result2 = { result = 2 }
    local result3 = { result = 3 }
    local value1 = 42
    local value2 = "Hello!"
    local value3 = nil

    local promise1 = Promise.new()
    local promise2 = Promise.new()
    local promise3 = Promise.new()

    Helper.timeout(0.1, function()
      promise1:resolve(result1)
    end)

    Helper.timeout(0.15, function()
      promise2:resolve(result2)
    end)

    Helper.timeout(0.2, function()
      promise3:resolve(result3)
    end)

    Promise.all{promise1, promise2, promise3, value1, value2, value3}:next(function(results)
      assert.are_same({result1, result2, result3, value1, value2, value3}, results)
      done()
    end)
  end)

  it("is rejected when any promises are rejected, reject with this first rejection message / error", function(done)
    async()

    local result1 = { result = 1 }
    local result2 = { result = 2 }

    local promise1 = Promise.new()
    local promise2 = Promise.new()

    Helper.timeout(0.1, function()
      promise1:resolve(result1)
    end)

    Helper.timeout(0.15, function()
      promise2:reject(result2)
    end)

    Promise.all{promise1, promise2, promise3}:next(
      nil,
      function(reason)
        assert.are_equals(result2, reason)
        done()
      end
    )
  end)

  it("is fulfilled when no promises are provided", function(done)
    async()
    
    Promise.all():next(function()
      done()
    end)
  end)
end)

-- see https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise/allSettled
describe('.all_settled', function()
  it("resolves after all of the given promises have either fulfilled or rejected, with an array of objects that each describes the outcome of each promise", function(done)
    async()

    local result1 = { result = 1 }
    local result2 = { result = 2 }
    local result3 = { result = 3 }
    local value1 = 42
    local value2 = "Hello!"
    local value3 = nil

    local promise1 = Promise.new()
    local promise2 = Promise.new()
    local promise3 = Promise.new()

    Helper.timeout(0.1, function()
      promise1:reject(result1)
    end)

    Helper.timeout(0.15, function()
      promise2:resolve(result2)
    end)

    Helper.timeout(0.2, function()
      promise3:reject(result3)
    end)

    Promise.all_settled{n = 6, promise1, promise2, promise3, value1, value2, value3}:next(function(results)
      assert.are_same({
        { status = "rejected", reason = result1 },
        { status = "fulfilled", value = result2 },
        { status = "rejected", reason = result3 },
        { status = "fulfilled", value = value1 },
        { status = "fulfilled", value = value2 },
        { status = "fulfilled", value = value3 },
      }, results)
      done()
    end)
  end)

  it("is fulfilled when no promises are provided", function(done)
    async()
    
    Promise.all():next(function()
      done()
    end)
  end)
end)

-- see https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise/race
describe(".race", function()
  it("returns the first resolved promise", function(done)
    async()

    local promise1 = Promise.new()
    local promise2 = Promise.new()
    local promise3 = Promise.new()

    Helper.timeout(0.1, function()
      promise1:resolve(other)
    end)

    Helper.timeout(0.15, function()
      promise2:resolve(other)
    end)

    Helper.timeout(0.05, function()
      promise3:resolve(sentinel)
    end)

    Promise.race{promise1, promise2, promise3}:next(function(result)
      assert.are_equals(sentinel, result)
      done()
    end)
  end)

  it("fulfills or rejects as soon as one of the promises in an iterable fulfills or rejects, with the value or reason from that promise", function(done)
    async()

    local promise1 = Promise.new()
    local promise2 = Promise.new()

    Helper.timeout(0.1, function()
      promise1:reject(sentinel)
    end)

    Helper.timeout(0.2, function()
      promise2:resolve(other)
    end)

    local fulfillment = spy.new(function() end)
    local rejection = spy.new(function() end)

    Promise.race{promise1, promise2}:next(function(value)
      fulfillment()
    end):catch(function(reason)
      rejection()
      assert.are_equals(sentinel, reason)
    end):next(function()
      assert.spy(rejection).was_called()
      assert.spy(fulfillment).was_not_called()
      done()
    end)
  end)

  it("immediately resolved when non-promise value provided in list", function(done)
    async()

    local promise1 = Promise.new()
    local promise2 = Promise.new()
    local value1 = 42

    Helper.timeout(0.1, function()
      promise1:reject(sentinel)
    end)

    Helper.timeout(0.2, function()
      promise2:resolve(other)
    end)

    local fulfillment = spy.new(function() end)
    local rejection = spy.new(function() end)

    Promise.race{promise1, promise2, value1}:next(function(value)
      fulfillment()
      assert.are_equals(value, value1)
    end):catch(function(reason)
      rejection()
    end):next(function()
      assert.spy(fulfillment).was_called()
      assert.spy(rejection).was_not_called()
      done()
    end)
  end)
end)

-- see https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise/any
describe(".any", function()
  it("returns the first resolved promise", function(done)
    async()

    local promise1 = Promise.new()
    local promise2 = Promise.new()
    local promise3 = Promise.new()

    Helper.timeout(0.1, function()
      promise1:resolve(sentinel)
    end)

    Helper.timeout(0.15, function()
      promise2:resolve(other)
    end)

    Helper.timeout(0.05, function()
      promise3:reject(other)
    end)

    Promise.any{promise1, promise2, promise3}:next(function(result)
      assert.are_equals(sentinel, result)
      done()
    end)
  end)

  it("if all of the given promises are rejected, then the returned promise is rejected with an AggregateError", function(done)
    async()

    local promise1 = Promise.new()
    local promise2 = Promise.new()
    local promise3 = Promise.new()

    Helper.timeout(0.1, function()
      promise1:reject(other)
    end)

    Helper.timeout(0.2, function()
      promise2:reject(other)
    end)

    promise3:reject(other)

    local fulfillment = spy.new(function() end)
    local rejection = spy.new(function() end)

    Promise.any{promise1, promise2, promise3}:next(function(value)
      fulfillment()
    end):catch(function(reason)
      rejection()
    end):next(function()
      assert.spy(rejection).was_called()
      assert.spy(fulfillment).was_not_called()
      done()
    end)
  end)

  it("immediately resolved when non-promise value provided in list", function(done)
    async()

    local promise1 = Promise.new()
    local promise2 = Promise.new()
    local value1 = 42

    Helper.timeout(0.1, function()
      promise1:reject(sentinel)
    end)

    Helper.timeout(0.2, function()
      promise2:resolve(other)
    end)

    local fulfillment = spy.new(function() end)
    local rejection = spy.new(function() end)

    Promise.any{promise1, promise2, value1}:next(function(value)
      fulfillment()
      assert.are_equals(value, value1)
    end):catch(function(reason)
      rejection()
    end):next(function()
      assert.spy(fulfillment).was_called()
      assert.spy(rejection).was_not_called()
      done()
    end)
  end)
end)