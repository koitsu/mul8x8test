-- mul8x8test.lua
--
-- Author: Jeremy Chadwick (koitsu) <jdc@koitsu.org>
--
-- Intended for use with Mesen (AppVeyor builds)
--
-- https://ci.appveyor.com/project/Sour/mesen/build/artifacts

-- RAM (ZP) locations for multiplier and multiplicand
-- These must match the locations in mul8x8test.asm!
zp_multiplier      = 0x0000
zp_multiplicand    = 0x0001
zp_ptr_str_algo    = 0x0005

-- Lua variables
multiplier   = 0
multiplicand = 0
cycles       = 0
algostring   = {}

function triggerFactorSave(address, value)
    local i      = 0
    local state  = emu.getState()
    local strptr = emu.readWord(zp_ptr_str_algo, emu.memType.cpuDebug, false)
    multiplier   = emu.read(zp_multiplier,   emu.memType.cpuDebug, false)
    multiplicand = emu.read(zp_multiplicand, emu.memType.cpuDebug, false)
    cycles       = state.cpu.cycleCount

    -- Copy algorithm string from ROM into a Lua array, excluding trailing NULL
    algostring = {}
    while (true)
    do
        local b = emu.read(strptr+i, emu.memType.cpuDebug, false)
        if b == 0x00 then
            break
        end
        i = i+1
        algostring[i] = string.char(b)
    end

    return
end

function triggerCountCycles(address, value)
    local state = emu.getState()
    local algo  = table.concat(algostring, "")

    -- Minus 4 due to the "sta triggerFactorSave"
    -- We don't subtract an additional 4 (for "sta triggerCountCycles") because
    -- on writes, callbacks get called *before* the instruction executes.
    total = state.cpu.cycleCount - cycles - 4

    -- emu.log(multiplier.."*"..multiplicand.." "..total)
    emu.log(algo.." "..total)
    return
end

emu.addMemoryCallback(triggerFactorSave,  emu.memCallbackType.cpuWrite, 0xFFF0, 0xFFF0)
emu.addMemoryCallback(triggerCountCycles, emu.memCallbackType.cpuWrite, 0xFFF1, 0xFFF1)
