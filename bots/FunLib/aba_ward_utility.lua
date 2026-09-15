local X = {}

local J = require(GetScriptDirectory()..'/FunLib/jmz_func')

local nVisionRadius = 1600

-- Radiant Warding Spots
-- Game Start
local RADIANT_GAME_START_MID_1 = Vector(-249.706375, -1046.293945)
local RADIANT_GAME_START_MID_2 = Vector(-1615.225952, -122.014526)
local RADIANT_GAME_START_MID_3 = Vector(355.807343, -1645.619995)
local RADIANT_GAME_START_2 = Vector(1638.469482, -4640.707031)

-- Laning Phase
local RADIANT_LANE_PHASE_1 = Vector(-4014.073975, 2569.298340)
local RADIANT_LANE_PHASE_2 = Vector(-7552.072266, 3967.816162)
local RADIANT_LANE_PHASE_3 = Vector(-1615.225952, -122.014526)
local RADIANT_LANE_PHASE_4 = Vector(-868.482300, -783.444824)
local RADIANT_LANE_PHASE_5 = Vector(3097.361328, -4069.593018)
local RADIANT_LANE_PHASE_6 = Vector(7614.873047, -5381.669434)

-- Dire Warding Spots
-- Game Start
local DIRE_GAME_START_MID_1 = Vector(-471.729309, 360.174347)
local DIRE_GAME_START_MID_2 = Vector(1141.866211, -458.288147)
local DIRE_GAME_START_MID_3 = Vector(-926.699951, 1274.039062)
local DIRE_GAME_START_2 = Vector(-1472.750732, 3815.509766)

-- Laning Phase
local DIRE_LANE_PHASE_1 = Vector(-4310.856445, 3639.681885)
local DIRE_LANE_PHASE_2 = Vector(-7490.370117, 4741.802246)
local DIRE_LANE_PHASE_3 = Vector(-2159.649414, 1987.394531)
local DIRE_LANE_PHASE_4 = Vector(1141.866211, -458.288147)
local DIRE_LANE_PHASE_5 = Vector(3810.311523, -4562.782227)
local DIRE_LANE_PHASE_6 = Vector(7512.600586, -4630.147461)

local nTowerList = {
	TOWER_TOP_1,
	TOWER_MID_1,
	TOWER_BOT_1,
	TOWER_TOP_2,
	TOWER_MID_2,
	TOWER_BOT_2,
	TOWER_TOP_3,
	TOWER_MID_3,
	TOWER_BOT_3,
}

-- [wardcomma 20260915] THE ONE MISSING COMMA IN bots/, HOISTED SO BOTH VALUES
-- HAVE A NAME. The shipped literal below is kept BYTE FOR BYTE -- it is still
-- `Vector(-2414.402100 -3802.327637)`, one argument, a subtraction -- because
-- the un-armed path must answer with the exact number it answers with today.
-- See the head note on X.ApplyWardCommaFix (just above the two spot producers)
-- for what the typo does and why the correction is gated rather than just made.
local WARD_MID3_R3_SHIPPED = Vector(-2414.402100 -3802.327637)
local WARD_MID3_R3_FIXED   = Vector(-2414.402100, -3802.327637)

-- [warddupkey 20260915] THE THREE DUPLICATE TABLE KEYS IN bots/, HOISTED SO THE
-- SWALLOWED VALUE HAS A NAME. Each of the three groups below writes the same
-- integer key twice; Lua keeps the LAST assignment, so the first spot is not
-- "wrong", it does not exist at run time -- the group is one spot short and
-- nothing anywhere says so. The duplicate keys are LEFT IN PLACE, exactly as
-- written: the shipped table must still answer with the second value, and the
-- duplicate itself is the only witness that this file is what it is
-- (tests/test_warddupkey_eaten_spots.lua re-runs the census rather than quoting
-- it). See the head note on X.ApplyWardDupKeyFix for what is restored and why
-- the restoration is gated rather than just made.
local WARD_DUP_DIRE_MID1_EATEN = Vector(-2400.793457, 1431.276611)
local WARD_DUP_DIRE_TOP3_EATEN = Vector(605.637573, 6996.875977)
local WARD_DUP_DIRE_TOP2_EATEN = Vector(-5217.980957, -1648.555908)

