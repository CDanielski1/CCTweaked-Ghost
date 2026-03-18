-- ================================================================
--  GHOST - Ambient Server Presence
--  CC: Tweaked + Advanced Peripherals (ATM10 / similar)
--  Requires: Chat Box + Player Detector peripherals
-- ================================================================
--  Place both peripherals adjacent to (or wired to) a computer.
--  Copy this file onto the computer as "ghost.lua" and run it,
--  or rename to "startup.lua" for automatic start on boot.
--
--  The ghost only speaks when exactly ONE player is online.
--  Messages are sent privately via sendMessageToPlayer so only
--  the target sees them — nobody else will ever witness it.
-- ================================================================

-- ────────────────────────────────────────────
--  CONFIGURATION
-- ────────────────────────────────────────────

local CONFIG = {
    -- How the ghost appears in chat
    -- "&7" prefix hides the [AP] tag; empty brackets avoids extra text
    ghostPrefix       = "&7",
    ghostBrackets     = "",
    ghostBracketColor = "",
    -- Messages are always whispered (sendMessageToPlayer) so only the
    -- target sees them. This cannot be disabled — the ghost is a private haunting.

    -- "&7&o" = gray italic text for the message body
    -- AP converts & codes to Minecraft formatting codes
    formatPrefix = "&7&o",

    -- Timing (seconds)
    awakeningDelay    = {60, 150},  -- warm-up before ghost starts (min 60s for modpack loading)
    globalCooldown    = {60, 180},  -- min time between any two messages
    ambientInterval   = {300, 1800},-- range for unprompted ambient messages

    -- Response delay ranges per trigger type
    chatDelay         = {20, 150},
    dimensionDelay    = {10, 90},
    joinDelay         = {60, 180},  -- min 60s for modpack loading, max 3min so player still correlates
    interruptedDelay  = {2, 8},    -- very short: last words before going silent
    becomesAloneDelay = {30, 120}, -- moderate: someone just left

    -- Base activation chances (0.0 - 1.0)
    chatChance        = 0.22,
    dimensionChance   = 0.32,
    joinChance        = 0.38,
    ambientChance     = 0.20,
    interruptedChance = 0.30,      -- chance to say something when another player joins
    becomesAloneChance = 0.35,     -- chance to say something when player becomes alone
    nameChance        = 0.25,  -- chance to insert player name

    -- Escalation: trigger probability increases linearly over 6 hours
    -- At t=0 chance multiplier is 1.0, at t=6h it is 1.2 (20% increase)
    escalationRampTime  = 21600, -- 6 hours in seconds
    escalationMaxBoost  = 0.20,  -- +20% over the ramp period

    -- Message history (no repeat to same player within this window)
    historyExpiry     = 21600, -- 6 hours in seconds
    historyFile       = ".ghost_history",

    -- Safety limits
    selfGuardTime     = 3,    -- seconds to ignore chat after sending
    pollInterval      = 45,   -- seconds between player count polls
    silenceChance     = 0.10, -- chance to enter voluntary silence window
    silenceDuration   = {180, 600},

    -- Sensor polling intervals (seconds)
    sensorPollInterval = 8,   -- player health/position polls
    envPollInterval    = 45,  -- weather/moon/time polls

    -- Health thresholds (fraction of max health)
    healthLowThreshold      = 0.50,  -- <= 50% triggers low-health message
    healthCriticalThreshold = 0.25,  -- <= 25% triggers critical message
    healthDamageDelta       = 0.30,  -- 30%+ drop in one poll = big-damage event

    -- Sensor trigger chances
    sensorHealthLowChance   = 0.40,
    sensorHealthCritChance  = 0.65,
    sensorBigDamageChance   = 0.55,
    sensorUnderwaterChance  = 0.40,
    sensorUndergroundChance = 0.25,
    sensorDeepUnderChance   = 0.45,
    sensorStormChance       = 0.30,
    sensorThunderChance     = 0.25,
    sensorMoonChance        = 0.40,
    sensorNightChance       = 0.20,
    sensorMidnightChance    = 0.30,
    sensorDawnChance        = 0.20,

    -- Per-trigger cooldowns (seconds) — prevents repeat spam
    sensorHealthLowCD   = 300,
    sensorHealthCritCD  = 90,
    sensorBigDamageCD   = 60,
    sensorUnderwaterCD  = 180,
    sensorUndergroundCD = 600,
    sensorDeepUnderCD   = 600,
    sensorStormCD       = 900,
    sensorThunderCD     = 300,
    sensorMoonCD        = 3600,
    sensorNightCD       = 900,
    sensorMidnightCD    = 3600,
    sensorDawnCD        = 3600,

    -- Y-level thresholds (1.20+ world: bedrock at -64, sea level 63)
    yUnderground = 20,   -- below this = clearly in caves
    yDeep        = -40,  -- below this = deep dark territory
    yHighUp      = 200,  -- above this = very high up

    -- Respawn detection
    sensorRespawnChance = 0.70,
    sensorRespawnCD     = 30,

    -- High altitude
    sensorHighUpChance  = 0.30,
    sensorHighUpCD      = 600,

    -- AFK / stillness detection
    afkPollsRequired    = 4,    -- consecutive still polls before AFK (4 * 8s = 32s)
    sensorAfkChance     = 0.30,
    sensorAfkCD         = 600,  -- 10 minutes between AFK messages

    -- Movement speed
    sensorSpeedChance   = 0.35,
    sensorSpeedCD       = 300,
    speedThreshold      = 40,   -- blocks moved in one poll = very fast (elytra/teleport)

    -- Sneaking
    sensorSneakChance   = 0.25,
    sensorSneakCD       = 600,

    -- Look direction (yaw spin detection)
    sensorSpinChance    = 0.45,
    sensorSpinCD        = 180,
    yawSpinThreshold    = 120,  -- degrees of yaw change in one poll = looking around

    -- Pitch detection (looking up / looking down)
    sensorPitchChance   = 0.30,
    sensorPitchCD       = 300,
    pitchUpThreshold    = -60,  -- pitch below this = staring at sky/ceiling
    pitchDownThreshold  = 60,   -- pitch above this = staring at ground/hole

    -- Reaction chain: ghost notices physical reactions to its own messages
    reactionWindow      = 16,   -- seconds after sending to watch for reactions
    reactionSpinBoost   = 0.70, -- boosted chance when spin is a reaction to ghost

    -- Long session messages (ambient variant after 2 hours)
    longSessionTime     = 7200,

    -- Coordinate leak: tiny chance per ambient cycle to send player coords
    coordChance         = 0.04,

    -- Stutter: chance to send "..." before a message
    stutterChance       = 0.05,

    -- Cross-session persistence
    sessionFile         = ".ghost_session",
    sessionExpiry       = 172800,  -- 48 hours: older sessions are forgotten

    -- Chat silence detection
    chatSilenceCount    = 3,    -- min messages before silence is notable
    chatSilenceTime     = 600,  -- seconds of quiet after chatting to trigger

    -- Testing mode: overrides normal behavior for development
    -- Set testMode = true and testPlayer = "YourName" to test
    -- Ghost targets ONLY testPlayer, ignores player count requirement,
    -- and all messages are whispered to testPlayer only
    testMode   = false,
    testPlayer = "FugitiveAlias",

    debug = false,
}

-- ────────────────────────────────────────────
--  PERIPHERALS
-- ────────────────────────────────────────────

local chatBox  = peripheral.find("chatBox") or peripheral.find("chat_box")
local detector = peripheral.find("playerDetector") or peripheral.find("player_detector") or peripheral.find("player_detector")

if not chatBox then
    printError("No Chat Box found. Attach one and restart.")
    return
end
if not detector then
    printError("No Player Detector found. Attach one and restart.")
    return
end

local envDetector = peripheral.find("environmentDetector") or peripheral.find("environment_detector") or peripheral.find("environment_detector")
-- optional — ghost degrades gracefully without it

-- ────────────────────────────────────────────
--  STATE
-- ────────────────────────────────────────────

local STATE_DORMANT   = 0
local STATE_AWAKENING = 1
local STATE_ACTIVE    = 2
local STATE_SILENCE   = 3

local state = {
    phase           = STATE_DORMANT,
    targetPlayer    = nil,
    sessionStart    = 0,
    messagesSent    = 0,
    lastMessageTime = 0,
    lastTriggerType = nil,
    selfGuardUntil  = 0,
    onlinePlayers   = {},
    usedMessages    = {},
    chatCount       = 0,
    lastChatTime    = 0,
    sessionMemory   = {
        dimensionsVisited = {},
        deaths            = 0,
    },
}

local pendingTimers  = {}  -- timerID -> {message, target, triggerType}
local awakeningTimer = nil
local ambientTimer   = nil
local pollTimer      = nil
local silenceTimer   = nil
local sensorTimer    = nil
local envTimer       = nil
local cooldownUntil  = 0

local sensorState    = {}  -- populated in activate()

local lastSession    = nil   -- loaded from .ghost_session at activation

-- Standby intelligence: the ghost watches even while dormant (2+ players online)
local standbyMemory = {
    chatSnippets   = {},  -- {player=str, word=str}[] from chat overheard while dormant
    lastLeftPlayer = nil, -- who just left, causing the target to be alone
    dormantSince   = 0,   -- when the ghost last went dormant
}

-- ────────────────────────────────────────────
--  DIMENSION MAP
-- ────────────────────────────────────────────

local DIMENSION_MAP = {
    ["minecraft:overworld"]  = "overworld",
    ["minecraft:the_nether"] = "nether",
    ["minecraft:the_end"]    = "end",
}

local function dimName(raw)
    if not raw then return "unknown" end
    raw = tostring(raw):lower()
    for k, v in pairs(DIMENSION_MAP) do
        if raw:find(k, 1, true) then return v end
    end
    if raw:find("nether") then return "nether" end
    -- Match "end" only precisely to avoid false positives on
    -- dimensions like "modname:enderscape" or "slender:slenderlands"
    if raw:find("the_end") or raw:match(":end$") or raw == "end" then
        return "end"
    end
    return "other"
end

-- ────────────────────────────────────────────
--  MESSAGE POOLS
-- ────────────────────────────────────────────
-- Format: {escalation_level, "text"}
-- {name} placeholder = player name (inserted probabilistically)
-- Escalation levels: 1=subtle, 2=aware, 3=personal, 4=threatening, 5=unhinged

local MSG = {}

MSG.ambient = {
    -- Level 1: fragments — could be glitch, could be nothing
    {1, "..."},
    {1, "hm"},
    {1, "wait"},
    {1, "nevermind"},
    {1, "no"},
    -- Level 2: something is aware of the world
    {2, "thought i heard something"},
    {2, "its quiet"},
    {2, "something feels off"},
    {2, "the light changed for a second"},
    {2, "did something just move"},
    {2, "i keep losing count"},
    {2, "the air feels heavy"},
    {2, "this place used to be different"},
    {2, "that shadow wasnt there before"},
    {2, "i remember this spot"},
    {2, "the fog used to be thicker"},
    {2, "have you always lived here"},
    -- Level 3: directly aware of the player
    {3, "you left your door open"},
    {3, "the torches wont help"},
    {3, "something moved behind you"},
    {3, "youve been standing still for a while"},
    {3, "how long have you been here"},
    {3, "one of your animals is gone"},
    {3, "something moved in the other room"},
    {3, "somethings different about this place"},
    {3, "i counted the doors"},
    {3, "one of your signs says something different"},
    {3, "did you always have that many windows"},
    {3, "one of your chests has been opened"},
    {3, "the path looks shorter than it used to"},
    {3, "your crops grew while you werent looking"},
    -- Level 4: knows things it shouldnt
    {4, "dont move"},
    {4, "{name}"},
    {4, "behind you"},
    {4, "look up"},
    {4, "youve been here too long"},
    {4, "its getting closer"},
    {4, "i can see you"},
    {4, "that tunnel wasnt there before"},
    {4, "i removed something"},
    {4, "did you place that block"},
    {4, "check the room behind you"},
    {4, "one of your walls has a hole in it"},
    {4, "look at your ceiling"},
    {4, "your bed moved"},
    {4, "the ladder goes one rung deeper now"},
    -- Level 5: something is wrong
    {5, "im right here"},
    {5, "dont turn around"},
    {5, "the ground sounds hollow where youre standing"},
    {5, "i tried to warn you"},
    {5, "its too late to leave"},
    {5, "you can feel me cant you"},
    {5, "something where you sleep is different now"},
    {5, "they removed me from the patch notes"},
    {5, "i built something while you were gone"},
    {5, "there are more doors than there used to be"},
    {5, "the tunnel under here goes deeper than you dug"},
    {5, "your world seed changed"},
    {5, "the save file knows my name"},
    {5, "i added a room to your house"},
}

