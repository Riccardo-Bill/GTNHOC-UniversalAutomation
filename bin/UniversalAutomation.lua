--Some of the code is modified from RecursivePineapple's "auto-altar" that can be found at https://github.com/RecursivePineapple/auto-altar/tree/master?tab=LGPL-2.1-1-ov-file

local os = require("os")
local component = require("component")
local serialization = require("serialization")
local filesystem = require("filesystem")
local sides = require("sides")
local thread = require("thread")
local event = require("event")

local utils = require("UA.utils")
local config_utils = require("UA.config_utils")

local config = utils.load("/etc/UA.cfg") or {}

if config.on_high == nil then
    config.on_high = true
end

print("Universal Automation setup sequence")

local function print_address(name, address, target_type)
    local proxy = component.proxy(address or "")

    print(name .. " address: " .. (address or "nil") .. (proxy and (" (address refers to component of type '" .. proxy.type .. "')") or (address and " (address invalid - component not connected)" or "")))

    if proxy and target_type and proxy.type ~= target_type then
        print("Warning: component should be a " .. target_type)
    end
end

while true do
    ::start::

    local option = config_utils.get_option({
        "Exit without saving",
        "Show pending config",
        "Set LCR Redstone 1",
        "Set LCR Transposer 1",
        "Set LCR Redstone 2",
        "Set LRC Transposer 2",
        "Save and exit"
    })

    if option == 1 then
        break        
    elseif option == 2 then

        print("TODO Peniding")
        print()

    elseif option == 3 then
        config_utils.select_component("redstone", config, "redstone1")
    elseif option == 4 then
        config_utils.select_component("transposer", config, "transposer1")
    elseif option == 5 then
        config_utils.select_component("redstone", config, "redstone2")
    elseif option == 6 then
        config_utils.select_component("transposer", config, "transposer2")
    elseif option == 7 then
        if filesystem.exists("/etc/UA-altar.cfg") then
            filesystem.rename("/etc/UA-altar.cfg", "/etc/UA-backup.cfg")
            print("Backed up old config to /etc/UA-backup.cfg")
        end

        utils.save("/etc/UA.cfg", config)
        print("Saved altar config")
        break
    end
end

print ("Setup done, starting Universal Automation")

if config == nil then
    print("error: could not load config")
    return
end

local function check_address(addr, name)
    if addr == nil then
        print("error: " .. name .. " address was not set")
        return false
    end
    return true
end

local tpose_sides = {}

local function check_tpose_side(transposer, side, name)
    local tpose = tpose_sides[transposer.address] or {}
    tpose_sides[transposer.address] = tpose

    if transposer.getInventoryName(side) == nil then
        print("error: '" .. name .. "' no inventory is present at that side")
        return false
    end

    tpose[side] = name

    return true
end

if not check_address(config.transposer1, "transposer 1") then return end
if not check_address(config.transposer2, "transposer 2") then return end
if not check_address(config.redstone1, "redstone 1") then return end
if not check_address(config.redstone2, "redstone 2") then return end

local transposer1 = component.proxy(config.transposer1)
local transposer2 = component.proxy(config.transposer2)
local redstone1 = component.proxy(config.redstone1)
local redstone2 = component.proxy(config.redstone2)

local input_side = sides.up
local staging_side = sides.west
local output_side = sides.down

if not check_tpose_side(transposer1, input_side, "input 1") then return end
if not check_tpose_side(transposer2, input_side, "input 2") then return end
if not check_tpose_side(transposer1, staging_side, "staging 1") then return end
if not check_tpose_side(transposer2, staging_side, "staging 2") then return end
if not check_tpose_side(transposer1, output_side, "output 1") then return end
if not check_tpose_side(transposer2, output_side, "output 2") then return end

local status = {0, 0}

local function move_staging(trans, name)
    trans.transferItem(staging_side, input_side, 1, 1, 1)
    print(name .. " stating recipe")
end

local function check_redstone(red)
    if red.getInput(sides.up) == 0 then return false
    else return true end
end

local function move_out(trans, name)
    trans.transferItem(input_side, output_side, 1, 7, 1)
    print(name .. " finishing recipe")
end

local function check_done(trans, name)
    if not trans.getStackInSlot(output_side, 7) and not trans.getStackInSlot(output_side, 1) and not trans.getStackInSlot(input_side, 7) then
      print(name .. " done output")
      return true
    else return false end
end

local function main()
    while true do
        if status[1] == 0 and transposer1.getStackInSlot(staging_side, 1) then
            move_staging(transposer1, "LCR 1")
            status[1] = 1
        end
        if status[2] == 0 and transposer2.getStackInSlot(staging_side, 1) then
            move_staging(transposer2, "LCR 2")
            status[2] = 1
        end
        os.sleep(1)
        if status[1] == 1 and not check_redstone(redstone1) then
            move_out(transposer1, "LCR 1")
            status[1] = 2
        end
        if status[2] == 1 and not check_redstone(redstone2) then
            move_out(transposer2, "LCR 2")
            status[2] = 2
        end
        if status[1] == 2 and check_done(transposer1, "LCR 1") then status[1] = 0 end
        if status[2] == 2 and check_done(transposer2, "LCR 2") then status[2] = 0 end
    end
end
--[[
local cleanup_thread = thread.create(function()
  event.pull("interrupted")
  print("cleaning up resources")
end)
--]]
local main_thread = thread.create(main())
--[[
thread.waitForAny({cleanup_thread, main_thread})
os.exit(0)
--]]