-- #############################################################
-- RADIANT
-- #############################################################
local WardLocationsBeforeAllyTowerFall__Radiant = {
	[TOWER_TOP_1] = {
		[1] = { location = Vector(-6309.000000, 5671.123535), plant_time_obs = 0, plant_time_sentry = 0, },
		[2] = { location = Vector(-6726.650879, 3244.411621), plant_time_obs = 0, plant_time_sentry = 0, },
		[3] = { location = Vector(-3311.859619, 4315.231445), plant_time_obs = 0, plant_time_sentry = 0, },
	},
	[TOWER_MID_1] = {
		[1] = { location = Vector(2255.840820, -1892.881836), plant_time_obs = 0, plant_time_sentry = 0, },
		[2] = { location = Vector(-416.000000, 224.000000), plant_time_obs = 0, plant_time_sentry = 0, },
		[3] = { location = Vector(-2606.656250, 1702.770752), plant_time_obs = 0, plant_time_sentry = 0, },
		[4] = { location = Vector(1067.144287, -2554.027832), plant_time_obs = 0, plant_time_sentry = 0, },
	},
	[TOWER_BOT_1] = {
		[1] = { location = Vector(5365.699707, -4870.313965), plant_time_obs = 0, plant_time_sentry = 0, },
		[2] = { location = Vector(5870.312500, -7174.024414), plant_time_obs = 0, plant_time_sentry = 0, },
		[3] = { location = Vector(3097.361328, -4069.593018), plant_time_obs = 0, plant_time_sentry = 0, },
		[4] = { location = Vector(1824.772705, -3358.895996), plant_time_obs = 0, plant_time_sentry = 0, },
	},

	[TOWER_TOP_2] = {
		[1] = { location = Vector(-7923.261719, 1820.198730), plant_time_obs = 0, plant_time_sentry = 0, },
		[2] = { location = Vector(-4199.289062, 1328.263062), plant_time_obs = 0, plant_time_sentry = 0, },
		[3] = { location = Vector(-4334.572266, -1036.464844), plant_time_obs = 0, plant_time_sentry = 0, },
		[4] = { location = Vector(-4245.528320, 357.413574), plant_time_obs = 0, plant_time_sentry = 0, },
		[5] = { location = Vector(-4562.793457, 1873.175537), plant_time_obs = 0, plant_time_sentry = 0, },
		[6] = { location = Vector(-7579.524902, 493.309631), plant_time_obs = 0, plant_time_sentry = 0, },
		[7] = { location = Vector(-3380.673828, 672.909180), plant_time_obs = 0, plant_time_sentry = 0, },
		[8] = { location = Vector(-8416.000000, 2272.000000), plant_time_obs = 0, plant_time_sentry = 0, },
		[9] = { location = Vector(-5152.000000, 2336.000000), plant_time_obs = 0, plant_time_sentry = 0, },
	},
	[TOWER_MID_2] = {
		[1] = { location = Vector(-1288.532471, -4351.110352), plant_time_obs = 0, plant_time_sentry = 0, },
		[2] = { location = Vector(-4334.572266, -1036.464844), plant_time_obs = 0, plant_time_sentry = 0, },
		[3] = { location = Vector(-995.484375, -2654.527832), plant_time_obs = 0, plant_time_sentry = 0, },
		[4] = { location = Vector(104.285484, -3576.448242), plant_time_obs = 0, plant_time_sentry = 0, },
		[5] = { location = Vector(-3322.988037, -200.036987), plant_time_obs = 0, plant_time_sentry = 0, },
		[6] = { location = Vector(-2458.159668, -1210.825439), plant_time_obs = 0, plant_time_sentry = 0, },
		[7] = { location = Vector(-4245.528320, 357.413574), plant_time_obs = 0, plant_time_sentry = 0, },
	},
	[TOWER_BOT_2] = {
		[1] = { location = Vector(2258.137207, -7110.736328), plant_time_obs = 0, plant_time_sentry = 0, },
		[2] = { location = Vector(2049.426514, -8427.432617), plant_time_obs = 0, plant_time_sentry = 0, },
		[3] = { location = Vector(2033.350830, -4917.041992), plant_time_obs = 0, plant_time_sentry = 0, },
		[4] = { location = Vector(-682.876953, -7909.373047), plant_time_obs = 0, plant_time_sentry = 0, },
		[5] = { location = Vector(361.339355, -4027.959473), plant_time_obs = 0, plant_time_sentry = 0, },
	},

	[TOWER_TOP_3] = {
		[1] = { location = Vector(-7497.418457, -1303.780396), plant_time_obs = 0, plant_time_sentry = 0, },
		[2] = { location = Vector(-5464.000000, -2335.000000), plant_time_obs = 0, plant_time_sentry = 0, },
		[3] = { location = Vector(-6578.378906, -3101.990479), plant_time_obs = 0, plant_time_sentry = 0, },
		[4] = { location = Vector(-5014.221191, -1732.490723), plant_time_obs = 0, plant_time_sentry = 0, },
		[5] = { location = Vector(-5915.992676, -3089.985596), plant_time_obs = 0, plant_time_sentry = 0, },
	},
	[TOWER_MID_3] = {
		[1] = { location = Vector(-4377.171387, -3911.893555), plant_time_obs = 0, plant_time_sentry = 0, },
		[2] = { location = Vector(-3888.701904, -1594.625244), plant_time_obs = 0, plant_time_sentry = 0, },
		[3] = { location = WARD_MID3_R3_SHIPPED, plant_time_obs = 0, plant_time_sentry = 0, },
		[4] = { location = Vector(-4334.572266, -1036.464844), plant_time_obs = 0, plant_time_sentry = 0, },
		[5] = { location = Vector(-2706.345459, -1664.330566), plant_time_obs = 0, plant_time_sentry = 0, },
		[6] = { location = Vector(-1288.418091, -4359.833496), plant_time_obs = 0, plant_time_sentry = 0, },
	},
	[TOWER_BOT_3] = {
		[1] = { location = Vector(-3628.625244, -6110.583496), plant_time_obs = 0, plant_time_sentry = 0, },
		[2] = { location = Vector(-2515.698975, -7325.979492), plant_time_obs = 0, plant_time_sentry = 0, },
		[3] = { location = Vector(-1978.637329, -6093.620117), plant_time_obs = 0, plant_time_sentry = 0, },
		[4] = { location = Vector(-3128.099609, -4716.803223), plant_time_obs = 0, plant_time_sentry = 0, },
		[5] = { location = Vector(-3532.540771, -6960.055176), plant_time_obs = 0, plant_time_sentry = 0, },
	},
}

