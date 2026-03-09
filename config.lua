Config = {};
Config.TuDong_ThayDoiGia = true;
Config.ThoiGian_CapNhat = 30;
Config.Items = {
	normal = {
		steel = {
			Min = 100,
			Max = 120,
			AmountToChange = 2000
		},
	},
};

Config.Locations = {
	{
		Blip = {
			Enable = false,
			Sprite = 304,
			Color = 5,
			Scale = 0.6,
			Label = "Thu mua"
		},
		Coords = {
			vec4(375.96, -346.96, 46.67, 254.65)
		},
		NPCHash = 1822107721,
		NPCModel = "a_m_m_hillbilly_01",
		NPCHeading = 1.17,
		Items = Config.Items.normal
	},
};