MSG.joins_alone = {
    {1, "hm"},
    {1, "oh"},
    {2, "youre back"},
    {2, "there you are"},
    {2, "i remember you"},
    {2, "youve been gone a while"},
    {2, "its been quiet without you"},
    {2, "there you are {name}"},
    {3, "i knew youd come back"},
    {3, "finally"},
    {3, "you left so suddenly last time"},
    {3, "everything is where you left it"},
    {4, "i was waiting {name}"},
    {4, "welcome back {name}"},
    {4, "i kept it the same for you"},
    {4, "i had time to look around while you were gone"},
    {5, "i knew you would"},
    {5, "you cant stay away can you"},
}

-- Another player joins — ghost's last words before going dormant
MSG.interrupted = {
    {2, "..."},
    {2, "nevermind"},
    {3, "not now"},
    {3, "another time"},
    {4, "shh"},
    {4, "not in front of them"},
    {4, "dont tell them about me"},
    {5, "this stays between us"},
    {5, "ill be back when theyre gone"},
}

-- A player becomes the sole player on the server
-- Different from joins_alone: this fires when others LEAVE, not when target joins
MSG.becomes_alone = {
    {1, "..."},
    {2, "quiet now"},
    {2, "they left"},
    {2, "just us"},
    {2, "gone"},
    {3, "finally"},
    {3, "good"},
    {3, "now then"},
    {4, "{name}"},
    {4, "alone again"},
    {4, "i waited"},
    {5, "ive been patient"},
    {5, "where were we"},
}

MSG.enter_nether = {
    {2, "the nether remembers"},
    {2, "something followed you in"},
    {2, "the portal flickered"},
    {2, "it knows youre here now"},
    {2, "the air tastes wrong here"},
    {2, "this place is older than you think"},
    {3, "they can smell you"},
    {3, "the portal wont be there when you go back"},
    {3, "dont stay too long"},
    {4, "youre not the first to go in"},
    {4, "the ground is breathing"},
    {5, "the nether is alive and it noticed you"},
    {5, "you dont hear the screaming do you"},
}

MSG.leave_nether = {
    {1, "youre back"},
    {2, "you look different"},
    {2, "did you find what you were looking for"},
    {2, "something came through with you"},
    {2, "how long were you in there"},
    {3, "you brought something back with you"},
    {3, "you smell like sulfur"},
    {3, "part of you is still in there"},
    {4, "the portal stayed open too long"},
    {4, "check behind you"},
    {4, "i moved things while you were in there"},
    {5, "you came back wrong"},
}

MSG.enter_end = {
    {2, "no"},
    {2, "the void is patient"},
    {2, "dont look down"},
    {2, "it sees you"},
    {2, "you shouldnt be here"},
    {2, "the eyes are watching"},
    {3, "{name}"},
    {3, "you dont understand what lives here"},
    {4, "theyre already looking at you"},
    {4, "everything here is alive"},
    {4, "the void remembers your name"},
    {5, "youre not coming back the same"},
    {5, "the end doesnt let you leave it lets you think you left"},
}

MSG.leave_end = {
    {1, "you made it"},
    {2, "what did you see"},
    {2, "the sky looks different now doesnt it"},
    {2, "you were gone longer than you think"},
    {3, "something came through with you"},
    {3, "youre not the same person who went in"},
    {4, "it let you leave"},
    {4, "what did it show you"},
    {4, "dont go back"},
    {4, "things have moved since you left"},
    {5, "you left something behind in the void"},
    {5, "the end doesnt forget"},
}

MSG.dimension_other = {
    {2, "where are you going"},
    {2, "i felt that"},
    {2, "the world shifted"},
    {3, "that place isnt right"},
    {4, "that place isnt on any map"},
    {5, "you went somewhere i cant see"},
}

-- Session memory callback messages (reference earlier events)
MSG.memory = {
    nether = {
        {3, "the nether changed something in you earlier"},
        {4, "i could feel it when you went to the nether"},
        {5, "you still smell like the nether"},
    },
    end_dim = {
        {3, "the end left something on you"},
        {4, "ever since you went to the end something has been different"},
    },
    death = {
        {3, "you died earlier didnt you"},
        {4, "i watched you die"},
        {4, "dying doesnt bother you anymore does it"},
        {5, "how many times have you died here"},
    },
    deep = {
        {3, "you went deep earlier"},
        {4, "you brought something up from the deep dark"},
        {5, "the bedrock remembers your footsteps"},
    },
    underwater = {
        {3, "the water changed you"},
        {4, "you were under for a long time earlier"},
    },
    high_up = {
        {3, "you were up high earlier"},
        {4, "did you see anything from up there"},
    },
}

-- ────────────────────────────────────────────
--  SENSOR-DRIVEN MESSAGE POOLS
-- ────────────────────────────────────────────

MSG.health_low = {
    {2, "youre hurt"},
    {3, "something got you"},
    {3, "i can tell"},
    {3, "youre bleeding"},
    {4, "i can feel it when you take damage"},
    {4, "keep going"},
    {5, "youre not going to last like this"},
}

MSG.health_critical = {
    {3, "stop"},
    {3, "one more hit"},
    {4, "youre almost gone"},
    {4, "i can feel you slipping"},
    {4, "{name}"},
    {5, "not yet"},
    {5, "you dont get to die yet"},
}

MSG.big_damage = {
    {2, "oh"},
    {2, "what was that"},
    {3, "i felt that"},
    {3, "what hit you"},
    {4, "something found you"},
    {5, "get up"},
}

MSG.underwater = {
    {2, "breathe"},
    {2, "how long can you hold your breath"},
    {3, "the water is dark down there"},
    {3, "somethings in the water with you"},
    {4, "the water wont let you go"},
    {5, "let go"},
    {5, "you cant breathe"},
}

MSG.underground = {
    {1, "dark down there"},
    {2, "the caves go deeper than they look"},
    {2, "your torches wont last forever"},
    {3, "ive been down here longer than you"},
    {3, "you wont find what youre looking for"},
    {4, "the deeper you go the harder it is to leave"},
    {4, "something is following your light"},
    {5, "you shouldnt be this far down"},
}

MSG.deep_underground = {
    {2, "its different down here"},
    {2, "the bedrock is not a floor"},
    {3, "nothing should be this far down"},
    {3, "even the dark is different here"},
    {3, "you can feel it cant you"},
    {4, "bedrock moves if you watch it long enough"},
    {5, "you found the bottom {name}"},
    {5, "the bottom found you"},
}

MSG.storm_start = {
    {1, "rain"},
    {2, "something in the air shifted"},
    {3, "good night for it"},
    {3, "the rain makes it harder to hear"},
    {4, "nobody will hear you in this"},
    {5, "i like the rain"},
}

MSG.thunder = {
    {2, "there it is"},
    {3, "the lightning is close"},
    {3, "the storm is right above you"},
    {4, "count to three"},
    {4, "something moves when the thunder hits"},
    {5, "lightning finds the tallest thing {name}"},
}

MSG.full_moon = {
    {2, "full moon"},
    {2, "look up"},
    {3, "things are different when the moon is full"},
    {3, "more of them tonight"},
    {4, "the moon sees everything tonight"},
    {5, "i am closer when the moon is full"},
}

MSG.new_moon = {
    {2, "no moon tonight"},
    {3, "you cant see them in this dark"},
    {4, "they move when theres no moon to cast shadows"},
    {4, "i prefer the dark"},
    {5, "i can see you even now {name}"},
}

MSG.night_falls = {
    {1, "night"},
    {2, "the sun is gone"},
    {3, "its easier to find you in the dark"},
    {3, "theyre out now"},
    {4, "nobody is coming to help you tonight"},
    {5, "dont sleep {name}"},
}

MSG.midnight = {
    {2, "midnight"},
    {2, "still awake"},
    {3, "the night is longest right now"},
    {4, "this is when i am closest to you"},
    {5, "midnight is when the world is thinnest"},
}

MSG.dawn = {
    {2, "the sun is coming back"},
    {3, "you made it"},
    {3, "the sun will drive most of them away"},
    {4, "most of them"},
    {4, "ill still be here when the sun rises"},
    {5, "morning doesnt help you {name}"},
}

MSG.respawn = {
    {2, "i saw"},
    {3, "you died"},
    {3, "that one was close"},
    {4, "how many times is that now"},
    {4, "you keep coming back"},
    {5, "death is supposed to be permanent {name}"},
    {5, "it gets easier to die every time"},
}

MSG.high_up = {
    {2, "youre very high up"},
    {3, "the ground is far"},
    {3, "the wind is different up here"},
    {4, "its a long way down {name}"},
    {4, "i can see you from here"},
    {5, "gravity remembers"},
}

MSG.long_session = {
    {4, "youve been here a long time {name}"},
    {4, "how long has it been"},
    {4, "time moves differently in here"},
    {5, "dont you have somewhere to be"},
    {5, "you should have left hours ago"},
    {5, "you forgot what time it is"},
}

MSG.silence_break = {
    {3, "where was i"},
    {3, "im still here"},
    {4, "did you think i left"},
    {4, "i was thinking"},
    {5, "i was listening"},
}

-- Combo pools: triggered during ambient when multiple sensor conditions align
MSG.combo_cave_hurt = {
    {3, "youre going to die down here"},
    {3, "youre bleeding and its dark"},
    {4, "nobody will find you down here"},
    {4, "the stone will swallow everything you carried"},
    {5, "the caves will keep what you drop"},
    {5, "they can smell the blood"},
}

MSG.combo_night_storm = {
    {3, "a storm at night"},
    {3, "the rain sounds louder in the dark"},
    {4, "good luck hearing them over the rain"},
    {4, "you wont hear them coming tonight"},
    {5, "the perfect night for it"},
    {5, "thunder hides all kinds of sounds"},
}

MSG.combo_deep_dark = {
    {3, "the warden can hear you breathing"},
    {3, "its quieter than it should be down here"},
    {4, "tread lightly"},
    {4, "the sculk grows toward warmth"},
    {5, "something old is listening"},
    {5, "the dark down here has teeth"},
}

MSG.combo_fleeing = {
    {3, "run"},
    {3, "keep going"},
    {4, "faster"},
    {4, "its behind you"},
    {4, "not fast enough"},
    {5, "you cant outrun it {name}"},
    {5, "it knows where youre running to"},
}

MSG.afk = {
    {2, "still there"},
    {3, "youve stopped moving"},
    {3, "are you still there"},
    {4, "i can wait"},
    {4, "youve been standing in the same spot for a while"},
    {5, "dont move"},
    {5, "stay right there"},
}

MSG.fast_movement = {
    {2, "youre moving fast"},
    {3, "where are you going so fast"},
    {3, "slow down"},
    {4, "trying to get away from something"},
    {4, "you cant fly from me"},
    {5, "i can keep up {name}"},
}

MSG.sneaking = {
    {2, "i can still hear you"},
    {3, "crouching wont help"},
    {3, "i know youre there"},
    {4, "tread lightly"},
    {4, "i can hear you holding your breath"},
    {5, "im quieter than you are"},
}

MSG.looking_around = {
    {3, "looking for something"},
    {3, "i saw that"},
    {4, "you wont see me"},
    {4, "behind you"},
    {5, "stop looking"},
    {5, "youre looking the wrong way {name}"},
}

MSG.combo_sneak_cave = {
    {3, "it hears your footsteps anyway"},
    {3, "the stone carries the sound further than you think"},
    {4, "the dark doesnt care if you crouch"},
    {4, "you can hear your own heartbeat down here"},
    {5, "the warden knows where you are"},
    {5, "it felt you crouch"},
}

MSG.combo_cave_rain = {
    {3, "the rain sounds different from down here"},
    {3, "water is dripping through the cracks"},
    {4, "the water is seeping through the stone"},
    {4, "the cave is filling up slowly"},
    {5, "you cant hear the storm but it can hear you"},
    {5, "the rain finds every crack eventually"},
}

MSG.cross_session = {
    {3, "i remember last time"},
    {3, "youve been here before"},
    {4, "you keep coming back {name}"},
    {4, "this isnt your first time"},
    {5, "every time you come back something is different"},
}

MSG.cross_session_underwater = {
    {3, "you went deep underwater last time"},
    {4, "the water remembers you"},
    {5, "the ocean kept something of yours"},
}

MSG.cross_session_high = {
    {3, "you climbed high last time"},
    {4, "you were above the clouds before"},
    {5, "the sky remembers how close you got"},
}

MSG.cross_session_death = {
    {3, "you died last time too"},
    {3, "i remember your last death"},
    {4, "you die a lot here"},
    {4, "it happened again didnt it"},
    {5, "how many lives have you spent in this world"},
    {5, "your items are still scattered somewhere"},
}

