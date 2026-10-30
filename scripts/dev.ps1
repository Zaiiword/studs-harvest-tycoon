# Synchronisation live avec Roblox Studio (plugin Rojo -> Connect).
Start-Process -NoNewWindow rojo -ArgumentList "sourcemap", "default.project.json", "-o", "sourcemap.json", "--watch"
rojo serve default.project.json
