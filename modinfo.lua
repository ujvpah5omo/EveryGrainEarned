local chinese = locale == "zh" or locale == "zht" or locale == "zhr"
local function text(zh, en)
    return chinese and zh or en
end

local workshop_url = "https://steamcommunity.com/sharedfiles/filedetails/?id=3831389006"
name = text("粒粒皆辛苦", "Every Grain Earned")
description = text(
    "耕种需要应对旱涝、寒冷、盐害与疾病。用洒水器供水、沙袋排水、农药治病。长期积水、干旱或盐害会毁田。",
    "Manage flooding, drought, cold, salinity and crop disease. Irrigate with sprinklers, drain with sandbags and treat crops with pesticide. Prolonged flooding, drought or salt exposure can ruin farm plots."
) .. "\n\n" .. text("Steam 创意工坊", "Steam Workshop") .. "\n" .. workshop_url
author = "Codex"
version = "0.6.1"
api_version = 10
dst_compatible = true
dont_starve_compatible = false
reign_of_giants_compatible = false
shipwrecked_compatible = false
all_clients_require_mod = true
client_only_mod = false
server_only_mod = false
server_filter_tags = { "farming", "survival" }

local toggles = {
    {description=text("开启", "On"), data=true},
    {description=text("关闭", "Off"), data=false},
}
local rates = {
    {description=text("较缓", "Gentle"), data=0.5},
    {description=text("标准", "Normal"), data=1},
    {description=text("严酷", "Harsh"), data=2},
}
configuration_options = {
    {name="flooding", label=text("积水与水土流失", "Flooding and soil erosion"), options=toggles, default=true},
    {name="drought", label=text("夏季干旱毁田", "Summer drought"), options=toggles, default=true},
    {name="disease", label=text("疾病与传染", "Crop disease and spread"), options=toggles, default=true},
    {name="temperature", label=text("作物寒害", "Crop cold damage"), options=toggles, default=true},
    {name="season_gate", label=text("应季才能结果", "Seasonal harvest"), options=toggles, default=true},
    {name="salinity", label=text("盐分压力与盐害毁田", "Soil salinity and salt damage"), options=toggles, default=true},
    {name="severity", label=text("环境恶化速度", "Damage severity"), options=rates, default=1},
    {name="sandbag_range", label=text("沙袋排水范围", "Sandbag drain area"), options={
        {description=text("与洒水器一致", "Match sprinkler"), data=6.5},
        {description=text("半径 2", "Radius 2"), data=2},
        {description=text("半径 4", "Radius 4"), data=4},
        {description=text("半径 6", "Radius 6"), data=6},
    }, default=4},
}