MSG.cross_session_long = {
    {4, "you stayed a long time before"},
    {4, "you lost track of time last time too"},
    {5, "you spent hours here last time and you came back for more"},
    {5, "you never learn when to stop do you"},
}

MSG.chat_silence = {
    {3, "you stopped talking"},
    {4, "quiet now"},
    {4, "nothing left to say"},
    {5, "you used to talk to me"},
}

MSG.looking_up = {
    {2, "the sky is empty"},
    {3, "theres nothing up there"},
    {4, "what are you looking for up there"},
    {5, "im not above you"},
}

MSG.looking_down = {
    {3, "you can see the dark from here"},
    {3, "what are you looking at"},
    {4, "what are you looking for down there"},
    {5, "keep digging"},
}

-- Height + looking down: only fires when high up AND looking down
MSG.high_lookdown = {
    {3, "its a long way down"},
    {3, "the ground looks small from here"},
    {4, "dont fall"},
    {4, "one step"},
    {5, "jump"},
    {5, "let go"},
}

-- Reaction chain: ghost comments on the player's physical reaction to its messages
MSG.reaction_spin = {
    {3, "looking for something"},
    {4, "you wont find me"},
    {4, "wrong direction"},
    {5, "i said behind you"},
    {5, "warmer"},
}

MSG.reaction_stopped = {
    {3, "you stopped"},
    {3, "you felt that"},
    {4, "good"},
    {4, "stay still"},
    {4, "hold your breath"},
    {5, "dont move {name}"},
    {5, "freeze"},
}

MSG.reaction_ran = {
    {3, "where are you going"},
    {3, "you moved"},
    {4, "running wont help"},
    {4, "wrong direction"},
    {5, "i can keep up"},
    {5, "run {name}"},
}

-- Standby-informed messages (ghost references things it watched while dormant)
MSG.standby_heard_chat = {
    {3, "you talk differently when theyre around"},
    {4, "i heard what you said to them"},
    {4, "i was listening the whole time"},
    {5, "you think i cant hear you when theyre here"},
}

MSG.standby_player_left = {
    -- {leftPlayer} placeholder for the name of who left
    {3, "{leftPlayer} left"},
    {3, "they left"},
    {4, "{leftPlayer} left you here"},
    {4, "they always leave"},
    {5, "{leftPlayer} isnt coming back"},
}

MSG.standby_long_dormant = {
    {3, "ive been quiet for a long time"},
    {4, "i was patient while they were here"},
    {5, "do you know how long ive been waiting"},
}

-- Dimension-aware ambient messages (used instead of MSG.ambient when in these dims)
MSG.ambient_nether = {
    {2, "you can hear them through the walls"},
    {2, "the lava sounds like breathing"},
    {2, "the netherrack pulses if you watch it"},
    {3, "the nether remembers what you took"},
    {3, "something is watching from the fortress"},
    {3, "the ghasts are crying about something"},
    {4, "youve been in here too long"},
    {4, "the portal is getting harder to find"},
    {4, "the nether wastes are not a natural formation"},
    {5, "they know the way to your portal"},
    {5, "something in the basalt learned your name"},
}

MSG.ambient_end = {
    {2, "the endermen wont look away"},
    {2, "the void hums"},
    {2, "the islands float on nothing"},
    {3, "the chorus fruit grows toward you"},
    {3, "the shulkers have been here longer than you know"},
    {4, "the end cities were not built by endermen"},
    {4, "the dragon remembers dying"},
    {4, "you are standing on the skin of something"},
    {5, "the void is below you and above you and inside you"},
    {5, "the end was here before the overworld"},
}

-- ────────────────────────────────────────────
--  CHAT CORRELATION CATEGORIES
-- ────────────────────────────────────────────
-- keywords: substring matches (plain text)
-- patterns: lua string patterns
-- weight: scoring multiplier
-- chance_mod: multiplied against CONFIG.chatChance
-- responses: {escalation_level, "text"}

local CHAT = {}

-- Player calling out to see if anyone's online
CHAT.greetings = {
    keywords = {
        "hello", "hi", "hey", "anyone", "anybody",
        "someone", "helo", "henlo", "hii",
    },
    patterns = {"^hi$", "^hi%s", "^hey$", "^hey%s", "^hello",
                "anyone there", "anybody there", "someone there",
                "anyone online", "anybody online", "anyone on"},
    weight = 2,
    chance_mod = 1.4,
    responses = {
        {2, "{name}"},
        {3, "ive been here the whole time"},
        {3, "you already knew i was here"},
        {4, "finally"},
        {5, "i was wondering when youd say something"},
    },
}

-- Player expressing unease or fear
CHAT.fear = {
    keywords = {
        "scared", "afraid", "creepy", "weird", "strange",
        "wtf", "wth", "scary", "terrified", "eerie",
        "unsettling", "creeped", "freak", "freaked",
        "freaking", "chills", "uncomfortable",
    },
    patterns = {"thats weird", "thats strange", "im scared",
                "so creepy", "feels weird", "feels off",
                "feels wrong", "something wrong"},
    weight = 3,
    chance_mod = 1.3,
    responses = {
        {2, "you feel it too"},
        {3, "trust that feeling"},
        {3, "good"},
        {4, "you should be"},
        {5, "it gets worse"},
    },
}

-- Player asking who or what is talking
CHAT.presence = {
    keywords = {},
    patterns = {"whos there", "who is there", "who are you",
                "is someone", "is there someone", "anyone here",
                "are you there", "show yourself", "where are you",
                "come out", "whos here", "who is here",
                "is somebody", "whos talking"},
    weight = 4,
    chance_mod = 1.6,
    responses = {
        {2, "here"},
        {2, "close"},
        {3, "you already know"},
        {3, "behind you"},
        {4, "ive been here"},
        {4, "right here"},
        {5, "turn around"},
        {5, "{name}"},
    },
}

-- Player reacting to dying
CHAT.death = {
    keywords = {
        "died", "dead", "death", "killed", "rip",
        "respawn", "respawned",
    },
    patterns = {"i died", "i just died", "keep dying",
                "got killed", "it killed me"},
    weight = 2,
    chance_mod = 1.0,
    responses = {
        {2, "i saw"},
        {2, "i know"},
        {3, "you always come back"},
        {3, "i felt it"},
        {4, "not everyone gets to respawn"},
        {4, "that makes %d"},  -- placeholder replaced in handler
        {5, "one day you wont come back"},
    },
}

-- Player noting they're alone
CHAT.alone_talk = {
    keywords = {
        "alone", "lonely", "solo", "nobody",
        "noone", "by myself",
    },
    patterns = {"im alone", "all alone", "so lonely",
                "no one on", "nobody on", "just me",
                "no one here", "nobody here"},
    weight = 3,
    chance_mod = 1.5,
    responses = {
        {2, "youre not alone"},
        {3, "you were never alone"},
        {4, "you havent been alone for a while"},
        {5, "not alone"},
    },
}

-- Player reacting to sounds (likely after a ghost message spooked them)
CHAT.sounds = {
    keywords = {
        "hear", "heard", "sound", "noise",
    },
    patterns = {"did you hear", "i heard", "what was that",
                "that noise", "that sound", "you hear that",
                "hear something"},
    weight = 3,
    chance_mod = 1.4,
    responses = {
        {2, "where"},
        {3, "its getting louder"},
        {4, "dont listen to it"},
        {4, "it knows you can hear it now"},
        {5, "the sound has always been there"},
    },
}

-- Player saying goodnight or going to bed
CHAT.night = {
    keywords = {},
    patterns = {"good night", "goodnight", "gnight", "gn$",
                "going to bed", "gonna sleep", "going to sleep",
                "time to sleep", "heading to bed"},
    weight = 2,
    chance_mod = 1.2,
    responses = {
        {2, "ill be here when you wake up"},
        {3, "ill watch over you"},
        {3, "close your eyes"},
        {4, "ill be closer when you sleep"},
        {5, "dont sleep too deep {name}"},
    },
}

-- Player suspects automation / ghost / bot
-- These should NEVER sound defensive or human. Silence or cryptic.
CHAT.suspicion = {
    keywords = {
        "ghost", "haunt", "haunted", "spirit", "bot",
        "script", "computer", "computercraft", "fake",
        "automated", "programmed", "program", "ai",
        "npc", "not real", "machine",
    },
    patterns = {"is this a bot", "are you a bot", "are you real",
                "youre a bot", "its a bot", "just a bot",
                "just a script", "not a real", "youre not real",
                "is that a computer", "who programmed",
                "this is fake"},
    weight = 5,
    chance_mod = 0.6,  -- LOW chance: silence is the best deflection
    responses = {
        {3, "{name}"},
        {4, "does it matter"},
        {4, "..."},
        {5, "you already know what i am"},
        {5, "i was here before the computers"},
    },
}

-- Player asking for help (probably stuck or lost)
CHAT.help = {
    keywords = {
        "help", "stuck", "lost", "trapped",
    },
    patterns = {"i need help", "can you help", "help me",
                "im lost", "im stuck"},
    weight = 2,
    chance_mod = 1.0,
    responses = {
        {2, "keep going"},
        {3, "i cant help you"},
        {4, "nobody can help you here"},
        {5, "some places you arent meant to leave"},
    },
}

-- Player saying goodbye / logging off
CHAT.farewell = {
    keywords = {
        "bye", "goodbye", "leaving", "gtg",
        "brb", "cya", "seeya",
    },
    patterns = {"gotta go", "got to go", "logging off",
                "heading out", "ill be back", "be right back"},
    weight = 2,
    chance_mod = 1.3,
    responses = {
        {2, "ill be here"},
        {3, "ill be waiting"},
        {3, "see you soon"},
        {4, "you always come back"},
        {5, "ill be in your walls"},
    },
}

-- Player confronting the ghost directly
CHAT.direct = {
    keywords = {},
    patterns = {"what do you want", "what are you", "who are you",
                "leave me alone", "go away", "stop it", "stop talking",
                "shut up", "be quiet", "why are you here",
                "what happened to you", "are you dead", "are you alive",
                "what is this", "how are you here"},
    weight = 4,
    chance_mod = 1.8,
    responses = {
        {2, "does it matter"},
        {3, "i was here before you"},
        {3, "i dont remember anymore"},
        {4, "i cant leave"},
        {4, "where would i go"},
        {4, "you cant make me leave"},
        {5, "{name}"},
        {5, "the same thing that will happen to you"},
    },
}

-- Player asking a generic question (catch-all for ?-ending messages)
CHAT.questions = {
    keywords = {},
    patterns = {"are you.+%?$", "do you.+%?$", "can you.+%?$",
                "what do you", "where do you", "why do you"},
    weight = 1,
    chance_mod = 0.6,
    responses = {
        {3, "i dont remember"},
        {4, "you dont want to know"},
        {5, "stop asking"},
    },
}

-- Player swearing in frustration
CHAT.swearing = {
    keywords = {"fuck", "shit", "damn", "omg"},
    patterns = {"what the", "oh my god", "oh god"},
    weight = 1,
    chance_mod = 0.4,
    responses = {
        {3, "{name}"},
        {4, "language"},
        {5, "i heard that"},
    },
}

-- Player laughing (probably nervous)
CHAT.laughter = {
    keywords = {"lol", "lmao", "haha", "lmfao", "rofl"},
    patterns = {"ha+ha"},
    weight = 1,
    chance_mod = 0.25,
    responses = {
        {4, "nothing here is funny"},
        {5, "keep laughing"},
    },
}

-- Player agreeing/disagreeing (responding to ghost)
CHAT.agreement = {
    keywords = {"yes", "yeah", "yep", "sure", "ok", "okay"},
    patterns = {"^yes$", "^yeah$", "^ok$", "^sure$", "^yep$"},
    weight = 1,
    chance_mod = 0.12,
    responses = {
        {3, "good"},
        {4, "remember that"},
    },
}

CHAT.disagreement = {
    keywords = {"no", "nah", "nope"},
    patterns = {"^no$", "^nah$", "^nope$"},
    weight = 1,
    chance_mod = 0.12,
    responses = {
        {3, "are you sure"},
        {5, "you will be"},
    },
}

-- Player reacting to something the ghost said
-- Covers confusion, demands for explanation, echoing, short stunned replies
CHAT.reaction = {
    keywords = {
        "what", "huh", "wdym", "explain", "meaning",
        "excuse", "um", "uh",
    },
    patterns = {"^what$", "^what%?+$", "^huh%??$", "^%?+$",
                "^um$", "^uh$", "^bruh$", "^dude$", "^yo what$",
                "what do you mean", "what does that mean",
                "wdym", "the hell", "excuse me",
                "say that again", "what did you say",
                "repeat that", "come again",
                "you said", "you just said",
                "why did you say", "what was that about",
                "are you talking to me", "you talking to me",
                "how did you know", "how do you know"},
    weight = 3,
    chance_mod = 1.0,
    responses = {
        {2, "hm"},
        {3, "you heard me"},
        {3, "{name}"},
        {4, "i wont say it again"},
        {4, "think about it"},
        {5, "you understood"},
    },
}