local WardLocationsAfterEnemyTowerFall__Radiant = {
	[TOWER_TOP_1] = {
		[1] = { location = Vector(-6141.217773, 7387.221680), plant_time_obs = 0, plant_time_sentry = 0, },
		[2] = { location = Vector(-1520.533691, 7675.010742), plant_time_obs = 0, plant_time_sentry = 0, },
		[3] = { location = Vector(-2108.795898, 4265.250000), plant_time_obs = 0, plant_time_sentry = 0, },
		[4] = { location = Vector(-4082.341309, 7135.104492), plant_time_obs = 0, plant_time_sentry = 0, },
		[5] = { location = Vector(-4620.397461, 4879.798340), plant_time_obs = 0, plant_time_sentry = 0, },
		[6] = { location = Vector(-2384.553955, 4859.611328), plant_time_obs = 0, plant_time_sentry = 0, },
		[7] = { location = Vector(-2085.847412, 3290.809814), plant_time_obs = 0, plant_time_sentry = 0, },
		[8] = { location = Vector(-5648.824219, 5342.285645), plant_time_obs = 0, plant_time_sentry = 0, },
	},
	[TOWER_MID_1] = {
		[1] = { location = Vector(-501.130188, 2374.691895), plant_time_obs = 0, plant_time_sentry = 0, },
		[2] = { location = Vector(857.109497, 1693.968018), plant_time_obs = 0, plant_time_sentry = 0, },
		[3] = { location = Vector(4613.312500, 755.917847), plant_time_obs = 0, plant_time_sentry = 0, },
		[4] = { location = Vector(3006.320068, -347.194275), plant_time_obs = 0, plant_time_sentry = 0, },
		[5] = { location = Vector(3454.585449, 965.981628), plant_time_obs = 0, plant_time_sentry = 0, },
		[6] = { location = Vector(4564.609375, 1342.290283), plant_time_obs = 0, plant_time_sentry = 0, },
		[7] = { location = Vector(-64.840370, 1206.849365), plant_time_obs = 0, plant_time_sentry = 0, },
		[8] = { location = Vector(-876.541870, 3462.283203), plant_time_obs = 0, plant_time_sentry = 0, },
		[9] = { location = Vector(929.558411, -178.148193), plant_time_obs = 0, plant_time_sentry = 0, },
	},
	[TOWER_BOT_1] = {
		[1] = { location = Vector(4719.973145, -1828.040405), plant_time_obs = 0, plant_time_sentry = 0, },
		[2] = { location = Vector(7695.852539, -1561.971436), plant_time_obs = 0, plant_time_sentry = 0, },
		[3] = { location = Vector(5092.339844, -366.790771), plant_time_obs = 0, plant_time_sentry = 0, },
		[4] = { location = Vector(3880.949219, -879.248657), plant_time_obs = 0, plant_time_sentry = 0, },
		[5] = { location = Vector(8427.142578, -704.303223), plant_time_obs = 0, plant_time_sentry = 0, },
		[6] = { location = Vector(4330.230469, -3323.803223), plant_time_obs = 0, plant_time_sentry = 0, },
		[7] = { location = Vector(2822.328369, -1504.332764), plant_time_obs = 0, plant_time_sentry = 0, },
		[8] = { location = Vector(4613.312500, 755.917847), plant_time_obs = 0, plant_time_sentry = 0, },
		[9] = { location = Vector(8137.696289, 415.701904), plant_time_obs = 0, plant_time_sentry = 0, },
	},

	[TOWER_TOP_2] = {
		[1] = { location = Vector(1019.997620, 3568.473633), plant_time_obs = 0, plant_time_sentry = 0, },
		[2] = { location = Vector(-707.014709, 7638.974609), plant_time_obs = 0, plant_time_sentry = 0, },
		[3] = { location = Vector(3045.438477, 5003.273438), plant_time_obs = 0, plant_time_sentry = 0, },
		[4] = { location = Vector(2250.127686, 4692.457520), plant_time_obs = 0, plant_time_sentry = 0, },
		[5] = { location = Vector(429.645172, 4669.281250), plant_time_obs = 0, plant_time_sentry = 0, },
		[6] = { location = Vector(1767.005737, 7348.324707), plant_time_obs = 0, plant_time_sentry = 0, },
	},
	[TOWER_MID_2] = {
		[1] = { location = Vector(4613.312500, 755.917847), plant_time_obs = 0, plant_time_sentry = 0, },
		[2] = { location = Vector(3429.349609, 958.148438), plant_time_obs = 0, plant_time_sentry = 0, },
		[3] = { location = Vector(1015.765564, 3570.294434), plant_time_obs = 0, plant_time_sentry = 0, },
		[4] = { location = Vector(4578.642578, 2904.757324), plant_time_obs = 0, plant_time_sentry = 0, },
		[5] = { location = Vector(3382.799316, 4072.131836), plant_time_obs = 0, plant_time_sentry = 0, },
		[6] = { location = Vector(2671.740967, 1842.921387), plant_time_obs = 0, plant_time_sentry = 0, },
	},
	[TOWER_BOT_2] = {
		[1] = { location = Vector(8137.696289, 415.701904), plant_time_obs = 0, plant_time_sentry = 0, },
		[2] = { location = Vector(4613.312500, 755.917847), plant_time_obs = 0, plant_time_sentry = 0, },
		[3] = { location = Vector(5499.228027, 2687.067871), plant_time_obs = 0, plant_time_sentry = 0, },
		[4] = { location = Vector(5367.971680, 1197.417236), plant_time_obs = 0, plant_time_sentry = 0, },
	},

	[TOWER_TOP_3] = {
		[1] = { location = Vector(2239.004395, 4694.355469), plant_time_obs = 0, plant_time_sentry = 0, },
		[2] = { location = Vector(1936.913818, 7349.268555), plant_time_obs = 0, plant_time_sentry = 0, },
		[3] = { location = Vector(4439.182617, 5550.124512), plant_time_obs = 0, plant_time_sentry = 0, },
	},
	[TOWER_MID_3] = {
		[1] = { location = Vector(4493.447754, 3960.869385), plant_time_obs = 0, plant_time_sentry = 0, },
		[2] = { location = Vector(5898.282715, 5387.940430), plant_time_obs = 0, plant_time_sentry = 0, },
		[3] = { location = Vector(2878.860840, 3631.565918), plant_time_obs = 0, plant_time_sentry = 0, },
	},
	[TOWER_BOT_3] = {
		[1] = { location = Vector(6335.169922, 4065.608643), plant_time_obs = 0, plant_time_sentry = 0, },
		[2] = { location = Vector(5338.760254, 2737.025879), plant_time_obs = 0, plant_time_sentry = 0, },
	},
}

-- #############################################################
-- DIRE
-- #############################################################
local WardLocationsBeforeAllyTowerFall__Dire = {
	[TOWER_TOP_1] = {
		[1] = { location = Vector(-7645.819824, 4469.880371), plant_time_obs = 0, plant_time_sentry = 0, },
		[2] = { location = Vector(-5775.200195, 2600.540527), plant_time_obs = 0, plant_time_sentry = 0, },
		[3] = { location = Vector(-3994.346924, 3636.463135), plant_time_obs = 0, plant_time_sentry = 0, },
	},
	[TOWER_MID_1] = {
		[1] = { location = Vector(-917.716919, 1233.115723), plant_time_obs = 0, plant_time_sentry = 0, },
		[2] = { location = Vector(2769.960693, -1521.609985), plant_time_obs = 0, plant_time_sentry = 0, },
		[3] = { location = Vector(-1679.397339, 3541.931396), plant_time_obs = 0, plant_time_sentry = 0, },
		[4] = { location = WARD_DUP_DIRE_MID1_EATEN, plant_time_obs = 0, plant_time_sentry = 0, },
		[4] = { location = Vector(1631.129028, -604.961731), plant_time_obs = 0, plant_time_sentry = 0, },
	},
	[TOWER_BOT_1] = {
		[1] = { location = Vector(4318.670410, -3305.405518), plant_time_obs = 0, plant_time_sentry = 0, },
		[2] = { location = Vector(4670.166504, -1949.093018), plant_time_obs = 0, plant_time_sentry = 0, },
		[3] = { location = Vector(6391.976074, -4914.761230), plant_time_obs = 0, plant_time_sentry = 0, },
	},

	[TOWER_TOP_2] = {
		[1] = { location = Vector(-1679.397339, 3541.931396), plant_time_obs = 0, plant_time_sentry = 0, },
		[2] = { location = Vector(-1531.722900, 7651.007324), plant_time_obs = 0, plant_time_sentry = 0, },
		[3] = { location = Vector(-4283.493164, 6410.409668), plant_time_obs = 0, plant_time_sentry = 0, },
		[4] = { location = Vector(-2553.300049, 4773.497070), plant_time_obs = 0, plant_time_sentry = 0, },
		[5] = { location = Vector(-2428.735596, 6744.824219), plant_time_obs = 0, plant_time_sentry = 0, },
	},
	[TOWER_MID_2] = {
		[1] = { location = Vector(3335.353760, -207.220703), plant_time_obs = 0, plant_time_sentry = 0, },
		[2] = { location = Vector(1029.402222, 3571.081055), plant_time_obs = 0, plant_time_sentry = 0, },
		[3] = { location = Vector(-1679.397339, 3541.931396), plant_time_obs = 0, plant_time_sentry = 0, },
		[4] = { location = Vector(279.710938, 1104.007568), plant_time_obs = 0, plant_time_sentry = 0, },
		[5] = { location = Vector(2844.631592, -1560.403564), plant_time_obs = 0, plant_time_sentry = 0, },
	},
	[TOWER_BOT_2] = {
		[1] = { location = Vector(7695.852539, -1561.971436), plant_time_obs = 0, plant_time_sentry = 0, },
		[2] = { location = Vector(4613.312500, 755.917847), plant_time_obs = 0, plant_time_sentry = 0, },
		[3] = { location = Vector(8432.747070, -379.338318), plant_time_obs = 0, plant_time_sentry = 0, },
		[4] = { location = Vector(6716.602539, -2427.237305), plant_time_obs = 0, plant_time_sentry = 0, },
		[5] = { location = Vector(3433.443604, -733.166626), plant_time_obs = 0, plant_time_sentry = 0, },
	},

	[TOWER_TOP_3] = {
		[1] = { location = Vector(3126.187500, 5750.492676), plant_time_obs = 0, plant_time_sentry = 0, },
		[2] = { location = Vector(1029.402222, 3571.081055), plant_time_obs = 0, plant_time_sentry = 0, },
		[3] = { location = Vector(450.604736, 4730.952148), plant_time_obs = 0, plant_time_sentry = 0, },
		[4] = { location = WARD_DUP_DIRE_TOP3_EATEN, plant_time_obs = 0, plant_time_sentry = 0, },
		[4] = { location = Vector(2174.007812, 4253.548828), plant_time_obs = 0, plant_time_sentry = 0, },
	},
	[TOWER_MID_3] = {
		[1] = { location = Vector(4041.562256, 3465.514893), plant_time_obs = 0, plant_time_sentry = 0, },
		[2] = { location = Vector(4613.312500, 755.917847), plant_time_obs = 0, plant_time_sentry = 0, },
		[3] = { location = Vector(1029.402222, 3571.081055), plant_time_obs = 0, plant_time_sentry = 0, },
		[4] = { location = Vector(2806.711182, 1943.263550), plant_time_obs = 0, plant_time_sentry = 0, },
	},
	[TOWER_BOT_3] = {
		[1] = { location = Vector(6344.555176, 2640.419678), plant_time_obs = 0, plant_time_sentry = 0, },
		[2] = { location = Vector(4613.312500, 755.917847), plant_time_obs = 0, plant_time_sentry = 0, },
		[3] = { location = Vector(8107.012695, 457.608398), plant_time_obs = 0, plant_time_sentry = 0, },
		[4] = { location = Vector(6536.082520, -1299.558472), plant_time_obs = 0, plant_time_sentry = 0, },
	},
}

