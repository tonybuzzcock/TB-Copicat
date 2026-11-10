// editor_test.mm  (macOS only)
// Loads the built plugin, opens its panel in an offscreen window the way a host
// does, renders screenshots, drives the controls with synthetic mouse events,
// checks host automation messages, and closes it again.
//
//   editor_test <plugin binary> <output dir for PNGs>

#import <Cocoa/Cocoa.h>

#include "../Source/VST2/vst2_abi.h"
#include "../Source/VST2/Params.h"
#include "../Source/VST2/Editor.h"

#include <dlfcn.h>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <string>
#include <algorithm>

static int failures = 0;
static void check (bool ok, const char* what)
{
    std::printf ("  %s  %s\n", ok ? "ok  " : "FAIL", what);
    if (! ok) ++failures;
}

static int automateCalls = 0, beginCalls = 0, endCalls = 0;
static VstIntPtr VST_CALL hostCallback (AEffect*, VstInt32 opcode, VstInt32, VstIntPtr, void*, float)
{
    switch (opcode)
    {
        case audioMasterVersion:   return 2400;
        case audioMasterAutomate:  ++automateCalls; return 0;
        case audioMasterBeginEdit: ++beginCalls; return 1;
        case audioMasterEndEdit:   ++endCalls; return 1;
        default:                   return 0;
    }
}

typedef AEffect* (*EntryProc) (audioMasterCallback);

static VstIntPtr call (AEffect* e, VstInt32 op, VstInt32 idx = 0, VstIntPtr val = 0, void* ptr = 0, float opt = 0.0f)
{
    return e->dispatcher (e, op, idx, val, ptr, opt);
}

static NSData* renderPNG (NSView* v, const std::string& path)
{
    const NSRect b = [v bounds];
    NSBitmapImageRep* rep = [v bitmapImageRepForCachingDisplayInRect: b];
    [v cacheDisplayInRect: b toBitmapImageRep: rep];
    NSData* png = [rep representationUsingType: NSPNGFileType properties: [NSDictionary dictionary]];
    [png writeToFile: [NSString stringWithUTF8String: path.c_str()] atomically: YES];
    std::printf ("  wrote %s (%lu bytes)\n", path.c_str(), (unsigned long) [png length]);
    return png;
}

// Send a mouse event at a point in the panel's (flipped) coordinates.
static void mouse (NSWindow* w, NSView* v, NSEventType type, NSPoint panelPt, int clicks = 1)
{
    const NSPoint wp = [v convertPoint: panelPt toView: nil];
    NSEvent* e = [NSEvent mouseEventWithType: type location: wp modifierFlags: 0 timestamp: 0
                                windowNumber: [w windowNumber] context: nil eventNumber: 0
                                  clickCount: clicks pressure: 1.0f];
    if (type == NSLeftMouseDown) [v mouseDown: e];
    else if (type == NSLeftMouseDragged) [v mouseDragged: e];
    else [v mouseUp: e];
}

static void pump (double secs)
{
    [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: secs]];
}