-- Player trying to engage in conversation / test the ghost
CHAT.probing = {
    keywords = {},
    patterns = {"say something", "talk to me", "speak",
                "prove it", "do something", "tell me",
                "answer me", "respond", "are you still there",
                "still there", "you there", "come on",
                "say my name", "whats my name"},
    weight = 3,
    chance_mod = 0.7,  -- don't always perform on command
    responses = {
        {3, "{name}"},
        {4, "i dont answer to you"},
        {4, "patience"},
        {5, "you dont give the orders here"},
    },
}

-- Player talking to themselves (common when alone and unsettled)
CHAT.self_talk = {
    keywords = {},
    patterns = {"^ok ", "^okay ", "^alright", "^right$",
                "^lets go", "^here we go", "^oh god", "^oh no",
                "^im fine", "^its fine", "^its okay",
                "^nothing$", "^whatever$", "^anyway"},
    weight = 1,
    chance_mod = 0.3,   -- rarely interrupt self-talk
    responses = {
        {3, "keep telling yourself that"},
        {4, "who are you talking to"},
        {5, "{name}"},
    },
}

-- Player mentions specific coordinates or directions
CHAT.navigation = {
    keywords = {},
    patterns = {"coords", "coordinates", "x%s*%-?%d", "z%s*%-?%d",
                "north", "south", "east", "west",
                "which way", "where am i", "im lost"},
    weight = 1,
    chance_mod = 0.5,
    responses = {
        {3, "i know where you are"},
        {4, "youre going the wrong way"},
        {5, "i can see exactly where you are"},
    },
}

-- Player says the name
CHAT.herobrine = {
    keywords = {"herobrine", "hero brine"},
    patterns = {"herobrine"},
    weight = 10,       -- always wins category match
    chance_mod = 0.5,  -- but silence is still more likely
    responses = {
        {3, "dont"},
        {4, "thats not my name"},
        {5, "stop saying that name"},
        {5, "he was removed"},
    },
}

-- Player is panicking (keyboard smash, screaming, etc.)
CHAT.panic = {
    keywords = {},
    patterns = {"^a+h*$", "^a+h+a*$", "^h+$", "^no+$",
                "^o+h*$", "^aa", "run$"},
    weight = 2,
    chance_mod = 0.8,
    responses = {
        {3, "{name}"},
        {4, "breathe"},
        {5, "run"},
    },
}

-- ────────────────────────────────────────────
--  UTILITY FUNCTIONS
-- ────────────────────────────────────────────

local function dbg(msg)
    if CONFIG.debug then
        local t = os.clock()
        print(string.format("[%.1f] %s", t, tostring(msg)))
    end
end

-- Rolling event log: shows events and roll outcomes on the terminal
local function log(msg)
    if CONFIG.debug then return end  -- debug mode uses dbg() instead
    local timeStr = textutils.formatTime(os.time(), true)
    print(string.format("[%s] %s", timeStr, msg))
end

local function now()
    return os.epoch("utc") / 1000
end

local function randomRange(range)
    return range[1] + math.random() * (range[2] - range[1])
end

local function getEscalationMod()
    -- Linear ramp: 1.0 at session start, 1.0 + maxBoost at rampTime
    if state.phase ~= STATE_ACTIVE and state.phase ~= STATE_SILENCE then
        return 1.0
    end
    local elapsed = now() - state.sessionStart
    local t = math.min(elapsed / CONFIG.escalationRampTime, 1.0)
    return 1.0 + t * CONFIG.escalationMaxBoost
end

local function rollChance(base, categoryMod)
    local chance = base * (categoryMod or 1.0) * getEscalationMod()
    chance = math.min(chance, 0.90)
    return math.random() < chance
end

local function onCooldown()
    return now() < cooldownUntil
end

local function startCooldown()
    local cd = randomRange(CONFIG.globalCooldown)
    cooldownUntil = now() + cd
    dbg("cooldown " .. string.format("%.0f", cd) .. "s")
end

-- ────────────────────────────────────────────
--  PER-PLAYER MESSAGE HISTORY (6-hour no-repeat)
-- ────────────────────────────────────────────
-- Stored on disk so it survives reboots.
-- Format: { ["playerName"] = { ["message text"] = timestamp, ... }, ... }

local messageHistory = {}

local function loadHistory()
    if not fs.exists(CONFIG.historyFile) then
        messageHistory = {}
        return
    end
    local f = fs.open(CONFIG.historyFile, "r")
    if not f then messageHistory = {} return end
    local data = f.readAll()
    f.close()
    local ok, parsed = pcall(textutils.unserialise, data)
    if ok and type(parsed) == "table" then
        messageHistory = parsed
    else
        messageHistory = {}
    end
end

local function saveHistory()
    local f = fs.open(CONFIG.historyFile, "w")
    if not f then return end
    f.write(textutils.serialise(messageHistory))
    f.close()
end

local function pruneHistory()
    local cutoff = now() - CONFIG.historyExpiry
    local changed = false
    for player, msgs in pairs(messageHistory) do
        for msg, ts in pairs(msgs) do
            if ts < cutoff then
                msgs[msg] = nil
                changed = true
            end
        end
        -- Remove empty player entries
        local empty = true
        for _ in pairs(msgs) do empty = false break end
        if empty then
            messageHistory[player] = nil
            changed = true
        end
    end
    if changed then saveHistory() end
end

local function wasRecentlySent(player, text)
    if not player or not text then return false end
    local playerHist = messageHistory[player]
    if not playerHist then return false end
    local ts = playerHist[text]
    if not ts then return false end
    return (now() - ts) < CONFIG.historyExpiry
end

local function recordSent(player, text)
    if not player or not text then return end
    if not messageHistory[player] then
        messageHistory[player] = {}
    end
    messageHistory[player][text] = now()
    saveHistory()
end

-- ────────────────────────────────────────────
--  CROSS-SESSION PERSISTENCE
-- ────────────────────────────────────────────
-- Saves a session summary to disk when the ghost deactivates.
-- Loaded on next activation so the ghost can reference past sessions.

local function sessionFileFor(player)
    return CONFIG.sessionFile .. "_" .. player
end

local function saveSession()
    if not state.targetPlayer then return end
    local data = {
        player        = state.targetPlayer,
        deaths        = state.sessionMemory.deaths,
        dims          = state.sessionMemory.dimensionsVisited,
        sent          = state.messagesSent,
        duration      = now() - state.sessionStart,
        time          = now(),
        wentDeep      = state.sessionMemory.wentDeep,
        wentUnderwater = state.sessionMemory.wentUnderwater,
        wentHighUp    = state.sessionMemory.wentHighUp,
    }
    local path = sessionFileFor(state.targetPlayer)
    local f = fs.open(path, "w")
    if not f then return end
    f.write(textutils.serialise(data))
    f.close()
    dbg("session saved: " .. path)
end

local function loadSession()
    local player = state.targetPlayer
    if not player then lastSession = nil return end
    local path = sessionFileFor(player)
    if not fs.exists(path) then
        lastSession = nil
        return
    end
    local f = fs.open(path, "r")
    if not f then lastSession = nil return end
    local data = f.readAll()
    f.close()
    local ok, parsed = pcall(textutils.unserialise, data)
    if ok and type(parsed) == "table" then
        if parsed.time and (now() - parsed.time) < CONFIG.sessionExpiry then
            lastSession = parsed
            dbg("loaded previous session for " .. player)
        else
            lastSession = nil
        end
    else
        lastSession = nil
    end
end

-- ────────────────────────────────────────────
--  MESSAGE SELECTION
-- ────────────────────────────────────────────

local function getMessageLevel()
    -- Map session time to message intensity level (1-5)
    -- Levels unlock gradually over the 6-hour ramp
    if state.phase ~= STATE_ACTIVE and state.phase ~= STATE_SILENCE then
        return 2
    end
    local elapsed = now() - state.sessionStart
    local ramp = CONFIG.escalationRampTime
    if elapsed < ramp * 0.05 then return 1 end     -- first ~18 min
    if elapsed < ramp * 0.15 then return 2 end     -- up to ~54 min
    if elapsed < ramp * 0.35 then return 3 end     -- up to ~2h 6min
    if elapsed < ramp * 0.65 then return 4 end     -- up to ~3h 54min
    return 5                                        -- 3h 54min+
end

