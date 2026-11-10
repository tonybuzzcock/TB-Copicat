# TB Copicat IC300

A VST 2.4 plugin model of the WEM Copicat IC300 tape echo, built from its
circuit drawing (drawing no. 577, 27-6-79, in `Docs/`).

- 64-bit Intel, **Mac OS X 10.8 and later**, made for Pro Tools 11 through Blue Cat PatchWork
- Built and tested on GitHub Actions; the build fails unless the binary declares
  10.8 as its minimum and links only libraries that ship with 10.8
- Personal, non-commercial use

## Controls

| # | Name | Control | Range |
|---|------|---------|-------|
| 1 | Gain | Input gain (stands in for the four input pots) | 0 – 10 |
| 2 | Swell | Echo level | 0 – 10 |
| 3 | Sustain | Repeats (playback fed back to the record amp): about 4 repeats at 5, about 10 at 7, long and steady at 9, runs away near 9.5 | 0 – 10 |
| 4–6 | Head 1/2/3 | Playback head buttons, any combination: button 1 = nearest head (70 ms), 2 = middle (220 ms), 3 = farthest (330 ms) | In / Out |
| 7 | Tone | Tone switch (the 4n7 across the heads): On is darker | Off / On |
| 8 | Echo | Echo in/out | In / Out |
| 9 | Speed | *plugin only*: tape speed trim, shown as button 1's echo time | 95 – 52 ms |
| 10 | Wow&Flut | *plugin only*: wow and flutter | 0 – 10 |
| 11 | Tape Age | *plugin only*: worn tape: duller, more hiss and dropouts, a bigger splice bump | 0 – 10 |
| 12 | Output | *plugin only*: output trim | ±24 dB |

The dry signal passes through the Gain control's input stage like the real unit,
so it gets louder as Gain goes up. It is at unity at the default (6).

## What's modelled

From the drawing:
- the input pot network and the 741 summing amp (120K || 100p over 47K)
- the 741 record amp (560K over 15K), with the Sustain feedback joining its summing node
- three playback heads in series on push buttons (unselected heads are shorted, so
  more heads means more inductance and a darker echo, especially with Tone on)
- the 741 playback preamp, whose time constants (153K × .022µ, 120K × 470p) give the standard tape playback curve: flat from about 50 Hz to 3 kHz per pass
- the Swell 10K log pot, the Sustain pot (its curve set by ear against a real unit), and the 741 output mixer (dry 27K, echo 10K, 47K || 100p)
- 741 rail clipping and slew rate; the drawing's 1.7 V record and 90 mV playback levels set the tape calibration

Not on the drawing, so estimated:
- **head times**: button 1 = 70 ms (set by the owner), buttons 2 and 3 = 220 / 330 ms (estimated) at normal speed, tape speed 9.5 cm/s and a 60 cm loop
- tape saturation, coating-thickness, gap and spacing losses, hiss, dropouts and the splice

The echo times are the easiest thing to change if they don't match a real unit
(`kHeadSeconds` in `Source/DSP/CopicatEcho.h`).

## The panel

On the Mac the plugin opens its own panel (800 × 600, 4:3): Gain on the left,
an animated tape loop over the three head buttons in the middle (it runs at the
Speed setting and wavers with Wow & Flutter; each head lights when its button
is in), Swell and Sustain on the right, Tone and Echo below. The strip along the
bottom has the tape-transport knobs with the presets and readout underneath. Drag knobs up/down (hold Shift for fine
control), double-click a knob to reset it, or use the scroll wheel. Click a head
button to latch it in (orange) or out. Rocker switches: press the top half for On/In, the
bottom half for Off/Out.

**Presets:** click SAVE, then a slot 1–8. Click a saved slot to recall it. Presets
are shared by every instance, in
`~/Library/Application Support/TB/TB Copicat IC300/Presets.txt`.

## Install

1. GitHub → Actions → latest run → Artifacts → `TB-Copicat-IC300-mac-vst`
2. Unzip twice to get `TB Copicat IC300.vst`
3. Copy it to `/Library/Audio/Plug-Ins/VST/` and rescan in PatchWork

## Build and test

- `make -C Tests run` — preset store and DSP tests, demo WAVs in `Tests/renders`
- `make -C Tests vst-run` — loads the plugin in a mini VST host
- `scripts/build_vst_mac.sh` — the Mac bundle (CI runs this, plus the panel test,
  which publishes screenshots to the `gui-preview` branch)
