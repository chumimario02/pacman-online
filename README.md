# PAC-MAN Online — Godot 4.7 + Node

Versión online para navegador del port de Pac-Man: hasta **4 jugadores** por sala,
Pac-Men de colores, controles táctiles y partidas de Pac-Man contra fantasmas.

El puerto de un solo jugador sigue intacto en `../pacman_godot`.

Al abrir el juego aparece una pantalla **PRESS START** con una cuadrícula animada
y Pac-Man huyendo de los fantasmas. Toca la pantalla, haz clic o pulsa Enter para
entrar al menú de salas. También puedes activar pantalla completa con el botón,
`F` o `F11`.

## Sala personalizada

Cada jugador elige libremente:

- **Rol:** Pac-Man o fantasma.
- **Color:** amarillo, azul, verde o rosa para Pac-Man; Blinky, Pinky, Inky o
  Clyde para fantasma.
- **Bots:** el anfitrión decide cuántos Pac-Men controlados por la CPU completan
  la partida (0 a 4). Con **0 bots** y fantasmas humanos, solo aparecen esos
  fantasmas (sin IA). Si nadie eligió fantasma, se mantienen los 4 fantasmas CPU.
  Con bots, la CPU completa los fantasmas que no haya elegido un jugador.

La partida puede ser de 1 a 4 Pac-Men contra 1 a 4 fantasmas. Si no queda
ningún Pac-Man humano, el anfitrión debe añadir al menos un bot para poder
iniciar. El color y el fantasma elegidos no se pueden repetir.

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
| Click / toque / Enter | Entrar desde la pantalla PRESS START |
| Flechas / WASD | Mover Pac-Man o fantasma |
| D-pad en pantalla | Mover en móvil/tableta |
| F / F11 o botón | Activar o salir de pantalla completa |
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
- **Salas:** código de 4 letras, máximo 4 jugadores humanos. Cada uno elige rol y color; el host elige cuántos bots Pac-Man completan la partida. Con 0 bots solo juegan los fantasmas humanos; si no hay ninguno, quedan los 4 fantasmas CPU.
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