local WardLocationsAfterEnemyTowerFall__Dire = {
	[TOWER_TOP_1] = {
		[1] = { location = Vector(-4006.174316, 269.627747), plant_time_obs = 0, plant_time_sentry = 0, },
		[2] = { location = Vector(-7923.261719, 1820.198730), plant_time_obs = 0, plant_time_sentry = 0, },
		[3] = { location = Vector(-7918.682129, 56.263672), plant_time_obs = 0, plant_time_sentry = 0, },
		[4] = { location = Vector(-4334.572266, -1036.464844), plant_time_obs = 0, plant_time_sentry = 0, },
	},
	[TOWER_MID_1] = {
		[1] = { location = Vector(-4334.572266, -1036.464844), plant_time_obs = 0, plant_time_sentry = 0, },
		[2] = { location = Vector(-3542.703857, -509.485474), plant_time_obs = 0, plant_time_sentry = 0, },
		[3] = { location = Vector(-830.539551, -2626.359131), plant_time_obs = 0, plant_time_sentry = 0, },
		[4] = { location = Vector(-1288.532471, -4351.110352), plant_time_obs = 0, plant_time_sentry = 0, },
	},
	[TOWER_BOT_1] = {
		[1] = { location = Vector(2101.796875, -4957.856445), plant_time_obs = 0, plant_time_sentry = 0, },
		[2] = { location = Vector(3906.684570, -7174.484375), plant_time_obs = 0, plant_time_sentry = 0, },
		[3] = { location = Vector(3533.874512, -7856.141113), plant_time_obs = 0, plant_time_sentry = 0, },
		[4] = { location = Vector(2259.454590, -7111.220215), plant_time_obs = 0, plant_time_sentry = 0, },
		[5] = { location = Vector(1694.457642, -5533.504395), plant_time_obs = 0, plant_time_sentry = 0, },
		[6] = { location = Vector(2050.627686, -8429.074219), plant_time_obs = 0, plant_time_sentry = 0, },
	},

	[TOWER_TOP_2] = {
		[1] = { location = WARD_DUP_DIRE_TOP2_EATEN, plant_time_obs = 0, plant_time_sentry = 0, },
		[1] = { location = Vector(-4334.572266, -1036.464844), plant_time_obs = 0, plant_time_sentry = 0, },
		[2] = { location = Vector(-7579.280762, -1119.693848), plant_time_obs = 0, plant_time_sentry = 0, },
		[3] = { location = Vector(-5685, -3139), plant_time_obs = 0, plant_time_sentry = 0, },
	},
	[TOWER_MID_2] = {
		[1] = { location = Vector(-1288.532471, -4351.110352), plant_time_obs = 0, plant_time_sentry = 0, },
		[2] = { location = Vector(-4334.572266, -1036.464844), plant_time_obs = 0, plant_time_sentry = 0, },
		[3] = { location = Vector(-4300.054199, -1757.872803), plant_time_obs = 0, plant_time_sentry = 0, },
		[4] = { location = Vector(-3788.625732, -4484.107910), plant_time_obs = 0, plant_time_sentry = 0, },
		[5] = { location = Vector(-5168.498535, -3407.188477), plant_time_obs = 0, plant_time_sentry = 0, },
		[6] = { location = Vector(-5347.964844, -2573.015381), plant_time_obs = 0, plant_time_sentry = 0, },
		[7] = { location = Vector(-2470.028320, -3950.313232), plant_time_obs = 0, plant_time_sentry = 0, },
	},
	[TOWER_BOT_2] = {
		[1] = { location = Vector(-1288.532471, -4351.110352), plant_time_obs = 0, plant_time_sentry = 0, },
		[2] = { location = Vector(-1954.655029, -7911.340820), plant_time_obs = 0, plant_time_sentry = 0, },
		[3] = { location = Vector(-3542.787598, -6944.415527), plant_time_obs = 0, plant_time_sentry = 0, },
		[4] = { location = Vector(-3612.549805, -5252.114258), plant_time_obs = 0, plant_time_sentry = 0, },
		[5] = { location = Vector(-2632.111328, -5009.849609), plant_time_obs = 0, plant_time_sentry = 0, },
	},

	[TOWER_TOP_3] = {
		[1] = { location = Vector(-6401, -4286, 256), plant_time_obs = 0, plant_time_sentry = 0, },
	},
	[TOWER_MID_3] = {
		[1] = { location = Vector(-4867.748047, -4425.016113), plant_time_obs = 0, plant_time_sentry = 0, },
		[3] = { location = Vector(-6194.468262, -5706.500488), plant_time_obs = 0, plant_time_sentry = 0, },
	},
	[TOWER_BOT_3] = {
		[1] = { location = Vector(-4876.913574, -5980.851562), plant_time_obs = 0, plant_time_sentry = 0, },
		[2] = { location = Vector(-2632.111328, -5009.849609), plant_time_obs = 0, plant_time_sentry = 0, },
	},
}

