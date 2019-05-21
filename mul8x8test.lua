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

-- Lua variables
multiplier   = 0
multiplicand = 0
cycles       = 0

function triggerFactorSave(address, value)
    local state  = emu.getState()
    multiplier   = emu.read(zp_multiplier,   emu.memType.cpuDebug, false)
    multiplicand = emu.read(zp_multiplicand, emu.memType.cpuDebug, false)
    cycles       = state.cpu.cycleCount
    return
end

function triggerCountCycles(address, value)
    local state = emu.getState()

    -- Minus 4 due to the "sta triggerFactorSave"
    -- We don't subtract an additional 4 (for "sta triggerCountCycles") because
    -- on writes, callbacks get called *before* the instruction executes.
    total = state.cpu.cycleCount - cycles - 4

    -- emu.log(multiplier.."*"..multiplicand.." "..total)
    emu.log(total)
    return
end

emu.addMemoryCallback(triggerFactorSave,  emu.memCallbackType.cpuWrite, 0xFFF0, 0xFFF0)
emu.addMemoryCallback(triggerCountCycles, emu.memCallbackType.cpuWrite, 0xFFF1, 0xFFF1)
