# UCI Build Guide: "LightingPanel"

A touchscreen panel for lights and shades. Build it in the UCI editor at 1280x800.

## Pages

| Page | Purpose |
|------|---------|
| `Lights` | Scene buttons and four area faders |
| `Shades` | Open / Stop / Close for each window |
| `Setup` | IP addresses and online indicator (installer use) |

Use Page Change buttons for navigation. The tab bar (Lights, Shades, Setup) sits along the top of every page, 80 px high.

## Page: Lights

Scenes row (y 120):

| Element | Type | Bind to |
|---------|------|---------|
| Full | Button, text "Full" | `LightingControl` > `Scene 1` (Trigger) |
| Presentation | Button | `Scene 2` |
| Video | Button | `Scene 3` |
| Off | Button | `Scene 4` |
| Scene indicators | Button Legend lit state, or LED behind each button | `SceneActive 1..4` |

Faders row (y 260), four columns, width 240, spaced 300 px:

| Element | Type | Bind to |
|---------|------|---------|
| Area label | Text | static: Front, Middle, Back, Accent |
| Vertical fader (100x420) | Fader | `LightLevel 1..4` |
| Level readout | Text Box | same control, display as `%` |

Footer: Status text box bound to `Status`.

## Page: Shades

Two rows, one per window:

| Element | Type | Bind to |
|---------|------|---------|
| Window label | Text | static: Window A / Window B |
| Open | Trigger Button | `ShadeOpen 1..2` |
| Stop | Trigger Button | `ShadeStop 1..2` |
| Close | Trigger Button | `ShadeClose 1..2` |
| State | Text Box (read-only) | `ShadeStatus 1..2` |

Tip: copy row 1, paste, and change the pin index to 2.

## Page: Setup

| Element | Type | Bind to |
|---------|------|---------|
| Lighting IP | Text Box (editable) | `LightIP` |
| Shade IP | Text Box (editable) | `ShadeIP` |
| Online | LED | `Online` |

Set IP defaults on the Script component pins (Default Value) so the panel works after a reboot.

## Wire-up

1. Add a Script component named `LightingControl` and paste `src/lighting_control.lua`.
2. Add all control pins from the script header. Use **Count** for the arrayed pins
   (4 for LightLevel / Scene / SceneActive, 2 for the shade controls).
3. Create a UCI named `LightingPanel` with the three pages.
4. Emulate (F5) and open the UCI viewer.

## Testing without hardware

- **Lights:** run a UDP listener on your computer (Packet Sender, or `nc -ul 5000`),
  set `LightIP` to your computer's IP, and watch the commands arrive. Drag a fader and note that
  commands are throttled; press a scene and note that all four areas are sent with the 1500 ms fade.
- **Shades:** run any HTTP server (`python3 -m http.server 80` returns 404 for the shade URL, which
  shows the error path; a stub that returns 200 shows the success path).
- **Online LED:** it only turns on if something replies to the UDP `PING`.
  Use Packet Sender's auto-response to test it.