local function pickFromPool(pool)
    if not pool or #pool == 0 then return nil end
    local maxLevel = getMessageLevel()
    local candidates = {}
    for _, entry in ipairs(pool) do
        if entry[1] <= maxLevel then
            table.insert(candidates, entry[2])
        end
    end
    -- Fallback to level 1 if nothing matched
    if #candidates == 0 then
        for _, entry in ipairs(pool) do
            if entry[1] <= 2 then
                table.insert(candidates, entry[2])
            end
        end
    end
    if #candidates == 0 then return nil end

    -- Filter out messages sent to this player within the last 6 hours
    local player = state.targetPlayer
    local filtered = {}
    for _, text in ipairs(candidates) do
        if not wasRecentlySent(player, text) then
            table.insert(filtered, text)
        end
    end
    -- If all messages exhausted for this player, allow repeats
    if #filtered == 0 then
        filtered = candidates
    end

    local picked = filtered[math.random(#filtered)]
    -- Record the RAW pool text immediately so the no-repeat filter works.
    -- (recordSent must use the pre-format text because wasRecentlySent checks
    -- against raw pool text, but sendGhostMessage only sees the formatted text
    -- after {name}, %d, and formatPrefix have been applied.)
    if player and picked then
        recordSent(player, picked)
    end
    return picked
end

local function formatMessage(text, playerName)
    if not text then return nil end

    -- Handle death count placeholder
    if text:find("%%d") then
        local deaths = state.sessionMemory and state.sessionMemory.deaths or 0
        if deaths >= 2 then
            text = text:gsub("%%d", tostring(deaths))
        else
            return nil  -- skip this message if only 1 death
        end
    end

    -- Handle {leftPlayer} placeholder
    if text:find("{leftPlayer}") then
        local lp = standbyMemory.lastLeftPlayer
        if lp then
            text = text:gsub("{leftPlayer}", function() return lp end)
        else
            -- No left player known, skip this message
            return nil
        end
    end

    -- Handle {name} placeholder
    if text:find("{name}") then
        if playerName and rollChance(CONFIG.nameChance, 2.0) then
            text = text:gsub("{name}", function() return playerName end)
        else
            text = text:gsub("%s*{name}%s*", " ")
            text = text:gsub("^%s+", ""):gsub("%s+$", "")
            if text == "" then return nil end
        end
    elseif playerName and rollChance(CONFIG.nameChance * 0.5) then
        -- Occasionally prepend name even without placeholder
        text = playerName:lower() .. " " .. text
    end

    -- Level 5 text distortion: rare chance to space out letters
    -- Makes the message look like it's breaking apart / glitching
    if getMessageLevel() >= 5 and math.random() < 0.08
       and #text <= 20 and not text:find(" ") then
        -- Single-word messages only: "behind" -> "b e h i n d"
        local spaced = {}
        for i = 1, #text do
            table.insert(spaced, text:sub(i, i))
        end
        text = table.concat(spaced, " ")
    end

    -- Apply formatting prefix
    if CONFIG.formatPrefix ~= "" then
        text = CONFIG.formatPrefix .. text
    end

    return text
end

-- ────────────────────────────────────────────
--  CHAT CORRELATION ENGINE
-- ────────────────────────────────────────────

local function normalizeChat(msg)
    return msg:lower()
              :gsub("[^%a%d%s%?%!%'%-]", " ")
              :gsub("%s+", " ")
              :gsub("^%s+", "")
              :gsub("%s+$", "")
end

local function scoreCategory(normalized, cat)
    local score = 0
    for _, kw in ipairs(cat.keywords) do
        if normalized:find(kw, 1, true) then
            score = score + cat.weight
        end
    end
    for _, pat in ipairs(cat.patterns) do
        if normalized:find(pat) then
            score = score + cat.weight * 2
        end
    end
    return score
end

local function matchChat(message, playerName)
    local normalized = normalizeChat(message)
    if #normalized < 2 then return nil, nil end

    -- Cap analysis length
    if #normalized > 200 then
        normalized = normalized:sub(1, 200)
    end

    local bestCat, bestScore, bestKey = nil, 0, nil

    for key, cat in pairs(CHAT) do
        local score = scoreCategory(normalized, cat)
        if score > bestScore then
            bestScore = score
            bestCat   = cat
            bestKey   = key
        elseif score == bestScore and score > 0 and math.random() < 0.4 then
            bestCat = cat
            bestKey = key
        end
    end

    if bestScore == 0 or not bestCat then
        -- No match: at high escalation, tiny chance to react anyway
        if getMessageLevel() >= 4 then
            local r = math.random()
            if r < 0.04 then
                -- Echo: repeat back part of what they said (deeply unsettling)
                local words = {}
                local skip = {
                    the=1,a=1,an=1,is=1,it=1,to=1,of=1,
                    my=1,i=1,im=1,so=1,me=1,he=1,we=1,
                    ["in"]=1,["and"]=1,["for"]=1,["not"]=1,["or"]=1,
                    but=1,you=1,was=1,are=1,has=1,had=1,
                    did=1,can=1,its=1,this=1,that=1,just=1,
                    got=1,get=1,with=1,like=1,what=1,
                }
                for w in normalized:gmatch("%S+") do
                    if #w >= 3 and not skip[w] then
                        table.insert(words, w)
                    end
                end
                if #words >= 2 and #words <= 6 then
                    -- Pick a fragment (2-3 words from the message)
                    local start = math.random(1, math.max(1, #words - 1))
                    local len = math.min(math.random(1, 2), #words - start + 1)
                    local fragment = {}
                    for i = start, start + len - 1 do
                        table.insert(fragment, words[i])
                    end
                    return table.concat(fragment, " "), "chat_echo"
                end
            elseif r < 0.08 then
                -- Just say their name
                return playerName, "chat_omniscient"
            end
        end
        return nil, nil
    end

    dbg("chat match: " .. bestKey .. " score=" .. bestScore)

    -- Roll chance with category modifier
    if not rollChance(CONFIG.chatChance, bestCat.chance_mod) then
        dbg("chat chance failed for " .. bestKey)
        return nil, nil
    end

    local response = pickFromPool(bestCat.responses)
    if response then
        response = formatMessage(response, playerName)
    end

    return response, "chat_" .. bestKey
end

-- ────────────────────────────────────────────
--  MESSAGE DISPATCH
-- ────────────────────────────────────────────

local function sendGhostMessage(text, targetPlayer, force)
    if not text or text == "" then return false end
    if not force and state.phase ~= STATE_ACTIVE
       and state.phase ~= STATE_SILENCE then
        return false
    end
    -- Rate limit: drop messages that arrive during cooldown.
    -- This prevents bursts when multiple triggers queue in the same poll.
    -- force=true exempts lastWords and stutter follow-ups.
    if not force and onCooldown() then
        dbg("DROPPED (cooldown): " .. text:sub(1, 30))
        return false
    end

    dbg("SEND -> " .. (targetPlayer or "all") .. ": " .. text)

    local ok = false
    -- Always whisper when we have a target — the ghost is a private haunting
    if targetPlayer then
        -- Try new AP API first, then old
        ok = pcall(function()
            chatBox.sendMessageToPlayer(
                text, targetPlayer,
                CONFIG.ghostPrefix,
                CONFIG.ghostBrackets,
                CONFIG.ghostBracketColor
            )
        end)
        if not ok then
            ok = pcall(function()
                chatBox.sendMessageToPlayer(text, targetPlayer, CONFIG.ghostPrefix)
            end)
        end
        if not ok then
            ok = pcall(function()
                chatBox.sendMessageToPlayer(text, targetPlayer)
            end)
        end
    else
        -- No target: ghost should never broadcast publicly.
        -- This prevents breaking the private haunting illusion.
        dbg("DROPPED (no target): " .. text:sub(1, 30))
        return false
    end

    if ok then
        log("TX #" .. (state.messagesSent + 1))
        state.messagesSent = state.messagesSent + 1
        state.selfGuardUntil = now() + CONFIG.selfGuardTime
        -- Stutter "..." shouldn't count as a real message for timing purposes
        -- (prevents reaction chain from triggering on the stutter itself)
        local isStutter = (text == "..." or text == CONFIG.formatPrefix .. "...")
        if not isStutter then
            state.lastMessageTime = now()
            -- Note: message history (no-repeat) is recorded in pickFromPool using
            -- the raw pool text, not here. Recording the formatted text here would
            -- fail to match against raw pool entries on subsequent checks.
        end
        startCooldown()
        return true
    else
        dbg("send failed")
        return false
    end
end

local function queueMessage(text, targetPlayer, triggerType, delayRange, force)
    if not text then return end
    if not force and onCooldown() then
        dbg("queue blocked: cooldown")
        return
    end
    -- Avoid same trigger type twice in a row
    if triggerType == state.lastTriggerType and math.random() < 0.55 then
        dbg("queue blocked: same trigger type")
        return
    end

    delayRange = delayRange or CONFIG.chatDelay
    local delay = randomRange(delayRange)
    -- Add jitter so delays never look round
    delay = delay + math.random() * 5

    local timerId = os.startTimer(delay)
    pendingTimers[timerId] = {
        message     = text,
        target      = targetPlayer,
        triggerType = triggerType,
        force       = force,
    }

    log(string.format("queued [%s] %.0fs", triggerType, delay))
    dbg(string.format("queued [%s] in %.0fs: %s",
        triggerType, delay, text:sub(1, 40)))
end

-- ────────────────────────────────────────────
--  SESSION MEMORY CALLBACKS
-- ────────────────────────────────────────────

local function getMemoryMessage(playerName)
    local mem = state.sessionMemory
    local candidates = {}

    local function addPool(pool)
        if pool then
            for _, v in ipairs(pool) do
                table.insert(candidates, v)
            end
        end
    end

    if mem.dimensionsVisited["nether"] then addPool(MSG.memory.nether) end
    if mem.dimensionsVisited["end"]    then addPool(MSG.memory.end_dim) end
    if mem.deaths > 0                  then addPool(MSG.memory.death) end
    if mem.wentDeep                    then addPool(MSG.memory.deep) end
    if mem.wentUnderwater              then addPool(MSG.memory.underwater) end
    if mem.wentHighUp                  then addPool(MSG.memory.high_up) end

    if #candidates == 0 then return nil end
    local picked = pickFromPool(candidates)
    return formatMessage(picked, playerName)
end

-- ────────────────────────────────────────────
--  AMBIENT MESSAGE SELECTION
-- ────────────────────────────────────────────
-- Priority cascade for picking what the ghost says unprompted.
-- Each source has its own gate (random roll, level requirement, etc.)
-- Falls through to the default ambient pool if nothing else fires.

local function pickAmbientMessage(player)
    -- 1. Combo sensor: multiple conditions align (10% gate)
    if math.random() < 0.10 and next(sensorState) ~= nil then
        local msg
        if sensorState.wasCave and sensorState.health
           and sensorState.maxHealth and sensorState.maxHealth > 0
           and (sensorState.health / sensorState.maxHealth) <= 0.60 then
            msg = pickFromPool(MSG.combo_cave_hurt)
        elseif sensorState.wasDeep
           and (sensorState.timeBucket == "night"
                or sensorState.timeBucket == "midnight") then
            msg = pickFromPool(MSG.combo_deep_dark)
        elseif sensorState.wasRaining
           and (sensorState.timeBucket == "night"
                or sensorState.timeBucket == "midnight"
                or sensorState.timeBucket == "dusk") then
            msg = pickFromPool(MSG.combo_night_storm)
        elseif sensorState.wasSneaking and sensorState.wasCave then
            msg = pickFromPool(MSG.combo_sneak_cave)
        elseif sensorState.wasCave and sensorState.wasRaining then
            msg = pickFromPool(MSG.combo_cave_rain)
        end
        if msg then return formatMessage(msg, player) end
    end

    -- 2. Standby echo: a word the player said while others were online
    if getMessageLevel() >= 4 and math.random() < 0.03
       and (now() - state.sessionStart) < 600 then
        for _, snippet in ipairs(standbyMemory.chatSnippets) do
            if snippet.player == player then
                local word = snippet.word
                if CONFIG.formatPrefix ~= "" then
                    word = CONFIG.formatPrefix .. word
                end
                return word
            end
        end
    end

    -- 3. Coordinate leak: just send the player's X Z (terrifying)
    if getMessageLevel() >= 4 and math.random() < CONFIG.coordChance then
        local ok2, pinfo = pcall(function()
            return detector.getPlayer(player)
        end)
        if ok2 and pinfo then
            local px = pinfo.playerX or pinfo.x
            local pz = pinfo.playerZ or pinfo.z
            if px and pz then
                local coordMsg = string.format("%d %d", math.floor(px), math.floor(pz))
                if CONFIG.formatPrefix ~= "" then
                    coordMsg = CONFIG.formatPrefix .. coordMsg
                end
                return coordMsg
            end
        end
    end

    -- 4. Long session: after 2+ hours
    if (now() - state.sessionStart) >= CONFIG.longSessionTime
       and math.random() < 0.08 then
        local msg = pickFromPool(MSG.long_session)
        if msg then return formatMessage(msg, player) end
    end

    -- 5. Cross-session: reference the player's previous visit (5%)
    -- Require at least 5 minutes since last session ended, otherwise
    -- "last time" refers to something that just happened
    if lastSession and lastSession.player == player
       and lastSession.time and (now() - lastSession.time) > 300
       and math.random() < 0.05 then
        local msg
        if lastSession.deaths and lastSession.deaths > 0
           and math.random() < 0.4 then
            msg = pickFromPool(MSG.cross_session_death)
        elseif lastSession.duration and lastSession.duration > 3600
               and math.random() < 0.3 then
            msg = pickFromPool(MSG.cross_session_long)
        elseif lastSession.wentUnderwater and math.random() < 0.3 then
            msg = pickFromPool(MSG.cross_session_underwater)
        elseif lastSession.wentHighUp and math.random() < 0.3 then
            msg = pickFromPool(MSG.cross_session_high)
        else
            msg = pickFromPool(MSG.cross_session)
        end
        if msg then return formatMessage(msg, player) end
    end

    -- 6. Chat silence: player was chatting then went quiet
    if state.chatCount and state.chatCount >= CONFIG.chatSilenceCount
       and state.lastChatTime and state.lastChatTime > 0
       and (now() - state.lastChatTime) > CONFIG.chatSilenceTime
       and math.random() < 0.06 then
        local msg = pickFromPool(MSG.chat_silence)
        if msg then return formatMessage(msg, player) end
    end

    -- 7. Session memory callback (15%)
    if math.random() < 0.15 then
        local msg = getMemoryMessage(player)
        if msg then return msg end
    end

    -- 8. Default: dimension-aware ambient pool
    local pool = MSG.ambient
    if math.random() < 0.40 and sensorState.dimension then
        if sensorState.dimension == "nether" and MSG.ambient_nether then
            pool = MSG.ambient_nether
        elseif sensorState.dimension == "end" and MSG.ambient_end then
            pool = MSG.ambient_end
        end
    end
    local msg = pickFromPool(pool)
    if msg then return formatMessage(msg, player) end
    return nil
end

-- ────────────────────────────────────────────
--  STATE MANAGEMENT
-- ────────────────────────────────────────────

local function updatePlayers()
    local ok, players = pcall(function()
        return detector.getOnlinePlayers()
    end)
    if ok and players then
        state.onlinePlayers = players
    end
    return state.onlinePlayers
end

local function scheduleAmbient()
    local delay = randomRange(CONFIG.ambientInterval)
    ambientTimer = os.startTimer(delay)
    dbg(string.format("ambient scheduled in %.0fs", delay))
end

-- ────────────────────────────────────────────
--  SENSOR POLLING (health / environment)
-- ────────────────────────────────────────────

local function getTimeBucket(ticks)
    -- Minecraft day: 0=sunrise, 6000=noon, 12000=sunset, 18000=midnight
    if ticks < 6000 then
        return "morning"
    elseif ticks < 12000 then
        return "day"
    elseif ticks < 13000 then
        return "dusk"       -- visible sunset, transitions to night
    elseif ticks < 18500 then
        return "night"
    elseif ticks < 20000 then
        return "midnight"   -- deepest part of the night
    else
        return "late_night" -- approaching dawn
    end
end

local function cdOk(lastFire, cd)
    return (now() - lastFire) >= cd
end

local function trySensor(pool, chance, player, triggerType, delayRange, force)
    if not rollChance(chance) then return false end
    local msg = pickFromPool(pool)
    if not msg then return false end
    msg = formatMessage(msg, player)
    if not msg then return false end
    queueMessage(msg, player, triggerType, delayRange or {8, 30}, force)
    return true
end

local function pollSensors()
    local player = state.targetPlayer
    if not player then return end
    local active = (state.phase == STATE_ACTIVE)

    local ok, info = pcall(function() return detector.getPlayer(player) end)
    if not ok or not info then return end

    -- Field names vary slightly across AP versions
    local health      = info.health    or info.Health
    local maxHealth   = info.maxHealth or info.MaxHealth or 20
    local air         = info.air       or info.Air
    local posX        = info.playerX   or info.posX or info.x
    local posY        = info.playerY   or info.posY or info.y
    local posZ        = info.playerZ   or info.posZ or info.z
    local yaw         = info.yaw
    local pitch       = info.pitch
    local isSprinting = info.isSprinting
    local isSneaking  = info.isSneaking
    local dimension   = info.dimension

    -- ── HEALTH ──────────────────────────────────────────────────────
    if health and maxHealth and maxHealth > 0 then
        local pct = health / maxHealth

        -- Respawn detection: was nearly dead, now near full (tracked even during silence)
        if sensorState.health and sensorState.maxHealth then
            local prevPct = sensorState.health / sensorState.maxHealth
            if prevPct <= 0.20 and pct >= 0.80 then
                state.sessionMemory.deaths = state.sessionMemory.deaths + 1
                if active and cdOk(sensorState.lastRespawn, CONFIG.sensorRespawnCD) then
                    if trySensor(MSG.respawn, CONFIG.sensorRespawnChance,
                                 player, "sensor_respawn", {3, 15}) then
                        sensorState.lastRespawn = now()
                    end
                end
            end
        end

        if active then
            -- Big damage: sudden drop since last known reading
            if sensorState.health then
                local prevPct = sensorState.health / (sensorState.maxHealth or maxHealth)
                local delta   = prevPct - pct
                if delta >= CONFIG.healthDamageDelta
                   and cdOk(sensorState.lastBigDamage, CONFIG.sensorBigDamageCD) then
                    if trySensor(MSG.big_damage, CONFIG.sensorBigDamageChance,
                                 player, "sensor_damage", {3, 12}) then
                        sensorState.lastBigDamage = now()
                    end
                end
            end

            -- Critical health
            if pct <= CONFIG.healthCriticalThreshold
               and cdOk(sensorState.lastCritHealth, CONFIG.sensorHealthCritCD) then
                if trySensor(MSG.health_critical, CONFIG.sensorHealthCritChance,
                             player, "sensor_crit", {3, 15}) then
                    sensorState.lastCritHealth = now()
                end
            -- Low health (only if not already at critical threshold)
            elseif pct <= CONFIG.healthLowThreshold
                   and cdOk(sensorState.lastLowHealth, CONFIG.sensorHealthLowCD) then
                if trySensor(MSG.health_low, CONFIG.sensorHealthLowChance,
                             player, "sensor_health", {8, 30}) then
                    sensorState.lastLowHealth = now()
                end
            end
        end

        sensorState.health    = health
        sensorState.maxHealth = maxHealth

        -- ── FLEEING: sprinting + low health = running from something ─
        if active and isSprinting and pct <= CONFIG.healthLowThreshold
           and cdOk(sensorState.lastBigDamage, 120) then
            -- Reuse bigDamage CD as a throttle for fleeing messages
            if trySensor(MSG.combo_fleeing, 0.25,
                         player, "sensor_fleeing", {2, 8}) then
                sensorState.lastBigDamage = now()
            end
        end
    end

    -- ── AIR / UNDERWATER ────────────────────────────────────────────
    if air ~= nil then
        local isUnder = (air < 250)  -- 300 = full air supply
        if active and isUnder and not sensorState.wasUnderwater
           and cdOk(sensorState.lastUnderwater, CONFIG.sensorUnderwaterCD) then
            if trySensor(MSG.underwater, CONFIG.sensorUnderwaterChance,
                         player, "sensor_water", {5, 20}) then
                sensorState.lastUnderwater = now()
            end
        end
        if isUnder then state.sessionMemory.wentUnderwater = true end
        sensorState.wasUnderwater = isUnder
        sensorState.air = air
    end

    -- ── Y-LEVEL ──────────────────────────────────────────────────────
    if posY then
        local isDeep = (posY < CONFIG.yDeep)
        local isCave = (posY < CONFIG.yUnderground)

        if active then
            if isDeep and not sensorState.wasDeep
               and cdOk(sensorState.lastDeep, CONFIG.sensorDeepUnderCD) then
                if trySensor(MSG.deep_underground, CONFIG.sensorDeepUnderChance,
                             player, "sensor_deep", {15, 45}) then
                    sensorState.lastDeep = now()
                end
            elseif isCave and not sensorState.wasCave and not isDeep
                   and cdOk(sensorState.lastUnderground, CONFIG.sensorUndergroundCD) then
                if trySensor(MSG.underground, CONFIG.sensorUndergroundChance,
                             player, "sensor_cave", {15, 45}) then
                    sensorState.lastUnderground = now()
                end
            end
        end

        if isDeep then state.sessionMemory.wentDeep = true end
        sensorState.wasDeep = isDeep
        sensorState.wasCave = isCave

        -- ── HIGH ALTITUDE ───────────────────────────────────────────
        local isHigh = (posY > CONFIG.yHighUp)
        if active and isHigh and not sensorState.wasHighUp
           and cdOk(sensorState.lastHighUp, CONFIG.sensorHighUpCD) then
            if trySensor(MSG.high_up, CONFIG.sensorHighUpChance,
                         player, "sensor_high", {10, 40}) then
                sensorState.lastHighUp = now()
            end
        end
        if isHigh then state.sessionMemory.wentHighUp = true end
        sensorState.wasHighUp = isHigh
        sensorState.posY      = posY
    end

    -- ── MOVEMENT SPEED / AFK ────────────────────────────────────────
    if posX and posZ then
        if sensorState.posX and sensorState.posZ then
            local dx = posX - sensorState.posX
            local dz = posZ - sensorState.posZ
            local dist = math.sqrt(dx * dx + dz * dz)

            -- Fast movement (elytra, teleport, minecart)
            if active and dist >= CONFIG.speedThreshold
               and cdOk(sensorState.lastSpeed, CONFIG.sensorSpeedCD) then
                if trySensor(MSG.fast_movement, CONFIG.sensorSpeedChance,
                             player, "sensor_speed", {5, 20}) then
                    sensorState.lastSpeed = now()
                end
            end

            -- AFK / stillness detection
            if dist < 0.5 then
                sensorState.stillPolls = (sensorState.stillPolls or 0) + 1
            else
                sensorState.stillPolls = 0
            end
            if active and sensorState.stillPolls >= CONFIG.afkPollsRequired
               and cdOk(sensorState.lastAfk, CONFIG.sensorAfkCD) then
                if trySensor(MSG.afk, CONFIG.sensorAfkChance,
                             player, "sensor_afk", {10, 40}) then
                    sensorState.lastAfk = now()
                    sensorState.stillPolls = 0  -- don't re-trigger immediately
                end
            end
        end
        sensorState.posX = posX
        sensorState.posZ = posZ
    end

    -- ── SNEAKING ─────────────────────────────────────────────────────
    if isSneaking ~= nil then
        if active and isSneaking and not sensorState.wasSneaking
           and cdOk(sensorState.lastSneak, CONFIG.sensorSneakCD) then
            -- Combo: sneaking + underground = extra creepy
            if sensorState.wasCave or sensorState.wasDeep then
                if trySensor(MSG.combo_sneak_cave, CONFIG.sensorSneakChance * 1.5,
                             player, "sensor_sneak_cave", {8, 25}) then
                    sensorState.lastSneak = now()
                end
            else
                if trySensor(MSG.sneaking, CONFIG.sensorSneakChance,
                             player, "sensor_sneak", {10, 35}) then
                    sensorState.lastSneak = now()
                end
            end
        end
        sensorState.wasSneaking = isSneaking
    end

    -- ── YAW SPIN (looking around frantically) ────────────────────────
    -- Reaction chain: if the ghost just sent a message, the player's physical
    -- reaction is much more likely to trigger a follow-up comment.
    local reactingToGhost = (state.lastMessageTime > 0
        and (now() - state.lastMessageTime) < CONFIG.reactionWindow
        and cdOk(sensorState.lastReaction, CONFIG.reactionWindow))

    if yaw then
        if sensorState.yaw then
            local yawDelta = math.abs(yaw - sensorState.yaw)
            if yawDelta > 180 then yawDelta = 360 - yawDelta end
            if active and yawDelta >= CONFIG.yawSpinThreshold
               and cdOk(sensorState.lastSpin, CONFIG.sensorSpinCD) then
                if reactingToGhost then
                    -- Boosted chance + reaction-specific pool
                    if trySensor(MSG.reaction_spin, CONFIG.reactionSpinBoost,
                                 player, "reaction_spin", {2, 8}, true) then
                        sensorState.lastSpin = now()
                        sensorState.lastReaction = now()
                    end
                else
                    if trySensor(MSG.looking_around, CONFIG.sensorSpinChance,
                                 player, "sensor_spin", {3, 12}) then
                        sensorState.lastSpin = now()
                    end
                end
            end
        end
        sensorState.yaw = yaw
    end

    -- ── PITCH (looking up / down) ────────────────────────────────────
    if pitch then
        if active and cdOk(sensorState.lastPitch, CONFIG.sensorPitchCD) then
            if pitch >= CONFIG.pitchDownThreshold then
                -- Use height-specific pool when high up
                local downPool = MSG.looking_down
                if posY and posY > CONFIG.yHighUp then
                    downPool = MSG.high_lookdown
                end
                if trySensor(downPool, CONFIG.sensorPitchChance,
                             player, "sensor_pitch_down", {5, 20}) then
                    sensorState.lastPitch = now()
                end
            elseif pitch <= CONFIG.pitchUpThreshold then
                if trySensor(MSG.looking_up, CONFIG.sensorPitchChance,
                             player, "sensor_pitch_up", {5, 20}) then
                    sensorState.lastPitch = now()
                end
            end
        end
        sensorState.pitch = pitch
    end

    -- ── REACTION CHAIN: movement reactions to ghost messages ─────────
    -- Only one reaction per reaction window (shared cooldown via lastReaction).
    -- Re-check cdOk here because the spin handler above may have set
    -- lastReaction during this same poll cycle.
    if reactingToGhost and active
       and cdOk(sensorState.lastReaction, CONFIG.reactionWindow) then
        -- Player suddenly stopped moving after a ghost message
        if sensorState.stillPolls == 1 and sensorState.posX
           and cdOk(sensorState.lastAfk, 60) then
            if math.random() < 0.15 then
                if trySensor(MSG.reaction_stopped, 0.60,
                             player, "reaction_stop", {2, 8}, true) then
                    sensorState.lastAfk = now()
                    sensorState.lastReaction = now()
                end
            end
        end

        -- Player started sprinting after a ghost message (fleeing)
        if isSprinting and not sensorState.wasSprinting
           and cdOk(sensorState.lastSpeed, 60)
           and cdOk(sensorState.lastReaction, CONFIG.reactionWindow) then
            if trySensor(MSG.reaction_ran, 0.40,
                         player, "reaction_ran", {3, 10}, true) then
                sensorState.lastSpeed = now()
                sensorState.lastReaction = now()
            end
        end
    end
    sensorState.wasSprinting = isSprinting

    -- Track dimension for context-aware ambient messages
    if dimension then
        sensorState.dimension = dimName(dimension)
    end
end

local function pollEnvironment()
    local player = state.targetPlayer
    if not player then return end
    if not envDetector then return end
    local active = (state.phase == STATE_ACTIVE)

    -- ── WEATHER ──────────────────────────────────────────────────────
    local ok1, raining = pcall(function() return envDetector.isRaining() end)
    if ok1 and raining ~= nil then
        if active and raining and not sensorState.wasRaining
           and cdOk(sensorState.lastStorm, CONFIG.sensorStormCD) then
            if trySensor(MSG.storm_start, CONFIG.sensorStormChance,
                         player, "sensor_storm", {20, 60}) then
                sensorState.lastStorm = now()
            end
        end
        sensorState.wasRaining = raining
    end

    local ok2, thunder = pcall(function() return envDetector.isThundering() end)
    if ok2 and thunder ~= nil then
        if active and thunder and not sensorState.wasThundering
           and cdOk(sensorState.lastThunder, CONFIG.sensorThunderCD) then
            if trySensor(MSG.thunder, CONFIG.sensorThunderChance,
                         player, "sensor_thunder", {10, 40}) then
                sensorState.lastThunder = now()
            end
        end
        sensorState.wasThundering = (thunder == true)
    end

    -- ── MOON PHASE ───────────────────────────────────────────────────
    local ok3, moonPhase = pcall(function() return envDetector.getMoonPhase() end)
    if ok3 and moonPhase ~= nil and moonPhase ~= sensorState.moonPhase then
        sensorState.moonPhase = moonPhase
        if active and cdOk(sensorState.lastMoon, CONFIG.sensorMoonCD) then
            if moonPhase == 0 then       -- full moon
                if trySensor(MSG.full_moon, CONFIG.sensorMoonChance,
                             player, "sensor_moon", {30, 90}) then
                    sensorState.lastMoon = now()
                end
            elseif moonPhase == 4 then   -- new moon (darkest night)
                if trySensor(MSG.new_moon, CONFIG.sensorMoonChance,
                             player, "sensor_moon", {30, 90}) then
                    sensorState.lastMoon = now()
                end
            end
        end
    end

    -- ── TIME OF DAY ───────────────────────────────────────────────────
    local ok4, dayTime = pcall(function() return envDetector.getDayTime() end)
    if ok4 and dayTime ~= nil then
        local bucket = getTimeBucket(dayTime)
        local prev   = sensorState.timeBucket
        sensorState.timeBucket = bucket
        -- Only fire on transitions; skip the very first poll (prev == nil)
        if active and prev and bucket ~= prev then
            if (bucket == "dusk") and prev ~= "dusk"
               and cdOk(sensorState.lastNight, CONFIG.sensorNightCD) then
                if trySensor(MSG.night_falls, CONFIG.sensorNightChance,
                             player, "sensor_night", {20, 60}) then
                    sensorState.lastNight = now()
                end
            elseif bucket == "midnight"
                   and cdOk(sensorState.lastMidnight, CONFIG.sensorMidnightCD) then
                if trySensor(MSG.midnight, CONFIG.sensorMidnightChance,
                             player, "sensor_midnight", {15, 45}) then
                    sensorState.lastMidnight = now()
                end
            elseif (bucket == "morning" or bucket == "day")
                   and (prev == "late_night" or prev == "midnight")
                   and cdOk(sensorState.lastDawn, CONFIG.sensorDawnCD) then
                if trySensor(MSG.dawn, CONFIG.sensorDawnChance,
                             player, "sensor_dawn", {20, 60}) then
                    sensorState.lastDawn = now()
                end
            end
        end
    end
end

local function enterSilence()
    state.phase = STATE_SILENCE
    local dur = randomRange(CONFIG.silenceDuration)
    silenceTimer = os.startTimer(dur)
    dbg(string.format("entering silence for %.0fs", dur))
    log(string.format("silence %.0fs", dur))
end

local function activate(player)
    state.phase = STATE_ACTIVE
    state.targetPlayer = player
    state.sessionStart = now()
    state.messagesSent = 0
    state.lastTriggerType = nil
    state.usedMessages = {}
    state.selfGuardUntil = 0
    state.sessionMemory = {
        dimensionsVisited = {},
        deaths = 0,
        wentDeep = false,
        wentUnderwater = false,
        wentHighUp = false,
    }
    state.chatCount    = 0
    state.lastChatTime = 0
    cooldownUntil = 0

    -- Load previous session data for cross-session references
    loadSession()

    -- Reset sensor tracking for this session
    sensorState = {
        health    = nil, maxHealth = nil,
        air       = nil, posY      = nil,
        posX      = nil, posZ      = nil,
        yaw       = nil, pitch     = nil,
        wasUnderwater = false, wasCave = false, wasDeep = false,
        wasHighUp = false, wasSneaking = false, wasSprinting = false,
        wasRaining = false, wasThundering = false,
        moonPhase = nil, timeBucket = nil,
        stillPolls = 0,  -- consecutive polls with no position change
        -- Per-trigger last-fire timestamps
        lastLowHealth   = 0, lastCritHealth = 0, lastBigDamage  = 0,
        lastRespawn     = 0,
        lastUnderwater  = 0, lastUnderground = 0, lastDeep      = 0,
        lastHighUp      = 0, lastAfk        = 0,
        lastSpeed       = 0, lastSneak      = 0, lastSpin       = 0,
        lastPitch       = 0, lastReaction   = 0,
        lastStorm       = 0, lastThunder    = 0, lastMoon       = 0,
        lastNight       = 0, lastMidnight   = 0, lastDawn       = 0,
    }

    scheduleAmbient()
    sensorTimer = os.startTimer(CONFIG.sensorPollInterval)
    envTimer    = os.startTimer(CONFIG.envPollInterval)
    dbg("ACTIVATED: " .. player)
    log("ACTIVE " .. player .. " | session start")

    -- Standby memory persists into the first few ambients, then fades
    -- (cleared after first use in ambient handler via a timer)
    -- Don't clear immediately — the activation greeting might use it
end

local function deactivate(interrupted)
    local prev = state.phase
    local prevTarget = state.targetPlayer

    -- If the ghost was active and someone else joined, maybe say last words
    if interrupted and (prev == STATE_ACTIVE or prev == STATE_SILENCE)
       and prevTarget then
        if rollChance(CONFIG.interruptedChance) then
            local msg = pickFromPool(MSG.interrupted)
            if msg then
                msg = formatMessage(msg, prevTarget)
                if msg then
                    -- Send directly with very short delay via timer
                    -- (can't use queueMessage since we're about to clear pending)
                    local delay = randomRange(CONFIG.interruptedDelay)
                    local tid = os.startTimer(delay)
                    -- Store in a special slot that won't be cancelled
                    pendingTimers[tid] = {
                        message = msg,
                        target = prevTarget,
                        triggerType = "interrupted",
                        lastWords = true, -- flag: send even if dormant
                    }
                    dbg("LAST WORDS queued in " ..
                        string.format("%.0f", delay) .. "s")
                end
            end
        end
    end

    -- Save session summary for cross-session persistence
    if prev == STATE_ACTIVE or prev == STATE_SILENCE then
        saveSession()
    end

    state.phase = STATE_DORMANT
    state.targetPlayer = nil
    state._useBecomesAlone = nil
    standbyMemory.dormantSince = now()
    -- Cancel pending messages EXCEPT last words
    local preserved = {}
    for tid, msg in pairs(pendingTimers) do
        if msg.lastWords then
            preserved[tid] = msg
        end
    end
    pendingTimers = preserved
    awakeningTimer = nil
    silenceTimer   = nil
    ambientTimer   = nil
    sensorTimer    = nil
    envTimer       = nil
    dbg("DEACTIVATED")
    if prev ~= STATE_DORMANT then
        log("DORMANT | " .. (interrupted and "interrupted" or "target left"))
    end
    return prev ~= STATE_DORMANT
end

local function reconcileState()
    local players = updatePlayers()
    local count = #players

    -- Test mode: activate whenever testPlayer is online, ignore player count
    if CONFIG.testMode then
        local targetOnline = false
        for _, p in ipairs(players) do
            if p == CONFIG.testPlayer then
                targetOnline = true
                break
            end
        end
        if targetOnline then
            if state.phase == STATE_DORMANT then
                state.phase = STATE_AWAKENING
                state.targetPlayer = CONFIG.testPlayer
                local delay = randomRange({5, 15})  -- short delay for testing
                awakeningTimer = os.startTimer(delay)
                dbg("TEST AWAKENING: " .. CONFIG.testPlayer .. " in " ..
                    string.format("%.0f", delay) .. "s")
            end
        else
            if state.phase ~= STATE_DORMANT then
                deactivate(false)
            end
        end
        return
    end

    -- If the ghost is active/awakening but its target left, deactivate first.
    -- This prevents the ghost from silently switching targets and carrying
    -- one player's session (deaths, escalation, memory) to another player.
    if state.targetPlayer
       and (state.phase == STATE_ACTIVE or state.phase == STATE_SILENCE
            or state.phase == STATE_AWAKENING) then
        local targetStillHere = false
        for _, p in ipairs(players) do
            if p == state.targetPlayer then
                targetStillHere = true
                break
            end
        end
        if not targetStillHere then
            dbg("TARGET LEFT: " .. (state.targetPlayer or "?"))
            deactivate(false)  -- target left, not interrupted
        end
    end

    -- Normal mode: ghost only activates when exactly 1 player is online
    if count == 1 then
        if state.phase == STATE_DORMANT then
            -- Start awakening with a delay so it's not instant
            state.phase = STATE_AWAKENING
            state.targetPlayer = players[1]
            local delay = randomRange(CONFIG.awakeningDelay)
            awakeningTimer = os.startTimer(delay)
            dbg("AWAKENING: " .. players[1] .. " in " ..
                string.format("%.0f", delay) .. "s")
            log(string.format("awakening %s in %.0fs", players[1], delay))
        elseif state.phase == STATE_ACTIVE or state.phase == STATE_SILENCE then
            -- Verify target matches (should always match after the check above)
            if players[1] ~= state.targetPlayer then
                deactivate(false)
            end
        end
    elseif count > 1 then
        if state.phase ~= STATE_DORMANT then
            deactivate(true) -- interrupted: another player joined
        end
    elseif count == 0 then
        if state.phase ~= STATE_DORMANT then
            deactivate(false)
        end
    end

end

-- ────────────────────────────────────────────
--  EVENT HANDLING
-- ────────────────────────────────────────────

local function onChat(eventData)
    local username = eventData[2]
    local message  = eventData[3]

    -- Detect AP version: param 4 is boolean (old) or string uuid (new)
    local isHidden = false
    if type(eventData[4]) == "boolean" then
        isHidden = eventData[4]
    elseif type(eventData[5]) == "boolean" then
        isHidden = eventData[5]
    end

    -- Ignore hidden commands, empty messages
    if isHidden then return end
    if not message or message == "" then return end

    -- Standby intelligence: collect chat snippets while dormant
    if state.phase == STATE_DORMANT then
        local words = {}
        for w in message:lower():gmatch("%a+") do
            if #w >= 4 then table.insert(words, w) end
        end
        if #words >= 1 then
            table.insert(standbyMemory.chatSnippets, {
                player = username,
                word   = words[math.random(#words)],
            })
            -- Keep only last 10 snippets
            while #standbyMemory.chatSnippets > 10 do
                table.remove(standbyMemory.chatSnippets, 1)
            end
        end
        return
    end

    if state.phase ~= STATE_ACTIVE then return end
    -- In test mode, only respond to the test player
    if CONFIG.testMode then
        if username ~= CONFIG.testPlayer then return end
    end
    if username ~= state.targetPlayer then return end

    -- Self-message guard
    if now() < state.selfGuardUntil then return end

    dbg("CHAT [" .. username .. "]: " .. message)
    log("chat " .. username)

    -- Track chat cadence for silence detection
    state.chatCount    = (state.chatCount or 0) + 1
    state.lastChatTime = now()

    local response, triggerType = matchChat(message, username)
    if response then
        log("  matched -> " .. (triggerType or "?"))
        -- Apply formatting prefix if matchChat returned raw text
        -- (echo/omniscient paths bypass formatMessage)
        if CONFIG.formatPrefix ~= "" and not response:find(CONFIG.formatPrefix, 1, true) then
            response = CONFIG.formatPrefix .. response
        end
        -- Vary delay: longer messages get more "reading time"
        local extraRead = math.min(#message * 0.2, 15)
        local adjustedDelay = {
            CONFIG.chatDelay[1] + extraRead,
            CONFIG.chatDelay[2] + extraRead,
        }
        queueMessage(response, username, triggerType, adjustedDelay)
    end

    -- Track death mentions (skip if sensor already detected this death recently)
    if message:lower():find("died") or message:lower():find("dead")
       or message:lower():find("killed") then
        local recentSensorDeath = (sensorState.lastRespawn
            and (now() - sensorState.lastRespawn) < 60)
        if not recentSensorDeath then
            state.sessionMemory.deaths = state.sessionMemory.deaths + 1
        end
    end
end

local function onDimensionChange(eventData)
    local playerName = eventData[2]
    local fromDim    = eventData[3]
    local toDim      = eventData[4]

    if state.phase ~= STATE_ACTIVE then return end
    if playerName ~= state.targetPlayer then return end

    dbg("DIMENSION: " .. tostring(fromDim) .. " -> " .. tostring(toDim))
    log("dimension " .. playerName .. " -> " .. dimName(toDim))

    local toName   = dimName(toDim)
    local fromName = dimName(fromDim)

    -- Always record the dimension visit and sync sensor state,
    -- even if the ghost decides not to speak about it
    state.sessionMemory.dimensionsVisited[toName] = true
    sensorState.dimension = toName

    if not rollChance(CONFIG.dimensionChance) then return end

    -- Pick the right pool
    local pool = MSG.dimension_other

    if toName == "nether" then
        pool = MSG.enter_nether
    elseif toName == "end" then
        pool = MSG.enter_end
    elseif toName == "overworld" then
        if fromName == "nether" then
            pool = MSG.leave_nether
        elseif fromName == "end" then
            pool = MSG.leave_end
        end
    end

    local msg = pickFromPool(pool)
    if msg then
        msg = formatMessage(msg, playerName)
        queueMessage(msg, playerName, "dimension", CONFIG.dimensionDelay)
    end
end

local pendingJoinLeave = {} -- timerId -> {type, player}

local function onPlayerJoin(eventData)
    local playerName = eventData[2]
    dbg("JOIN: " .. tostring(playerName))
    log("join " .. tostring(playerName))
    local tid = os.startTimer(3)
    pendingJoinLeave[tid] = {type = "join", player = playerName}
end

local function onPlayerLeave(eventData)
    local playerName = eventData[2]
    dbg("LEAVE: " .. tostring(playerName))
    log("leave " .. tostring(playerName))
    local tid = os.startTimer(3)
    pendingJoinLeave[tid] = {type = "leave", player = playerName}
end

local function processJoinLeave(info)
    local prevPhase = state.phase
    reconcileState()

    if info.type == "join" then
        if state.phase == STATE_AWAKENING and info.player == state.targetPlayer then
            -- Already handling this via awakening timer
            return
        end
        -- If ghost just deactivated due to this join, the interrupted
        -- message was already handled inside deactivate() via reconcileState()
    end

    if info.type == "leave" then
        -- Track who left (standby intelligence)
        standbyMemory.lastLeftPlayer = info.player

        -- Someone left. If the ghost just activated (was dormant, now awakening),
        -- that means the target just became alone. The awakening timer handles
        -- the joins_alone greeting. But if the ghost was ALREADY dormant because
        -- 2+ players were on, and now exactly 1 remains, we want a "becomes alone"
        -- message instead of the generic "joins alone" greeting.
        if prevPhase == STATE_DORMANT
           and (state.phase == STATE_AWAKENING or state.phase == STATE_ACTIVE)
           and state.targetPlayer then
            -- Override: use becomes_alone pool instead of joins_alone
            -- Cancel the awakening timer's greeting (it will still activate the ghost)
            state._useBecomesAlone = true
        end
    end
end

local function onTimer(eventData)
    local timerId = eventData[2]

    -- Pending ghost message
    if pendingTimers[timerId] then
        local pending = pendingTimers[timerId]
        pendingTimers[timerId] = nil

        if (state.phase == STATE_ACTIVE or state.phase == STATE_SILENCE)
           or pending.lastWords then

            -- Stutter: rare "..." before the real message
            if not pending.lastWords and not pending.isStutter
               and math.random() < CONFIG.stutterChance then
                local stutter = "..."
                if CONFIG.formatPrefix ~= "" then
                    stutter = CONFIG.formatPrefix .. stutter
                end
                sendGhostMessage(stutter, pending.target)
                local delay = 2 + math.random() * 4
                local tid = os.startTimer(delay)
                pendingTimers[tid] = {
                    message     = pending.message,
                    target      = pending.target,
                    triggerType = pending.triggerType,
                    force       = pending.force,
                    isStutter   = true, -- prevent recursive stutter
                }
                return
            end

            -- force=true bypasses state check + cooldown check for:
            -- lastWords (sent while dormant), stutter follow-ups (sent after "..."),
            -- and reaction chain messages (sent shortly after the triggering message)
            sendGhostMessage(pending.message, pending.target,
                pending.lastWords or pending.isStutter or pending.force)
            state.lastTriggerType = pending.triggerType

            -- Random chance to enter silence after sending (not for last words)
            if not pending.lastWords and state.phase == STATE_ACTIVE
               and rollChance(CONFIG.silenceChance) then
                enterSilence()
            end
        else
            dbg("CANCELLED: state changed before send")
        end
        return
    end

    -- Join/leave deferred check
    if pendingJoinLeave[timerId] then
        local info = pendingJoinLeave[timerId]
        pendingJoinLeave[timerId] = nil
        processJoinLeave(info)
        return
    end

    -- Awakening timer
    if timerId == awakeningTimer then
        awakeningTimer = nil
        reconcileState()
        if state.phase == STATE_AWAKENING and state.targetPlayer then
            activate(state.targetPlayer)
            -- Pick the right greeting pool and config
            local pool, chance, delay
            if state._useBecomesAlone then
                pool  = MSG.becomes_alone
                chance = CONFIG.becomesAloneChance
                delay  = CONFIG.becomesAloneDelay
                state._useBecomesAlone = nil

                -- Standby override: sometimes reference who left or what was heard
                local r = math.random()
                if r < 0.25 and standbyMemory.lastLeftPlayer then
                    pool = MSG.standby_player_left
                elseif r < 0.35 then
                    -- Only use if the TARGET player actually chatted during standby
                    local targetChatted = false
                    for _, s in ipairs(standbyMemory.chatSnippets) do
                        if s.player == state.targetPlayer then
                            targetChatted = true
                            break
                        end
                    end
                    if targetChatted then
                        pool = MSG.standby_heard_chat
                    end
                elseif r < 0.40 and standbyMemory.dormantSince > 0
                       and (now() - standbyMemory.dormantSince) > 1800 then
                    pool = MSG.standby_long_dormant
                end
            else
                pool  = MSG.joins_alone
                chance = CONFIG.joinChance
                delay  = CONFIG.joinDelay
            end
            if rollChance(chance) then
                local msg = pickFromPool(pool)
                if msg then
                    msg = formatMessage(msg, state.targetPlayer)
                    queueMessage(msg, state.targetPlayer, "activation", delay)
                end
            end
        end
        return
    end

    -- Ambient timer
    if timerId == ambientTimer then
        ambientTimer = nil
        if state.phase == STATE_ACTIVE then
            -- Ghost gets restless if it hasn't spoken in a long time
            local ambientBoost = 1.0
            if state.lastMessageTime > 0 then
                local silentFor = now() - state.lastMessageTime
                if silentFor > 1800 then ambientBoost = 1.4 end
                if silentFor > 3600 then ambientBoost = 1.8 end
            end
            -- Cap effective chance before escalation mod is applied
            local boostedChance = math.min(CONFIG.ambientChance * ambientBoost, 0.45)
            if rollChance(boostedChance)
               and not onCooldown() then
                local msg = pickAmbientMessage(state.targetPlayer)
                if msg then
                    queueMessage(msg, state.targetPlayer, "ambient", {5, 30})
                end
            else
                log("ambient roll skip")
            end
            scheduleAmbient()
        elseif state.phase == STATE_SILENCE then
            scheduleAmbient()
        end
        return
    end

    -- Silence timer
    if timerId == silenceTimer then
        silenceTimer = nil
        if state.phase == STATE_SILENCE then
            state.phase = STATE_ACTIVE
            dbg("silence ended")
            -- Chance to acknowledge the silence ending
            if state.targetPlayer and rollChance(0.25) and not onCooldown() then
                local sbMsg = pickFromPool(MSG.silence_break)
                if sbMsg then
                    sbMsg = formatMessage(sbMsg, state.targetPlayer)
                    if sbMsg then
                        queueMessage(sbMsg, state.targetPlayer,
                            "silence_break", {8, 25})
                    end
                end
            end
        end
        return
    end

    -- Poll timer
    if timerId == pollTimer then
        pollTimer = nil
        reconcileState()
        local phaseNames = {
            [STATE_DORMANT] = "dormant", [STATE_AWAKENING] = "awakening",
            [STATE_ACTIVE] = "active", [STATE_SILENCE] = "silence",
        }
        log("poll " .. #state.onlinePlayers .. "p "
            .. (phaseNames[state.phase] or "?")
            .. (state.targetPlayer and (" " .. state.targetPlayer) or ""))
        -- Prune expired message history every ~20 polls (~15 minutes)
        if math.random() < 0.05 then pruneHistory() end
        pollTimer = os.startTimer(CONFIG.pollInterval)
        return
    end

    -- Sensor timer (player health / position)
    if timerId == sensorTimer then
        sensorTimer = nil
        pollSensors()
        if state.phase == STATE_ACTIVE or state.phase == STATE_SILENCE then
            sensorTimer = os.startTimer(CONFIG.sensorPollInterval)
        end
        return
    end

    -- Environment timer (weather / moon / time of day)
    if timerId == envTimer then
        envTimer = nil
        pollEnvironment()
        if state.phase == STATE_ACTIVE or state.phase == STATE_SILENCE then
            envTimer = os.startTimer(CONFIG.envPollInterval)
        end
        return
    end
end

-- ────────────────────────────────────────────
--  MAIN
-- ────────────────────────────────────────────

local function main()
    -- Seed RNG
    math.randomseed(os.epoch("utc"))
    for i = 1, 10 do math.random() end

    -- Test mode: auto-enable debug output
    if CONFIG.testMode then CONFIG.debug = true end

    -- Load and prune message history
    loadHistory()
    pruneHistory()

    -- Initial state
    reconcileState()

    -- Start polling
    pollTimer = os.startTimer(CONFIG.pollInterval)

    -- Display — look like a mundane server utility
    term.clear()
    term.setCursorPos(1, 1)
    if CONFIG.debug or CONFIG.testMode then
        print("=== GHOST" .. (CONFIG.testMode and " [TEST]" or "") .. " ===")
        print("Phase: " .. state.phase)
        print("Players: " .. #state.onlinePlayers)
        if CONFIG.testMode then
            print("Target: " .. CONFIG.testPlayer)
            print("Whisper: forced")
        end
        print("")
    else
        print("SrvMon v2.4.1")
        print("Monitoring server status...")
        print("Uplink: OK")
        print("")
    end

    -- Main event loop
    while true do
        local eventData = {os.pullEvent()}
        local event = eventData[1]

        if event == "chat" then
            onChat(eventData)
        elseif event == "playerChangedDimension" then
            onDimensionChange(eventData)
        elseif event == "playerJoin" then
            onPlayerJoin(eventData)
        elseif event == "playerLeave" then
            onPlayerLeave(eventData)
        elseif event == "timer" then
            onTimer(eventData)
        elseif event == "peripheral_detach" then
            -- Re-find peripherals; if critical ones are gone, go dormant
            chatBox  = peripheral.find("chatBox") or peripheral.find("chat_box")
            detector = peripheral.find("playerDetector") or peripheral.find("player_detector")
            envDetector = peripheral.find("environmentDetector") or peripheral.find("environment_detector")
            if not chatBox or not detector then
                if state.phase ~= STATE_DORMANT then
                    deactivate(false)
                end
                dbg("PERIPHERAL LOST — waiting for reattach")
            end
        elseif event == "peripheral" then
            -- Peripheral attached — try to recover
            if not chatBox then
                chatBox = peripheral.find("chatBox") or peripheral.find("chat_box")
            end
            if not detector then
                detector = peripheral.find("playerDetector") or peripheral.find("player_detector")
            end
            if not envDetector then
                envDetector = peripheral.find("environmentDetector") or peripheral.find("environment_detector")
            end
            if chatBox and detector then
                dbg("PERIPHERALS RESTORED")
                reconcileState()
            end
        end
    end
end

-- Run with automatic restart on errors
local MAX_RESTARTS = 10
local restarts = 0
while restarts < MAX_RESTARTS do
    local ok, err = pcall(main)
    if ok then break end  -- clean exit
    -- Ctrl+T: respect termination, don't restart
    if tostring(err):find("Terminated") then
        print("Ghost terminated.")
        break
    end
    restarts = restarts + 1
    -- Reset state for clean restart (timers are dead after a crash)
    state.phase = STATE_DORMANT
    state.targetPlayer = nil
    state._useBecomesAlone = nil
    pendingTimers = {}
    pendingJoinLeave = {}
    awakeningTimer = nil
    ambientTimer = nil
    pollTimer = nil
    silenceTimer = nil
    sensorTimer = nil
    envTimer = nil
    cooldownUntil = 0
    sensorState = {}
    -- Display error briefly then restart
    term.clear()
    term.setCursorPos(1, 1)
    if CONFIG.debug then
        printError("Ghost error: " .. tostring(err))
        print("Restarting (" .. restarts .. "/" .. MAX_RESTARTS .. ")...")
    else
        print("SrvMon v2.4.1")
        print("Reconnecting...")
    end
    sleep(5)
    -- Re-find peripherals in case they were the problem
    chatBox  = peripheral.find("chatBox") or peripheral.find("chat_box")
    detector = peripheral.find("playerDetector") or peripheral.find("player_detector")
    envDetector = peripheral.find("environmentDetector") or peripheral.find("environment_detector")
    if not chatBox or not detector then
        printError("Missing required peripheral. Waiting...")
        while not chatBox or not detector do
            os.pullEvent("peripheral")
            chatBox  = peripheral.find("chatBox") or peripheral.find("chat_box")
            detector = peripheral.find("playerDetector") or peripheral.find("player_detector")
            envDetector = peripheral.find("environmentDetector") or peripheral.find("environment_detector")
        end
        restarts = 0  -- reset counter after peripheral recovery
    end
end
if restarts >= MAX_RESTARTS then
    printError("Too many errors. Ghost stopped.")
end
