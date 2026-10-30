name = "粒粒皆辛苦 / Every Grain Earned"
description = "耕种需要应对旱涝、寒冷、盐害与疾病。自动洒水器与海水淡化洒水器补水，沙袋排水，农药治疗。长期积水或盐害会毁田。\nFarming with floods, drought, salinity and crop disease. Includes ordinary and magical sprinklers, sandbags and pesticide."
author = "Every Grain Earned"
version = "0.5.0"
api_version = 10
dst_compatible = true
dont_starve_compatible = false
reign_of_giants_compatible = false
shipwrecked_compatible = false
all_clients_require_mod = true
client_only_mod = false
server_only_mod = false
server_filter_tags = { "farming", "survival" }
local toggles = {{description="开启 / On",data=true},{description="关闭 / Off",data=false}}
local rates = {{description="较缓 / Gentle",data=0.5},{description="标准 / Normal",data=1},{description="严酷 / Harsh",data=2}}
configuration_options = {
    {name="flooding",label="积水与水土流失 / Floods",options=toggles,default=true},
    {name="drought",label="夏季干旱毁田 / Drought",options=toggles,default=true},
    {name="disease",label="疾病与传染 / Disease",options=toggles,default=true},
    {name="temperature",label="作物寒害 / Cold damage",options=toggles,default=true},
    {name="season_gate",label="应季才能巨大化 / Seasonal giants",options=toggles,default=true},
    {name="salinity",label="盐分压力与盐害毁田 / Soil salinity",options=toggles,default=true},
    {name="severity",label="环境恶化速度 / Severity",options=rates,default=1},
    {name="sandbag_range",label="沙袋排水范围 / Drain area",options={{description="与洒水器一致 / Match sprinkler",data=6.5},{description="半径2 / Radius 2",data=2},{description="半径4 / Radius 4",data=4},{description="半径6 / Radius 6",data=6}},default=4},
}