int main (int argc, char** argv)
{
    if (argc < 3) { std::printf ("usage: %s <plugin binary> <png dir>\n", argv[0]); return 2; }
    setvbuf (stdout, 0, _IONBF, 0);   // unbuffered, so a crash still shows how far it got
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    [NSApplication sharedApplication];
    const std::string dir = argv[2];

    // Keep the test's presets away from any real ones
    const std::string presetFile = dir + "/test_presets/Presets.txt";
    setenv ("TBCC_PRESET_FILE", presetFile.c_str(), 1);
    std::remove (presetFile.c_str());

    void* lib = dlopen (argv[1], RTLD_NOW | RTLD_LOCAL);
    if (! lib) { std::printf ("dlopen failed: %s\n", dlerror()); return 1; }
    EntryProc entry = (EntryProc) dlsym (lib, "VSTPluginMain");
    if (! entry) { std::printf ("no entry point\n"); return 1; }
    AEffect* e = entry (hostCallback);
    call (e, effOpen);
    call (e, effSetSampleRate, 0, 0, 0, 44100.0f);
    call (e, effMainsChanged, 0, 1);

    using namespace tbcc;
    std::printf ("Editor\n");
    check ((e->flags & effFlagsHasEditor) != 0, "plugin reports a custom editor");
    ERect* r = 0;
    call (e, effEditGetRect, 0, 0, &r);
    check (r && r->right - r->left == kEditorWidth && r->bottom - r->top == kEditorHeight,
           "editor size 1040 x 330");

    NSWindow* win = [[NSWindow alloc] initWithContentRect: NSMakeRect (0, 0, kEditorWidth, kEditorHeight)
                                                styleMask: NSBorderlessWindowMask
                                                  backing: NSBackingStoreBuffered defer: NO];
    NSView* parent = [win contentView];
    check (call (e, effEditOpen, 0, 0, parent) == 1, "effEditOpen succeeds");
    check ([[parent subviews] count] == 1, "panel view added to the host's view");
    NSView* panel = [[parent subviews] count] ? [[parent subviews] objectAtIndex: 0] : nil;
    if (! panel) return 1;
    check (NSEqualSizes ([panel frame].size, NSMakeSize (kEditorWidth, kEditorHeight)), "panel has the declared size");

    NSData* pngDefault = renderPNG (panel, dir + "/panel_default.png");
    check ([pngDefault length] > 10000, "panel renders");

    std::printf ("\nControls\n");
    // Drag the Swell knob up 50 px: +0.25
    const float g0 = e->getParameter (e, kSwell);
    automateCalls = beginCalls = endCalls = 0;
    mouse (win, panel, NSLeftMouseDown,    NSMakePoint (305, 112));
    mouse (win, panel, NSLeftMouseDragged, NSMakePoint (305, 87));
    mouse (win, panel, NSLeftMouseDragged, NSMakePoint (305, 62));
    mouse (win, panel, NSLeftMouseUp,      NSMakePoint (305, 62));
    const float g1 = e->getParameter (e, kSwell);
    std::printf ("  Swell %.2f -> %.2f\n", g0, g1);
    check (std::fabs (g1 - std::min (1.0f, g0 + 0.25f)) < 0.02f, "dragging a knob up turns it up");
    check (automateCalls > 0 && beginCalls == 1 && endCalls == 1, "host gets begin / automate / end");

    // Double-click returns it to default
    mouse (win, panel, NSLeftMouseDown, NSMakePoint (305, 112), 2);
    mouse (win, panel, NSLeftMouseUp,   NSMakePoint (305, 112), 2);
    check (std::fabs (e->getParameter (e, kSwell) - kDefaults[kSwell]) < 1e-6f, "double-click resets a knob");

    // Head buttons latch in and out
    mouse (win, panel, NSLeftMouseDown, NSMakePoint (640, 112));
    mouse (win, panel, NSLeftMouseUp,   NSMakePoint (640, 112));
    check (e->getParameter (e, kHead2) >= 0.5f, "head 2 button latches in");
    mouse (win, panel, NSLeftMouseDown, NSMakePoint (570, 112));
    mouse (win, panel, NSLeftMouseUp,   NSMakePoint (570, 112));
    check (e->getParameter (e, kHead1) < 0.5f, "head 1 button pops out");

    // Rockers: Tone on (top half), Echo out (bottom half)
    mouse (win, panel, NSLeftMouseDown, NSMakePoint (870, 102));
    mouse (win, panel, NSLeftMouseUp,   NSMakePoint (870, 102));
    check (e->getParameter (e, kTone) >= 0.5f, "Tone rocker switches on");
    mouse (win, panel, NSLeftMouseDown, NSMakePoint (965, 122));
    mouse (win, panel, NSLeftMouseUp,   NSMakePoint (965, 122));
    check (e->getParameter (e, kEcho) < 0.5f, "Echo rocker switches out");
    mouse (win, panel, NSLeftMouseDown, NSMakePoint (965, 102));
    mouse (win, panel, NSLeftMouseUp,   NSMakePoint (965, 102));
    check (e->getParameter (e, kEcho) >= 0.5f, "and back in");

    // Strip knob: Tape Age by scroll-free drag
    const float a0 = e->getParameter (e, kTapeAge);
    mouse (win, panel, NSLeftMouseDown,    NSMakePoint (355, 296));
    mouse (win, panel, NSLeftMouseDragged, NSMakePoint (355, 276));
    mouse (win, panel, NSLeftMouseUp,      NSMakePoint (355, 276));
    check (e->getParameter (e, kTapeAge) > a0 + 0.05f, "strip knobs turn");

    std::printf ("\nPresets\n");
    #define SLOT(k) NSMakePoint (564.0 + (k) * 27.0 + 12.0, 296.0)
    e->setParameter (e, kSustain, 0.3f);
    e->setParameter (e, kHead3, 1.0f);
    pump (0.1);
    mouse (win, panel, NSLeftMouseDown, NSMakePoint (527, 296));    // SAVE
    mouse (win, panel, NSLeftMouseUp,   NSMakePoint (527, 296));
    mouse (win, panel, NSLeftMouseDown, SLOT (2));                   // slot 3
    mouse (win, panel, NSLeftMouseUp,   SLOT (2));
    FILE* pf = std::fopen (presetFile.c_str(), "r");
    check (pf != 0, "SAVE then a slot writes the preset file");
    if (pf) std::fclose (pf);
    renderPNG (panel, dir + "/panel_preset_saved.png");

    e->setParameter (e, kSustain, 0.9f);
    e->setParameter (e, kHead3, 0.0f);
    pump (0.1);
    automateCalls = 0;
    mouse (win, panel, NSLeftMouseDown, SLOT (2));
    mouse (win, panel, NSLeftMouseUp,   SLOT (2));
    check (std::fabs (e->getParameter (e, kSustain) - 0.3f) < 1e-5f
           && e->getParameter (e, kHead3) >= 0.5f, "clicking the slot recalls the saved settings");
    check (automateCalls >= kNumParams, "recall tells the host about every parameter");

    const float before = e->getParameter (e, kSustain);
    mouse (win, panel, NSLeftMouseDown, SLOT (5));                   // empty slot 6
    mouse (win, panel, NSLeftMouseUp,   SLOT (5));
    check (e->getParameter (e, kSustain) == before, "an empty slot changes nothing");

    std::printf ("\nHost automation shows on the panel\n");
    e->setParameter (e, kGain, 0.9f);
    e->setParameter (e, kHead1, 1.0f);
    pump (0.3);
    NSData* pngAfter = renderPNG (panel, dir + "/panel_changed.png");
    check (! [pngAfter isEqualToData: pngDefault], "panel redraws after host changes");

    // A showcase render: multi-head repeats
    e->setParameter (e, kGain, 0.6f);
    e->setParameter (e, kSwell, 0.65f);
    e->setParameter (e, kSustain, 0.55f);
    e->setParameter (e, kHead1, 1.0f);
    e->setParameter (e, kHead2, 0.0f);
    e->setParameter (e, kHead3, 1.0f);
    e->setParameter (e, kTone, 0.0f);
    e->setParameter (e, kWow, 0.4f);
    pump (0.3);
    renderPNG (panel, dir + "/panel_showcase.png");

    std::printf ("\nClose\n");
    call (e, effEditClose);
    check ([[parent subviews] count] == 0, "effEditClose removes the panel");
    check (call (e, effEditOpen, 0, 0, parent) == 1 && [[parent subviews] count] == 1, "reopens");
    call (e, effEditClose);
    call (e, effMainsChanged, 0, 0);
    call (e, effClose);
    [win release];
    [pool release];      // drain before unloading the plugin's code
    dlclose (lib);

    std::printf ("\n%s (%d failure%s)\n", failures ? "FAILED" : "ALL EDITOR CHECKS PASSED", failures, failures == 1 ? "" : "s");
    return failures ? 1 : 0;
}
