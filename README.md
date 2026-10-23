# PAC-MAN Online — Godot 4.7 + Node

Versión online para navegador del port de Pac-Man: hasta **4 jugadores** por sala,
Pac-Men de colores, controles táctiles y partidas de Pac-Man contra fantasmas.

El puerto de un solo jugador sigue intacto en `../pacman_godot`.

## Modos

- **Equipo — 4 Pac-Men:** todos los jugadores controlan un Pac-Man. Los espacios
  libres los ocupan CPUs.
- **Fantasma — 1 Pac-Man vs 3 fantasmas:** el primer jugador es Pac-Man y los
  demás controlan a Blinky, Pinky, Inky y Clyde. La CPU completa los huecos.
- **Fantasma — 2 Pac-Men vs 2 fantasmas:** dos jugadores son Pac-Men y dos son
  fantasmas; la CPU completa los huecos.

El anfitrión elige el modo, el color de su Pac-Man e inicia la partida. Los
Pac-Men pueden ser amarillo, azul, verde o rosa. Los fantasmas conservan sus
colores clásicos.

## Jugar en local

Requisitos: **Node.js 20 o superior**.

```bat
cd pacman_online
npm --prefix server install
node server/server.js
```

Abre <http://localhost:3000>. Para jugar con otra persona, comparte la URL del
servidor y el código de sala de 4 letras. En la misma red, la otra persona debe
usar la IP del equipo anfitrión en lugar de `localhost`.

También se puede abrir el cliente con Godot:

```bat
run_game.bat
```

El cliente de escritorio conecta por defecto a `ws://127.0.0.1:3000/ws`. Para
usar otro servidor:

```bat
set PACMAN_WS=ws://mi-servidor:3000/ws
run_game.bat
```

## Controles

| Entrada | Acción |
| --- | --- |
| Flechas / WASD | Mover Pac-Man o fantasma |
| D-pad en pantalla | Mover en móvil/tableta |
| P | Pausa (solo el anfitrión) |
| M | Silenciar |
| Esc | Volver al lobby |
| Enter / Espacio | Reiniciar al terminar la partida (anfitrión) |

En el lobby se puede activar **CONTROLES TÁCTILES**. En dispositivos con
pantalla táctil se activan automáticamente.

## Arquitectura

- **Cliente:** Godot 4.7 exportado a Web (`gl_compatibility`, sin hilos).
- **Servidor:** Node.js con `ws`, sirve los archivos del build y retransmite
  mensajes por `/ws`.
- **Autoridad:** el anfitrión simula la partida y envía snapshots a 20 Hz. Los
  clientes interpolan posiciones y aplican eventos.
- **Salas:** código de 4 letras, máximo 4 jugadores, relleno automático con IA.
- Si un jugador se desconecta, su personaje pasa a ser controlado por la CPU.
- Si el anfitrión sale, la sala se cierra.

## Build web

El build exportado se guarda en `server/public/` y se sirve directamente:

```bat
"C:\Users\ThinkPad\AppData\Local\Temp\opencode\godot\Godot_v4.7.2-stable_win64_console.exe" ^
  --headless --path . --export-release "Web" "server/public/index.html"
```

El preset `Web` incluye explícitamente `assets/pellets.dat`. Godot trata los
`.csv` como fuentes de traducción, por eso los datos de puntos viajan en un
`.dat` sin procesar. No elimines esa entrada de `include_filter`.

## Despliegue en Render

El archivo `render.yaml` define un único Web Service desde la raíz del
repositorio:

- Build: `npm --prefix server install`
- Start: `node server/server.js`
- Health check: `/health`

Pasos:

1. Sube este proyecto a GitHub.
2. En Render, crea un **Blueprint** desde el repositorio, o un **Web Service**
   con los comandos anteriores.
3. Render inyecta `PORT`; el servidor sirve el juego y el WebSocket en la misma
   URL. No hace falta configurar el host del WebSocket en el cliente web.
4. Comprueba `https://TU-SERVICIO.onrender.com/health`.

Los servicios gratuitos de Render se suspenden cuando están inactivos; la
primera conexión puede tardar unos segundos.

## Pruebas

Servidor y salas:

```bat
npm --prefix server test
```

Comprobación de sintaxis y partidas simuladas de Godot:

```bat
godot --headless --path . --quit
godot --headless --path . -- --smoke
godot --headless --path . -- --online-smoke
```

Resultados esperados: `SERVER TEST: ALL OK`, `SMOKE RESULT: ALL OK` y
`ONLINE SMOKE RESULT: ALL OK`. La prueba del navegador con dos clientes se hace
con Playwright y Microsoft Edge en modo headless.

## Estructura

```text
pacman_online/
  project.godot
  main.tscn
  export_presets.cfg
  render.yaml
  scripts/
    config.gd          constantes, colores y laberinto
    maze.gd            rejilla, pellets y campos de distancia
    maze_view.gd       dibujo del laberinto
    pacman.gd          movimiento y animación de Pac-Man
    ghost.gd           IA de los fantasmas
    lobby.gd           sala, modo, colores y controles táctiles
    hud.gd             HUD multijugador y overlays
    net.gd             cliente WebSocket
    main.gd            estados, simulación del host y snapshots
    touch_controls.gd  D-pad y botones táctiles
    audio.gd           sonidos y loops
  assets/
    pellets.dat        datos de los 244 pellets (incluido en el PCK)
    pellets.csv        fuente original (respaldo local)
    sprites32.png, maze_bg.png, bg.png, scanlines.png, ...
    sounds/*.wav
  server/
    server.js          relay WebSocket + servidor estático
    test_rooms.js      prueba de salas
    public/            build web exportado
```

## Créditos

Sprites de los ejemplos de Phaser. Fuente Press Start 2P (SIL Open Font
License). Proyecto fan-made, sin afiliación con Bandai Namco.
