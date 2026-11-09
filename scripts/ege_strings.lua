local strings = {
    deploy_bag = {"放置沙袋", "Place Sandbag"},
    stress_flood = {"农田积水了，需要排水。", "The soil is flooded. It needs drainage."},
    stress_cold = {"气温过低，不适合这种作物。", "It is too cold for this crop."},
    stress_salt = {"海水灌溉过多或农田积盐严重，需要淡水洗盐。", "The soil is too salty. Flush it with fresh water and drain it."},
    sprinkler = {"自动洒水器", "Sprinkler"},
    magic_sprinkler = {"海水淡化洒水器", "Desalinating Sprinkler"},
    sandbag = {"排水沙袋", "Drainage Sandbag"},
    pesticide = {"农药", "Pesticide"},
    flood = {"农田积水", "Floodwater"},
    sprinkler_desc = {"水源附近建造，海水灌溉会积盐。", "Build near a water source. Seawater leaves salt in the soil."},
    magic_desc = {"装入蓝宝石或启迪碎片，淡化海水。", "Insert a Blue Gem or Enlightened Shard to desalinate seawater."},
    sandbag_desc = {"吸排附近农田的积水。", "Drains standing water from nearby farm plots."},
    pesticide_desc = {"装备后投掷，释放蓝色治疗雾。病株需先排水。", "Equip and throw to release a blue healing mist. Drain flooded crops before treating them."},
    flood_desc = {"水太多了，该排水了。", "Too much water. Time to drain it."},
    bag_item_desc = {"放在农田空位上，排除附近积水。", "Place on a clear spot to drain nearby farm plots."},
    cloth = {"布", "Cloth"},
    cloth_recipe = {"把蜘蛛丝织成结实的布。", "Weave spider silk into sturdy cloth."},
    cloth_desc = {"可以用来缝制沙袋。", "Use it to sew sandbags."},
    ruined_field = {"毁坏的田地", "Ruined Farm Plot"},
    seawater_share = {"本轮海水供水占比：%.1f%%", "Seawater this crop cycle: %.1f%%"},
    soil_salt = {"土壤盐分：%.0f/300（%s）", "Soil salinity: %.0f/300 (%s)"},
    salt_normal = {"正常", "Normal"},
    salt_light = {"轻度", "Mild"},
    salt_medium = {"中度", "Moderate"},
    salt_severe = {"重度", "Severe"},
    salt_progress = {"，重度累积 %.1f/3 天", ", severe exposure: %.1f/3 days"},
    rot_cold = {"低温超过了这种作物的承受范围。", "This crop could not survive the cold."},
    rot_disease = {"病害或长期浸泡让作物腐烂了。", "Disease or prolonged flooding rotted this crop."},
    rot_field = {"农田已经毁坏。", "The farm plot was ruined."},
    rot_ice = {"农田积水结冰，作物已冻坏腐烂。", "The floodwater froze and killed this crop."},
    rot_default = {"这株作物已经腐烂，无法治疗。", "This crop has rotted and cannot be treated."},
    sick_flooded = {"病株：请先用沙袋排水，再使用农药。", "Diseased crop. Drain the plot with sandbags before applying pesticide."},
    sick = {"病株：可以使用农药治疗。", "Diseased crop. Treat it with pesticide."},
    crop_flooded = {"农田积水，正在流失肥力。", "The flooded soil is losing nutrients."},
    crop_cold = {"气温过低，持续下去会冻死。", "It is too cold. This crop will die if the cold continues."},
    crop_season = {"如果结果时仍不应季，这株作物会直接枯萎。", "This crop will wither if it reaches maturity out of season."},
    rot_season = {"作物在结果时不应季，已经枯萎。", "This crop withered because it reached maturity out of season."},
    crop_salty = {"农田积盐过多，正在承受盐分压力。", "Excess soil salt is stressing this crop."},
    no_water = {"附近20范围内没有可用水源。绿洲只在夏季供水。", "No usable water source within 20 units. Oases supply water only in summer."},
    fuel_plain = {"燃料：%.2f%%。抽取海水会使农田积盐。", "Fuel: %.2f%%. Seawater irrigation leaves salt in the soil."},
    shard = {"启迪碎片：持续淡化，不消耗。", "Enlightened Shard: desalination without consumption."},
    gem_time = {"蓝宝石淡化余时：%.0f秒（%s）。", "Blue Gem desalination: %.0f seconds left (%s)."},
    gem_off = {"已停机，暂停计时", "switched off, timer paused"},
    gem_fresh = {"淡水供水，暂停计时", "freshwater supply, timer paused"},
    gem_sea = {"海水淡化中，每2秒扣除", "desalinating, charged every 2 seconds"},
    fuel_magic = {"燃料：%.2f%%。右键开关机器，打开容器可更换淡化材料。\n%s", "Fuel: %.2f%%. Right-click to toggle. Open the container to change the desalination material.\n%s"},
    recovery = {"土地已毁坏，需休耕约%.1f天才能重新开垦。", "This plot is ruined. Wait about %.1f days before tilling it again."},
    bag_detail = {"已吸水：%.1f/%d；累计吸盐：%.2f。\n袋内平均盐水比：%.4f（每100水含%.2f盐）。", "Water absorbed: %.1f/%d. Salt removed: %.2f.\nAverage salt-to-water ratio: %.4f (%.2f salt per 100 water)."},
    bag_broken = {"沙袋已损坏，无法吸水。\n", "This sandbag is damaged and cannot absorb water.\n"},
    bag_full = {"沙袋已经吸满；继续浸泡会损坏，可敲掉更换。\n", "This sandbag is full. Continued soaking will damage it. Hammer it to replace it.\n"},
}

local legacy_reasons = {}
for key, pair in pairs(strings) do
    if key:sub(1,4) == "rot_" then legacy_reasons[pair[1]] = key end
end

return function(key)
    local pair = strings[legacy_reasons[key] or key]
    if not pair then return key end
    local locale = LOC and LOC.GetLocaleCode and LOC.GetLocaleCode() or "en"
    return pair[locale and locale:lower():sub(1,2) == "zh" and 1 or 2]
end