local WardLocationsEarlyGame__Radiant = {
	[1] = { location = RADIANT_LANE_PHASE_1, plant_time_obs = 0, plant_time_sentry = 0, },
	[2] = { location = RADIANT_LANE_PHASE_2, plant_time_obs = 0, plant_time_sentry = 0, },
	[3] = { location = RADIANT_LANE_PHASE_3, plant_time_obs = 0, plant_time_sentry = 0, },
	[4] = { location = RADIANT_LANE_PHASE_4, plant_time_obs = 0, plant_time_sentry = 0, },
	[5] = { location = RADIANT_LANE_PHASE_5, plant_time_obs = 0, plant_time_sentry = 0, },
	[6] = { location = RADIANT_LANE_PHASE_6, plant_time_obs = 0, plant_time_sentry = 0, },
}

local WardLocationsEarlyGame__Dire = {
	[1] = { location = DIRE_LANE_PHASE_1, plant_time_obs = 0, plant_time_sentry = 0, },
	[2] = { location = DIRE_LANE_PHASE_2, plant_time_obs = 0, plant_time_sentry = 0, },
	[3] = { location = DIRE_LANE_PHASE_3, plant_time_obs = 0, plant_time_sentry = 0, },
	[4] = { location = DIRE_LANE_PHASE_4, plant_time_obs = 0, plant_time_sentry = 0, },
	[5] = { location = DIRE_LANE_PHASE_5, plant_time_obs = 0, plant_time_sentry = 0, },
	[6] = { location = DIRE_LANE_PHASE_6, plant_time_obs = 0, plant_time_sentry = 0, },
}
function X.GetEarlyGameWardSpots()
	return GetTeam() == TEAM_RADIANT and WardLocationsEarlyGame__Radiant or WardLocationsEarlyGame__Dire
end

