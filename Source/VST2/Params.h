// Params.h
// Parameter table shared by the VST wrapper, the editor and the preset store.
//
// Front-panel controls of the WEM Copicat IC300 first (as drawn on sheet 577:
// one input Gain standing in for the four input pots, Swell = echo level,
// Sustain = repeats, head buttons 1-3, Tone switch, Echo in/out), then the
// plugin-only controls for the tape transport.

#ifndef TBCC_PARAMS_H
#define TBCC_PARAMS_H

namespace tbcc
{

enum Param
{
    // Front panel
    kGain = 0, kSwell, kSustain, kHead1, kHead2, kHead3, kTone, kEcho,
    // Plugin only (bottom strip of the editor)
    kSpeed, kWow, kTapeAge, kOutput,
    kNumParams
};

enum Kind { kKnob, kSwitch, kHeadSw, kSpeedMs, kDb24 };

const char* const kParamNames[kNumParams] = {
    "Gain", "Swell", "Sustain", "Head 1", "Head 2", "Head 3", "Tone", "Echo",
    "Speed", "Wow&Flut", "Tape Age", "Output"
};

const int kParamKind[kNumParams] = {
    kKnob, kKnob, kKnob, kHeadSw, kHeadSw, kHeadSw, kSwitch, kSwitch,
    kSpeedMs, kKnob, kKnob, kDb24
};

const float kDefaults[kNumParams] = {
    0.6f, 0.55f, 0.45f, 1.0f, 0.0f, 0.0f, 0.0f, 1.0f,
    0.5f, 0.3f, 0.25f, 0.5f
};

const double kOutputRangeDb = 24.0;

// Which tape head each panel button plays, as on the owner's unit. Heads are
// numbered from the record head outwards (0 = shortest echo, see kHeadSeconds):
// button 1 = farthest head, button 2 = nearest, button 3 = middle.
const int kButtonHead[3] = { 2, 0, 1 };

inline bool isOn (float v) { return v >= 0.5f; }

} // namespace tbcc

#endif
