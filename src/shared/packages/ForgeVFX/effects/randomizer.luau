local attr = require("../mod/attributes")

local lerp = require("../mod/lerp")
local tween = require("../mod/tween")
local types = require("../types")
local utility = require("../mod/utility")

local Bezier = require("../obj/Bezier")

local rng = Random.new()

local randomizer = {}

local function getBezier(params: string): Bezier.Bezier?
  local bezier = tween.bezier_cache[params]

  if not bezier then
    local success, points = pcall(function()
      return utility.deserializePath(params)
    end)

    if not success then
      return nil
    end

    bezier = Bezier.new(points, 0)
    tween.bezier_cache[params] = bezier
  end

  return bezier
end

local function sampleWeighted(bezier: Bezier.Bezier): number
  local t = rng:NextNumber()
  local weight = 1 - bezier:getEase(t).y

  return weight
end

function randomizer.emit(obj: RayValue, scope: types.scope, isAttribute: boolean)
  local target = utility.getTarget(obj)

  if not target then
    return
  end

  local name = obj.Name

  local startValue = attr.get(obj, "_START_VALUE", nil)
  local endValue = attr.get(obj, "_END_VALUE", nil)

  if startValue == nil or endValue == nil then
    return
  end

  local typeName = typeof(startValue)

  if typeName ~= typeof(endValue) then
    return
  end

  local weightCurve = attr.get(obj, "Weight_Curve", utility.linear_bezier)
  local bezier = getBezier(weightCurve)

  if not bezier then
    return
  end

  local originalValue

  if isAttribute then
    originalValue = attr.get(target, name, nil)
  else
    local ok, val = pcall(function()
      return target[name]
    end)

    if not ok then
      return
    end

    originalValue = val
  end

  local lfunc = lerp[typeName] or lerp.Other

  local alpha = sampleWeighted(bezier)
  local newValue = lfunc(startValue, endValue, alpha)

  local resetOnFinish = attr.get(obj, "ResetOnFinish", true)

  if isAttribute then
    attr.set(target, name, newValue)
  else
    target[name] = newValue
  end

  if resetOnFinish then
    -- reset on next frame (after the target effects are emitted)
    task.defer(function()
      if isAttribute then
        attr.set(target, name, originalValue)
      else
        target[name] = originalValue
      end
    end)
  end
end

return randomizer