local WardSpotRadiant = nil
local WardSpotDire = nil
function X.GetGameStartWardSpots()
	if WardSpotRadiant == nil then
		local hMidWardSpots = {
			RADIANT_GAME_START_MID_1,
			RADIANT_GAME_START_MID_2,
			RADIANT_GAME_START_MID_3,
		}

		local vWardMidSpot = hMidWardSpots[RandomInt(1, #hMidWardSpots)]

		WardSpotRadiant = {
			[1] = { location = vWardMidSpot, plant_time_obs = 0, plant_time_sentry = 0, },
			[2] = { location = RADIANT_GAME_START_2, plant_time_obs = 0, plant_time_sentry = 0, },
		}
	end

	if WardSpotDire == nil then
		local hMidWardSpots = {
			DIRE_GAME_START_MID_1,
			DIRE_GAME_START_MID_2,
			DIRE_GAME_START_MID_3,
		}
		local vWardMidSpot = hMidWardSpots[RandomInt(1, #hMidWardSpots)]

		WardSpotDire = {
			[1] = { location = vWardMidSpot, plant_time_obs = 0, plant_time_sentry = 0, },
			[2] = { location = DIRE_GAME_START_2, plant_time_obs = 0, plant_time_sentry = 0, },
		}
	end

	return GetTeam() == TEAM_RADIANT and WardSpotRadiant or WardSpotDire
end

-- [wardcomma 20260915] Soak candidate 'wardcomma' (turbo-only). ONE COORDINATE
-- MOVES; no spot is added, no spot is removed, no clause is relaxed.
--
-- ⭐ THE DEFECT, closed form -- a statement about SOURCE, not a frequency.
-- `WardLocationsBeforeAllyTowerFall__Radiant[TOWER_MID_3][3]` is written
--
--     Vector(-2414.402100 -3802.327637)
--
-- with no comma between the two numbers, so Lua reads it as ONE argument, the
-- subtraction `-2414.402100 - 3802.327637`, and the spot lands at
-- **(-6216.729737, 0)** instead of (-2414.4, -3802.3) -- 4,723 units away, on
-- the far west edge at y EXACTLY zero, while every other member of the same
-- mid-tier-3 group sits in a cluster around (-3300, -2500). It is the ONLY such
-- literal in bots/: a scan of every `Vector(` call in the tree finds exactly one
-- (tests/test_wardcomma_mid3_spot.lua re-runs that scan rather than quoting it),
-- so this is a typo, not a convention. luacheck cannot see it -- the expression
-- is valid Lua -- and the smoke loader cannot either, because it loads fine.
--
-- ⭐⭐ WHY IT IS A BEHAVIOUR FINDING AND NOT A TIDINESS ONE. The corrupted point
-- is not merely wrong, it is wrong TOWARD the bot: X.GetClosestObserverWardSpot
-- is an argmin over distance-to-bot, so a spot dragged 4.7k units across the map
-- competes for the pick from wherever it lands. Measured on the fixture corpus
-- (112 fixtures, 104 real radiant hero-frames at position >= 4, i.e. the bots
-- mode_ward_generic's own `J.GetPosition(bot) <= 3` gate admits): with the
-- mid-tier-2 tower declared down (see the debt below), the broken spot is in the
-- candidate list on 104/104 and is the ARGMIN -- the spot the bot walks to and
-- plants on -- on 8. On the bearing frame it is 760u from the bot while the spot
-- it was meant to be is 5,788u away: inside mode_ward_generic's 3200u desire
-- gate versus far outside it. The typo is what makes the mode fire at all there.
--
-- DOMAIN, AND THE HALF THIS CORPUS CANNOT BUY (declared, not buried). The
-- MID_3 group is only read once our own mid tier-2 has fallen while tier-3
-- stands. Shipped tower state over the same 104 frames reaches it 0 times --
-- the corpus stops at t=850.1s and carries no game that far along. That zero is
-- the CORPUS-COVERAGE kind, not the constructive kind (GH #838): the branch runs
-- in every game that loses a mid tier-2, which in Turbo is most of them. The
-- test declares that one ordinary state and drives everything else -- every hero,
-- every position, every distance -- off real frames. `queue.json:strategy-48`
-- asks the replay desk for a post-tier-2 frame so the declaration can retire.
--
-- SHAPE. Resolved ONCE, on the spot OBJECT, at the head of the only two
-- producers that read these tables -- so the observer path, the sentry path,
-- X.GetClosestObserverWardSpot's argmin, mode_ward_generic's 3200u desire test
-- and the Action_UseAbilityOnLocation that finally plants the ward all read the
-- same coordinate, and the `plant_time_obs` / `plant_time_sentry` bookkeeping
-- stays on the same table (a corrected COPY would silently fork that state).
-- Un-armed the `if` falls out on its first conjunct and the table is the shipped
-- one, identity and all. Single id, conjoined with nothing (no 'pullcad' trap).
-- Radiant-only BY CONSTRUCTION -- the typo is in the __Radiant table and
-- GetTeam() picks the side -- so in a mirrored A/B this id has a domain only on
-- the leg whose armed side is radiant; a reader must not treat the dire leg's
-- zero as evidence about the lever.
--
-- DECLARED CONSEQUENCE, not a hidden one: the corrected point is subject to the
-- same `IsLocationPassable(spot.location)` test as every other spot, so if the
-- intended coordinate is impassable the armed list is one spot SHORTER rather
-- than one spot moved. That is the only way armed can change the size of the
-- list, and it is asserted in the test rather than promised here.
local tWardCommaSpot = WardLocationsBeforeAllyTowerFall__Radiant[TOWER_MID_3][3]
function X.ApplyWardCommaFix()
	if tWardCommaSpot.location ~= WARD_MID3_R3_SHIPPED then return end
	if not (J.IsModeTurbo() and J.IsSoakCandidate('wardcomma')) then return end
	tWardCommaSpot.location = WARD_MID3_R3_FIXED
end

-- [warddupkey 20260915] Soak candidate 'warddupkey' (turbo-only). THREE SPOTS
-- COME BACK; no spot is moved, no spot is removed, no clause is relaxed, no
-- coordinate is invented.
--
-- ⭐ THE DEFECT, closed form -- a statement about SOURCE, not a frequency.
-- Three table constructors in this file write the same integer key twice:
--
--   WardLocationsBeforeAllyTowerFall__Dire[TOWER_MID_1]  [4] twice
--   WardLocationsBeforeAllyTowerFall__Dire[TOWER_TOP_3]  [4] twice
--   WardLocationsAfterEnemyTowerFall__Dire[TOWER_TOP_2]  [1] twice
--
-- Lua keeps the LAST assignment, so in each group the FIRST of the pair is not
-- a wrong spot, it is a spot that does not exist -- the group is one shorter
-- than it reads, and nothing anywhere says so. These are the ONLY three
-- duplicate keys in a spot table in bots/ (tools/agent/table_dup_key_census.py
-- re-runs the scan; the other four hits in the tree are in FretBots sound
-- tables, a different file and a different consequence), so this is a
-- transcription slip, not a convention. Neither automatic reader on the push
-- path can see it: a repeated key is valid Lua, so luacheck is silent, and the
-- file loads, so the smoke loader is too. Same blind spot as 'wardcomma'
-- directly above -- different failure mode, hence a separate id: a comma moves
-- one point, a duplicate key deletes one.
--
-- DOMAIN, measured, and the half this corpus cannot buy (declared, not buried).
-- All three groups are DIRE tables, so in a mirrored A/B this id has a domain
-- only on the leg whose armed side is dire -- a reader must not treat the
-- radiant leg's zero as evidence about the lever ('wardcomma' is the mirror
-- image of this and is radiant-only). Over the whole fixture corpus (125
-- fixtures, 625 dire hero-frames, 126 at J.GetPosition >= 4, i.e. the
-- population mode_ward_generic's own first line admits), on each frame's OWN
-- tower state with nothing declared -- see tests/_warddupkey_sweep.lua:
--
--   82/126   still have their own mid tier-1 standing, the state the MID_1
--            group is read in: the branch is live, not constructive-zero;
--   80/126   armed candidate list is exactly one longer and contains a
--            restored spot -- it passes IsLocationPassable and every filter;
--    0/126   the ARGMIN changes. On this corpus the lever changes no plant.
--
-- ⛔ That zero is stated first and not explained away. What it is NOT is "a
-- distant also-ran": the restored spot is inside the top 3 by distance on
-- 13/80, and on the nearest frame (Lich, position 5, t=587.4,
-- f_260820_043524_wd_defend_alone) it is 951u from the bot against the shipped
-- argmin's 548u -- it loses by 403u. A bot standing 400u further on that same
-- frame flips it. This is the CORPUS-COVERAGE kind of zero (GH #838), not the
-- constructive kind: the host runs and the spot is admitted, the corpus just
-- never samples a stance where it wins.
--
-- ⭐⭐ AND THE CHANNEL A SINGLE-FRAME CORPUS CANNOT SEE AT ALL, which is the
-- real cost of being one spot short: a spot is filtered out for 360s after it
-- is planted on (`spot.plant_time_obs`). Over a game the group drains, and a
-- group of 4 drains sooner than a group of 5 -- when the last unexpired spot is
-- the one the duplicate key deleted, the shipped bot has NO spot for that tower
-- and wards nowhere. No frame can show this, so the test drives it instead, on
-- a real frame with the plant times DECLARED.
--
-- SHAPE. Restored ONCE, on the spot tables themselves, at the head of the only
-- two producers that read them -- so the observer path, the sentry path,
-- X.GetClosestObserverWardSpot's argmin, mode_ward_generic's 3200u desire test
-- and the Action_UseAbilityOnLocation that finally plants all see the same
-- group, and the restored spot carries its own `plant_time_obs` bookkeeping on
-- the same table as its neighbours. Un-armed the function falls out on its
-- first conjunct and every table is the shipped one, identity and all. Single
-- id, conjoined with nothing (no 'pullcad' trap). Appended at max-integer-key
-- + 1, which is safe here because BOTH readers iterate with `pairs`, never `#`
-- (checked: the four call sites at the two producers), so neither a hole nor an
-- appended key can change what they see.
--
-- DECLARED CONSEQUENCE, not a hidden one: the restored spot faces the same
-- IsLocationPassable / IsOtherWardClose / IsThereEnemySentry tests as every
-- other spot, so on a frame where it is impassable the armed list is the same
-- length as the shipped one rather than one longer. That is the only way armed
-- can fail to grow the list, and it is asserted in the test rather than
-- promised here.
local tWardDupRestore = {
	{ tbl = WardLocationsBeforeAllyTowerFall__Dire,  tower = TOWER_MID_1,
	  spot = { location = WARD_DUP_DIRE_MID1_EATEN, plant_time_obs = 0, plant_time_sentry = 0, } },
	{ tbl = WardLocationsBeforeAllyTowerFall__Dire,  tower = TOWER_TOP_3,
	  spot = { location = WARD_DUP_DIRE_TOP3_EATEN, plant_time_obs = 0, plant_time_sentry = 0, } },
	{ tbl = WardLocationsAfterEnemyTowerFall__Dire,  tower = TOWER_TOP_2,
	  spot = { location = WARD_DUP_DIRE_TOP2_EATEN, plant_time_obs = 0, plant_time_sentry = 0, } },
}

function X.ApplyWardDupKeyFix()
	if not (J.IsModeTurbo() and J.IsSoakCandidate('warddupkey')) then return end

	for _, r in ipairs(tWardDupRestore) do
		local tGroup = r.tbl[r.tower]
		if tGroup ~= nil then
			-- Idempotent against the WORLD, not against a flag: a flag can
			-- disagree with the table after a reload, the table cannot disagree
			-- with itself. Identity, not coordinates -- a group is allowed to
			-- hold another spot at the same place.
			local nMax, bPresent = 0, false
			for k, s in pairs(tGroup) do
				if s == r.spot then bPresent = true end
				if type(k) == 'number' and k > nMax then nMax = k end
			end
			if not bPresent then
				tGroup[nMax + 1] = r.spot
			end
		end
	end
end

function X.GetAvailabeObserverWardSpots(bot)
	X.ApplyWardCommaFix()
	X.ApplyWardDupKeyFix()
	local availableSpots = {}

	if DotaTime() < 0 then
		for _, spot in pairs(X.GetGameStartWardSpots()) do
			if not X.IsOtherWardClose(spot.location, 'npc_dota_observer_wards', nVisionRadius * 2, true, false) and not X.IsThereEnemySentry(spot.location, 1100) then
				table.insert(availableSpots, spot)
			end
		end

		return availableSpots
	end

	if J.IsEarlyGame() then
		for _, spot in pairs(X.GetEarlyGameWardSpots()) do
			if not X.IsOtherWardClose(spot.location, 'npc_dota_observer_wards', nVisionRadius * 2, true, false)
			and not X.IsThereEnemySentry(spot.location, 1100)
			and (spot.plant_time_obs == 0 or (DotaTime() > spot.plant_time_obs + 360))
			then
				table.insert(availableSpots, spot)
			end
		end
	end

	for i = 1, #nTowerList do
		local t = GetTower(GetTeam(),  nTowerList[i])
		if t ~= nil
		or GetTower(GetTeam(), TOWER_TOP_3) == nil
		or GetTower(GetTeam(), TOWER_MID_3) == nil
		or GetTower(GetTeam(), TOWER_BOT_3) == nil
        then
			if (t == GetTower(GetTeam(), TOWER_TOP_2) and GetTower(GetTeam(), TOWER_TOP_1) ~= nil)
			or (t == GetTower(GetTeam(), TOWER_TOP_3) and GetTower(GetTeam(), TOWER_TOP_2) ~= nil)
			or (t == GetTower(GetTeam(), TOWER_MID_2) and GetTower(GetTeam(), TOWER_MID_1) ~= nil)
			or (t == GetTower(GetTeam(), TOWER_MID_3) and GetTower(GetTeam(), TOWER_MID_2) ~= nil)
			or (t == GetTower(GetTeam(), TOWER_BOT_2) and GetTower(GetTeam(), TOWER_BOT_1) ~= nil)
			or (t == GetTower(GetTeam(), TOWER_BOT_3) and GetTower(GetTeam(), TOWER_BOT_2) ~= nil)
			then
				--
			else
				if GetTeam() == TEAM_RADIANT then
					for tower, spots in pairs(WardLocationsBeforeAllyTowerFall__Radiant) do
						if tower == nTowerList[i] then
							for _, spot in pairs(spots) do
								if IsLocationPassable(spot.location)
								and not X.IsOtherWardClose(spot.location, 'npc_dota_observer_wards', nVisionRadius * 2, true, false)
								and not X.IsThereEnemySentry(spot.location, 1100)
								and (spot.plant_time_obs == 0 or (DotaTime() > spot.plant_time_obs + 360))
								then
									table.insert(availableSpots, spot)
								end
							end
						end
					end
				else
					for tower, spots in pairs(WardLocationsBeforeAllyTowerFall__Dire) do
						if tower == nTowerList[i] then
							for _, spot in pairs(spots) do
								if IsLocationPassable(spot.location)
								and not X.IsOtherWardClose(spot.location, 'npc_dota_observer_wards', nVisionRadius * 2, true, false)
								and not X.IsThereEnemySentry(spot.location, 1100)
								and (spot.plant_time_obs == 0 or (DotaTime() > spot.plant_time_obs + 360))
								then
									table.insert(availableSpots, spot)
								end
							end
						end
					end
				end
			end
		end
	end

	for i = 1, #nTowerList do
		local t = GetTower(GetOpposingTeam(),  nTowerList[i])
		if t == nil then
			if (t == GetTower(GetOpposingTeam(), TOWER_TOP_2) and GetTower(GetOpposingTeam(), TOWER_TOP_1) ~= nil)
			or (t == GetTower(GetOpposingTeam(), TOWER_TOP_3) and GetTower(GetOpposingTeam(), TOWER_TOP_2) ~= nil)
			or (t == GetTower(GetOpposingTeam(), TOWER_MID_2) and GetTower(GetOpposingTeam(), TOWER_MID_1) ~= nil)
			or (t == GetTower(GetOpposingTeam(), TOWER_MID_3) and GetTower(GetOpposingTeam(), TOWER_MID_2) ~= nil)
			or (t == GetTower(GetOpposingTeam(), TOWER_BOT_2) and GetTower(GetOpposingTeam(), TOWER_BOT_1) ~= nil)
			or (t == GetTower(GetOpposingTeam(), TOWER_BOT_3) and GetTower(GetOpposingTeam(), TOWER_BOT_2) ~= nil)
			then
				--
			else
				if GetTeam() == TEAM_RADIANT then
					for tower, spots in pairs(WardLocationsAfterEnemyTowerFall__Radiant) do
						if tower == nTowerList[i] then
							for _, spot in pairs(spots) do
								if IsLocationPassable(spot.location)
								and not X.IsOtherWardClose(spot.location, 'npc_dota_observer_wards', nVisionRadius * 2, true, false)
								and not X.IsThereEnemySentry(spot.location, 1100)
								and (spot.plant_time_obs == 0 or (DotaTime() > spot.plant_time_obs + 360))
								then
									table.insert(availableSpots, spot)
								end
							end
						end
					end
				else
					for tower, spots in pairs(WardLocationsAfterEnemyTowerFall__Dire) do
						if tower == nTowerList[i] then
							for _, spot in pairs(spots) do
								if IsLocationPassable(spot.location)
								and not X.IsOtherWardClose(spot.location, 'npc_dota_observer_wards', nVisionRadius * 2, true, false)
								and not X.IsThereEnemySentry(spot.location, 1100)
								and (spot.plant_time_obs == 0 or (DotaTime() > spot.plant_time_obs + 360))
								then
									table.insert(availableSpots, spot)
								end
							end
						end
					end
				end
			end
		end
	end

	return availableSpots
end

function X.GetClosestObserverWardSpot(bot, spots)
	local cDist = 100000
	local cTarget = nil

	for _, spot in pairs(spots) do
		local dist = GetUnitToLocationDistance(bot, spot.location)
		if dist < cDist then
			cDist = dist
			cTarget = spot
		end
	end

	return cTarget
end

function X.GetPossibleSentryWardSpots(bot)
	X.ApplyWardCommaFix()
	X.ApplyWardDupKeyFix()
	local possibleSpots = {}

	if J.IsEarlyGame() then
		for _, spot in pairs(X.GetEarlyGameWardSpots()) do
			if not X.IsOtherWardClose(spot.location, 'npc_dota_sentry_wards', 1200, true, false)
			and not J.Site.IsLocationHaveTrueSight(spot.location)
			then
				if (spot.plant_time_obs > 0 and DotaTime() - spot.plant_time_obs < 360) -- got "dewarded"
				or (X.IsOtherWardClose(spot.location, 'npc_dota_observer_wards', 400, true, true))
				then
					table.insert(possibleSpots, spot)
				end
			end
		end
	end

	if DotaTime() > 0 then
		for i = 1, #nTowerList do
			local t = GetTower(GetTeam(),  nTowerList[i])
			if t ~= nil
			or GetTower(GetTeam(), TOWER_TOP_3) == nil
			or GetTower(GetTeam(), TOWER_MID_3) == nil
			or GetTower(GetTeam(), TOWER_BOT_3) == nil
			then
				if (t == GetTower(GetTeam(), TOWER_TOP_2) and GetTower(GetTeam(), TOWER_TOP_1) ~= nil)
				or (t == GetTower(GetTeam(), TOWER_TOP_3) and GetTower(GetTeam(), TOWER_TOP_2) ~= nil)
				or (t == GetTower(GetTeam(), TOWER_MID_2) and GetTower(GetTeam(), TOWER_MID_1) ~= nil)
				or (t == GetTower(GetTeam(), TOWER_MID_3) and GetTower(GetTeam(), TOWER_MID_2) ~= nil)
				or (t == GetTower(GetTeam(), TOWER_BOT_2) and GetTower(GetTeam(), TOWER_BOT_1) ~= nil)
				or (t == GetTower(GetTeam(), TOWER_BOT_3) and GetTower(GetTeam(), TOWER_BOT_2) ~= nil)
				then
					--
				else
					if GetTeam() == TEAM_RADIANT then
						for tower, spots in pairs(WardLocationsBeforeAllyTowerFall__Radiant) do
							if tower == nTowerList[i] then
								for _, spot in pairs(spots) do
									if IsLocationPassable(spot.location)
									and not X.IsOtherWardClose(spot.location, 'npc_dota_sentry_wards', 1200, true, false)
									and not J.Site.IsLocationHaveTrueSight(spot.location)
									then
										if (spot.plant_time_obs > 0 and DotaTime() - spot.plant_time_obs < 360) -- got "dewarded"
										or (X.IsOtherWardClose(spot.location, 'npc_dota_observer_wards', 400, true, true))
										then
											table.insert(possibleSpots, spot)
										end
									end
								end
							end
						end
					else
						for tower, spots in pairs(WardLocationsBeforeAllyTowerFall__Dire) do
							if tower == nTowerList[i] then
								for _, spot in pairs(spots) do
									if IsLocationPassable(spot.location)
									and not X.IsOtherWardClose(spot.location, 'npc_dota_sentry_wards', 1200, true, false)
									and not J.Site.IsLocationHaveTrueSight(spot.location)
									then
										if (spot.plant_time_obs > 0 and DotaTime() - spot.plant_time_obs < 360) -- got "dewarded"
										or (X.IsOtherWardClose(spot.location, 'npc_dota_observer_wards', 400, true, true))
										then
											table.insert(possibleSpots, spot)
										end
									end
								end
							end
						end
					end
				end
			end
		end

		for i = 1, #nTowerList do
			local t = GetTower(GetOpposingTeam(),  nTowerList[i])
			if t == nil then
				if (t == GetTower(GetOpposingTeam(), TOWER_TOP_2) and GetTower(GetOpposingTeam(), TOWER_TOP_1) ~= nil)
				or (t == GetTower(GetOpposingTeam(), TOWER_TOP_3) and GetTower(GetOpposingTeam(), TOWER_TOP_2) ~= nil)
				or (t == GetTower(GetOpposingTeam(), TOWER_MID_2) and GetTower(GetOpposingTeam(), TOWER_MID_1) ~= nil)
				or (t == GetTower(GetOpposingTeam(), TOWER_MID_3) and GetTower(GetOpposingTeam(), TOWER_MID_2) ~= nil)
				or (t == GetTower(GetOpposingTeam(), TOWER_BOT_2) and GetTower(GetOpposingTeam(), TOWER_BOT_1) ~= nil)
				or (t == GetTower(GetOpposingTeam(), TOWER_BOT_3) and GetTower(GetOpposingTeam(), TOWER_BOT_2) ~= nil)
				then
					--
				else
					if GetTeam() == TEAM_RADIANT then
						for tower, spots in pairs(WardLocationsAfterEnemyTowerFall__Radiant) do
							if tower == nTowerList[i] then
								for _, spot in pairs(spots) do
									if IsLocationPassable(spot.location)
									and not X.IsOtherWardClose(spot.location, 'npc_dota_sentry_wards', 1200, true, false)
									and not J.Site.IsLocationHaveTrueSight(spot.location)
									then
										if (spot.plant_time_obs > 0 and DotaTime() - spot.plant_time_obs < 360) -- got "dewarded"
										or (X.IsOtherWardClose(spot.location, 'npc_dota_observer_wards', 400, true, true))
										then
											table.insert(possibleSpots, spot)
										end
									end
								end
							end
						end
					else
						for tower, spots in pairs(WardLocationsAfterEnemyTowerFall__Dire) do
							if tower == nTowerList[i] then
								for _, spot in pairs(spots) do
									if IsLocationPassable(spot.location)
									and not X.IsOtherWardClose(spot.location, 'npc_dota_sentry_wards', 1200, true, false)
									and not J.Site.IsLocationHaveTrueSight(spot.location)
									then
										if (spot.plant_time_obs > 0 and DotaTime() - spot.plant_time_obs < 360) -- got "dewarded"
										or (X.IsOtherWardClose(spot.location, 'npc_dota_observer_wards', 400, true, true))
										then
											table.insert(possibleSpots, spot)
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end

	return possibleSpots
end

function X.GetClosestSentryWardSpot(bot, spots)
	local cDist = 100000
	local cTarget = nil

	for _, spot in pairs(spots) do
		local dist = GetUnitToLocationDistance(bot, spot.location)
		if dist < cDist then
			cDist = dist
			cTarget = spot
		end
	end

	return cTarget
end

function X.IsOtherWardClose(vLocation, sWardName, nRadius, bTeam, bCheckLifespan)
	local unitList = GetUnitList(UNIT_LIST_ALLIED_WARDS)
	if not bTeam then unitList = GetUnitList(UNIT_LIST_ENEMY_WARDS) end

	for _, ward in pairs(unitList) do
		if J.IsValid(ward)
		and string.find(ward:GetUnitName(), sWardName)
        and GetUnitToLocationDistance(ward, vLocation) <= nRadius
        then
			if bCheckLifespan then
				if sWardName == 'item_ward_observer' and J.GetModifierTime(ward, 'modifier_item_buff_ward') >= 360/2 then
					return true
				end
			else
				return true
			end
		end
	end

	return false
end

function X.IsThereEnemySentry(vLocation, nRadius)
	local nWardList = GetUnitList(UNIT_LIST_ENEMY_WARDS)
	for _, ward in pairs(nWardList) do
		if J.IsValid(ward)
		and ward:GetUnitName() == "npc_dota_sentry_wards"
        and GetUnitToLocationDistance(ward, vLocation) <= nRadius
        then
			return true
		end
	end

	return false
end

return X