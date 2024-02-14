pub const radar_site_locations: []const struct {
    name: []const u8,
    lat: f32,
    lon: f32,
} = &.{
    .{ .name = "TJUA", .lat = 18.115667, .lon = -66.078167 },
    .{ .name = "KCBW", .lat = 46.03925, .lon = -67.806431 },
    .{ .name = "KGYX", .lat = 43.891306, .lon = -70.256361 },
    .{ .name = "KCXX", .lat = 44.511, .lon = -73.166431 },
    .{ .name = "KBOX", .lat = 41.955778, .lon = -71.136861 },
    .{ .name = "KENX", .lat = 42.586556, .lon = -74.064083 },
    .{ .name = "KBGM", .lat = 42.199694, .lon = -75.984722 },
    .{ .name = "KBUF", .lat = 42.948789, .lon = -78.736781 },
    .{ .name = "KTYX", .lat = 43.755694, .lon = -75.679861 },
    .{ .name = "KOKX", .lat = 40.865528, .lon = -72.863917 },
    .{ .name = "KDOX", .lat = 38.825767, .lon = -75.440117 },
    .{ .name = "KDIX", .lat = 39.947089, .lon = -74.410731 },
    .{ .name = "KPBZ", .lat = 40.531717, .lon = -80.217967 },
    .{ .name = "KCCX", .lat = 40.923167, .lon = -78.003722 },
    .{ .name = "KRLX", .lat = 38.311111, .lon = -81.722778 },
    .{ .name = "KAKQ", .lat = 36.98405, .lon = -77.007361 },
    .{ .name = "KFCX", .lat = 37.0244, .lon = -80.273969 },
    .{ .name = "KLWX", .lat = 38.976111, .lon = -77.4875 },
    .{ .name = "KMHX", .lat = 34.775908, .lon = -76.876189 },
    .{ .name = "KRAX", .lat = 35.665519, .lon = -78.48975 },
    .{ .name = "KLTX", .lat = 33.98915, .lon = -78.429108 },
    .{ .name = "KCLX", .lat = 32.655528, .lon = -81.042194 },
    .{ .name = "KCAE", .lat = 33.948722, .lon = -81.118278 },
    .{ .name = "KGSP", .lat = 34.883306, .lon = -82.219833 },
    .{ .name = "KFFC", .lat = 33.36355, .lon = -84.56595 },
    .{ .name = "KVAX", .lat = 30.890278, .lon = -83.001806 },
    .{ .name = "KJGX", .lat = 32.675683, .lon = -83.350833 },
    .{ .name = "KEVX", .lat = 30.565033, .lon = -85.921667 },
    .{ .name = "KJAX", .lat = 30.484633, .lon = -81.7019 },
    .{ .name = "KBYX", .lat = 24.5975, .lon = -81.703167 },
    .{ .name = "KMLB", .lat = 28.113194, .lon = -80.654083 },
    .{ .name = "KAMX", .lat = 25.611083, .lon = -80.412667 },
    .{ .name = "KTLH", .lat = 30.397583, .lon = -84.328944 },
    .{ .name = "KTBW", .lat = 27.7055, .lon = -82.401778 },
    .{ .name = "KBMX", .lat = 33.172417, .lon = -86.770167 },
    .{ .name = "KEOX", .lat = 31.460556, .lon = -85.459389 },
    .{ .name = "KHTX", .lat = 34.930556, .lon = -86.083611 },
    .{ .name = "KMXX", .lat = 32.53665, .lon = -85.78975 },
    .{ .name = "KMOB", .lat = 30.679444, .lon = -88.24 },
    .{ .name = "KDGX", .lat = 32.279944, .lon = -89.984444 },
    .{ .name = "KGWX", .lat = 33.896917, .lon = -88.329194 },
    .{ .name = "KMRX", .lat = 36.168611, .lon = -83.401944 },
    .{ .name = "KNQA", .lat = 35.344722, .lon = -89.873333 },
    .{ .name = "KOHX", .lat = 36.247222, .lon = -86.5625 },
    .{ .name = "KHPX", .lat = 36.736972, .lon = -87.285583 },
    .{ .name = "KLVX", .lat = 37.975278, .lon = -85.943889 },
    .{ .name = "KPAH", .lat = 37.068333, .lon = -88.771944 },
    .{ .name = "KILN", .lat = 39.420483, .lon = -83.82145 },
    .{ .name = "KCLE", .lat = 41.413217, .lon = -81.859867 },
    .{ .name = "KDTX", .lat = 42.7, .lon = -83.471667 },
    .{ .name = "KAPX", .lat = 44.90635, .lon = -84.719533 },
    .{ .name = "KGRR", .lat = 42.893889, .lon = -85.544889 },
    .{ .name = "KMQT", .lat = 46.531111, .lon = -87.548333 },
    .{ .name = "KVWX", .lat = 38.26025, .lon = -87.724528 },
    .{ .name = "KIND", .lat = 39.7075, .lon = -86.280278 },
    .{ .name = "KIWX", .lat = 41.358611, .lon = -85.7 },
    .{ .name = "KLOT", .lat = 41.604444, .lon = -88.084444 },
    .{ .name = "KILX", .lat = 40.1505, .lon = -89.336792 },
    .{ .name = "KGRB", .lat = 44.498633, .lon = -88.111111 },
    .{ .name = "KARX", .lat = 43.822778, .lon = -91.191111 },
    .{ .name = "KMKX", .lat = 42.9679, .lon = -88.550667 },
    .{ .name = "KDLH", .lat = 46.836944, .lon = -92.209722 },
    .{ .name = "KMPX", .lat = 44.848889, .lon = -93.565528 },
    .{ .name = "KDVN", .lat = 41.611667, .lon = -90.580833 },
    .{ .name = "KDMX", .lat = 41.7312, .lon = -93.722869 },
    .{ .name = "KEAX", .lat = 38.81025, .lon = -94.264472 },
    .{ .name = "KLSX", .lat = 38.698611, .lon = -90.682778 },
    .{ .name = "KSRX", .lat = 35.290417, .lon = -94.361889 },
    .{ .name = "KLZK", .lat = 34.8365, .lon = -92.262194 },
    .{ .name = "KPOE", .lat = 31.155278, .lon = -92.976111 },
    .{ .name = "KLCH", .lat = 30.125306, .lon = -93.215889 },
    .{ .name = "KLIX", .lat = 30.336667, .lon = -89.825417 },
    .{ .name = "KSHV", .lat = 32.450833, .lon = -93.84125 },
    .{ .name = "KAMA", .lat = 35.233333, .lon = -101.709278 },
    .{ .name = "KEWX", .lat = 29.704056, .lon = -98.028611 },
    .{ .name = "KBRO", .lat = 25.916, .lon = -97.418967 },
    .{ .name = "KCRP", .lat = 27.784017, .lon = -97.51125 },
    .{ .name = "KFWS", .lat = 32.573, .lon = -97.30315 },
    .{ .name = "KDYX", .lat = 32.5385, .lon = -99.254333 },
    .{ .name = "KEPZ", .lat = 31.873056, .lon = -106.698 },
    .{ .name = "KGRK", .lat = 30.721833, .lon = -97.382944 },
    .{ .name = "KHGX", .lat = 29.4719, .lon = -95.078733 },
    .{ .name = "KDFX", .lat = 29.273139, .lon = -100.280333 },
    .{ .name = "KLBB", .lat = 33.654139, .lon = -101.814167 },
    .{ .name = "KMAF", .lat = 31.943461, .lon = -102.18925 },
    .{ .name = "KSJT", .lat = 31.371278, .lon = -100.4925 },
    .{ .name = "KFDR", .lat = 34.362194, .lon = -98.976667 },
    .{ .name = "KTLX", .lat = 35.333361, .lon = -97.277761 },
    .{ .name = "KINX", .lat = 36.175131, .lon = -95.564161 },
    .{ .name = "KVNX", .lat = 36.740617, .lon = -98.127717 },
    .{ .name = "KDDC", .lat = 37.760833, .lon = -99.968889 },
    .{ .name = "KGLD", .lat = 39.366944, .lon = -101.700278 },
    .{ .name = "KTWX", .lat = 38.99695, .lon = -96.23255 },
    .{ .name = "KICT", .lat = 37.654444, .lon = -97.443056 },
    .{ .name = "KUEX", .lat = 40.320833, .lon = -98.441944 },
    .{ .name = "KLNX", .lat = 41.957944, .lon = -100.576222 },
    .{ .name = "KOAX", .lat = 41.320369, .lon = -96.366819 },
    .{ .name = "KABR", .lat = 45.455833, .lon = -98.413333 },
    .{ .name = "KUDX", .lat = 44.124722, .lon = -102.83 },
    .{ .name = "KFSD", .lat = 43.587778, .lon = -96.729444 },
    .{ .name = "KBIS", .lat = 46.770833, .lon = -100.760556 },
    .{ .name = "KMVX", .lat = 47.527778, .lon = -97.325556 },
    .{ .name = "KMBX", .lat = 48.393056, .lon = -100.864444 },
    .{ .name = "KBLX", .lat = 45.853778, .lon = -108.606806 },
    .{ .name = "KGGW", .lat = 48.206361, .lon = -106.624694 },
    .{ .name = "KTFX", .lat = 47.459583, .lon = -111.385333 },
    .{ .name = "KMSX", .lat = 47.041, .lon = -113.986222 },
    .{ .name = "KCYS", .lat = 41.151919, .lon = -104.806031 },
    .{ .name = "KRIW", .lat = 43.066089, .lon = -108.4773 },
    .{ .name = "KFTG", .lat = 39.786639, .lon = -104.545806 },
    .{ .name = "KGJX", .lat = 39.062169, .lon = -108.213761 },
    .{ .name = "KPUX", .lat = 38.45955, .lon = -104.18135 },
    .{ .name = "KABX", .lat = 35.149722, .lon = -106.823889 },
    .{ .name = "KFDX", .lat = 34.634167, .lon = -103.618889 },
    .{ .name = "KHDX", .lat = 33.077, .lon = -106.120033 },
    .{ .name = "KFSX", .lat = 34.574333, .lon = -111.198444 },
    .{ .name = "KIWA", .lat = 33.289233, .lon = -111.669917 },
    .{ .name = "KEMX", .lat = 31.89365, .lon = -110.63025 },
    .{ .name = "KYUX", .lat = 32.495281, .lon = -114.656711 },
    .{ .name = "KICX", .lat = 37.59105, .lon = -112.862183 },
    .{ .name = "KMTX", .lat = 41.262778, .lon = -112.447778 },
    .{ .name = "KCBX", .lat = 43.490217, .lon = -116.236033 },
    .{ .name = "KSFX", .lat = 43.1056, .lon = -112.686133 },
    .{ .name = "KLRX", .lat = 40.73955, .lon = -116.8027 },
    .{ .name = "KESX", .lat = 35.70135, .lon = -114.89165 },
    .{ .name = "KRGX", .lat = 39.754056, .lon = -119.462028 },
    .{ .name = "KBBX", .lat = 39.495639, .lon = -121.631611 },
    .{ .name = "KEYX", .lat = 35.09785, .lon = -117.56075 },
    .{ .name = "KBHX", .lat = 40.498583, .lon = -124.292167 },
    .{ .name = "KVTX", .lat = 34.412017, .lon = -119.17875 },
    .{ .name = "KDAX", .lat = 38.501111, .lon = -121.677833 },
    .{ .name = "KNKX", .lat = 32.919017, .lon = -117.0418 },
    .{ .name = "KMUX", .lat = 37.155222, .lon = -121.898444 },
    .{ .name = "KHNX", .lat = 36.314181, .lon = -119.632139 },
    .{ .name = "KSOX", .lat = 33.817733, .lon = -117.636 },
    .{ .name = "KVBX", .lat = 34.83855, .lon = -120.397917 },
    .{ .name = "PHKI", .lat = 21.893889, .lon = -159.5525 },
    .{ .name = "PHKM", .lat = 20.125278, .lon = -155.777778 },
    .{ .name = "PHMO", .lat = 21.132778, .lon = -157.180278 },
    .{ .name = "PHWA", .lat = 19.095, .lon = -155.568889 },
    .{ .name = "KMAX", .lat = 42.081169, .lon = -122.717369 },
    .{ .name = "KPDT", .lat = 45.69065, .lon = -118.852931 },
    .{ .name = "KRTX", .lat = 45.715039, .lon = -122.965 },
    .{ .name = "KLGX", .lat = 47.116944, .lon = -124.106667 },
    .{ .name = "KATX", .lat = 48.194611, .lon = -122.495694 },
    .{ .name = "KOTX", .lat = 47.680417, .lon = -117.626778 },
    .{ .name = "PABC", .lat = 60.791944, .lon = -161.876389 },
    .{ .name = "PAPD", .lat = 65.035114, .lon = -147.501431 },
    .{ .name = "PAHG", .lat = 60.725914, .lon = -151.351467 },
    .{ .name = "PAKC", .lat = 58.679444, .lon = -156.629444 },
    .{ .name = "PAIH", .lat = 59.460767, .lon = -146.303447 },
    .{ .name = "PAEC", .lat = 64.511389, .lon = -165.295 },
    .{ .name = "PACG", .lat = 56.852778, .lon = -135.529167 },
    .{ .name = "PGUA", .lat = 13.455833, .lon = 144.811111 },
    .{ .name = "LPLA", .lat = 38.73028, .lon = -27.32167 },
    .{ .name = "RKJK", .lat = 35.924167, .lon = 126.622222 },
    .{ .name = "KJKL", .lat = 37.590833, .lon = -83.313056 },
    .{ .name = "RKSG", .lat = 37.207569, .lon = 127.285561 },
    .{ .name = "KSGF", .lat = 37.235239, .lon = -93.400419 },
    .{ .name = "RODN", .lat = 26.3078, .lon = 127.903469 },
    .{ .name = "TLVE", .lat = 41.29, .lon = -82.008056 },
    .{ .name = "TADW", .lat = 38.695, .lon = -76.845 },
    .{ .name = "TATL", .lat = 33.646944, .lon = -84.261944 },
    .{ .name = "TBWI", .lat = 39.09, .lon = -76.63 },
    .{ .name = "TBOS", .lat = 42.158056, .lon = -70.933056 },
    .{ .name = "TCLT", .lat = 35.336944, .lon = -80.885 },
    .{ .name = "TMDW", .lat = 41.651111, .lon = -87.73 },
    .{ .name = "TORD", .lat = 41.796944, .lon = -87.858056 },
    .{ .name = "TCMH", .lat = 40.006111, .lon = -82.715 },
    .{ .name = "TCVG", .lat = 38.898056, .lon = -84.58 },
    .{ .name = "TDAL", .lat = 32.926111, .lon = -96.968056 },
    .{ .name = "TDFW", .lat = 33.065, .lon = -96.918056 },
    .{ .name = "TDAY", .lat = 40.021944, .lon = -84.123056 },
    .{ .name = "TDEN", .lat = 39.728056, .lon = -104.52611 },
    .{ .name = "TDTW", .lat = 42.111111, .lon = -83.515 },
    .{ .name = "TIAD", .lat = 39.083889, .lon = -77.528889 },
    .{ .name = "TFLL", .lat = 26.143056, .lon = -80.343889 },
    .{ .name = "THOU", .lat = 29.516111, .lon = -95.241944 },
    .{ .name = "TIAH", .lat = 30.065, .lon = -95.566944 },
    .{ .name = "TIDS", .lat = 39.636944, .lon = -86.436111 },
    .{ .name = "TMCI", .lat = 39.498056, .lon = -94.741944 },
    .{ .name = "TLAS", .lat = 36.143889, .lon = -115.00694 },
    .{ .name = "TSDF", .lat = 38.046111, .lon = -85.61 },
    .{ .name = "TMEM", .lat = 34.896111, .lon = -89.993056 },
    .{ .name = "TMIA", .lat = 25.758056, .lon = -80.491111 },
    .{ .name = "TMKE", .lat = 42.818889, .lon = -88.046111 },
    .{ .name = "TMSP", .lat = 44.871111, .lon = -92.933056 },
    .{ .name = "TBNA", .lat = 35.98, .lon = -86.661944 },
    .{ .name = "TMSY", .lat = 30.021944, .lon = -90.403056 },
    .{ .name = "TJFK", .lat = 40.588889, .lon = -73.881111 },
    .{ .name = "TEWR", .lat = 40.593056, .lon = -74.27 },
    .{ .name = "TOKC", .lat = 35.276111, .lon = -97.51 },
    .{ .name = "TMCO", .lat = 28.343889, .lon = -81.326111 },
    .{ .name = "TPHL", .lat = 39.948889, .lon = -75.068889 },
    .{ .name = "TPHX", .lat = 33.421111, .lon = -112.16305 },
    .{ .name = "TPIT", .lat = 40.501111, .lon = -80.486111 },
    .{ .name = "TRDU", .lat = 36.001944, .lon = -78.696944 },
    .{ .name = "TSLC", .lat = 40.966944, .lon = -111.93 },
    .{ .name = "TSJU", .lat = 18.473889, .lon = -66.178889 },
    .{ .name = "TSTL", .lat = 38.805, .lon = -90.488889 },
    .{ .name = "TTPA", .lat = 27.86, .lon = -82.518056 },
    .{ .name = "TTUL", .lat = 36.071111, .lon = -95.826944 },
    .{ .name = "TDCA", .lat = 38.758889, .lon = -76.961944 },
    .{ .name = "TPBI", .lat = 26.688056, .lon = -80.273056 },
    .{ .name = "TICH", .lat = 37.506944, .lon = -97.436944 },
};
