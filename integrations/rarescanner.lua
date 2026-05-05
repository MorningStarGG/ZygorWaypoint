local NS = _G.AzerothWaypointNS

NS.RegisterExternalWaypointSource("rarescanner", {
    displayName = "RareScanner",
    stackMatches = {
        "rarescanner\\core\\service\\addons\\rstomtom.lua",
    },
    transient = true,
    iconKey = "rarescanner",
})

