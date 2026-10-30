# Génère le fichier place build/StudsHarvestTycoon.rbxl (à ouvrir/publier dans Studio).
New-Item -ItemType Directory -Force build | Out-Null
rojo build default.project.json -o build/StudsHarvestTycoon.rbxl
