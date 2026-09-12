"""Build the TouchDesigner end of the Godot bridge.

FINAL_V.md section 16 settles the architecture: TouchDesigner is the *lab*,
Godot shaders are the *engine*. This script builds the lab bench — twelve
sliders wired to an OSC Out CHOP pointed at the running game — so that moving a
slider here moves a uniform in `shaders/psychedelic.gdshader` while you watch
the game. When the look is right you read the numbers off and write them into a
scene. Nothing in this file ships; it is the thing that makes porting a TD graph
a five-minute job instead of an afternoon.

HOW TO RUN IT
    1. Start the game's lab scene:  Start-PsyLab.ps1
    2. In TouchDesigner, open the Textport  (Alt+T)
    3. Paste this whole file in and press Enter.
       Or: drop it in a Text DAT, right-click, "Run Script".

It builds `/project1/wizards_dials`. Open that, and the twelve values on the
`dials` Constant CHOP are the twelve uniforms. Drag one and the game changes.

WHY A CONSTANT CHOP AND NOT SLIDER WIDGETS
    Because a Constant CHOP's parameter fields already drag like sliders, they
    survive every TD version unchanged, and they are trivially replaceable: swap
    the CHOP for an Audio Analysis, an LFO, a Noise, a Mouse In, anything at all
    with channels named after the dials, and it drives the game the same way.
    That substitution is the entire point of the bridge. The dial names are the
    contract, not the widget.

WHAT GODOT EXPECTS
    An OSC message per channel with one float. The dial is the LAST segment of
    the address, so `/lut_strength`, `/psy/lut_strength` and anything else
    ending in `/lut_strength` all land on the same uniform. Godot ignores names
    it does not recognise, so a channel this build has never heard of is a
    harmless no-op rather than a crash.
"""

HOST = "127.0.0.1"
PORT = 9000

# Name, default, low, high. These mirror `PsychedelicRig.NEUTRAL` in the game,
# and the defaults here are that table's neutral values — so a freshly built
# patch sends the shader's own no-op state and changes nothing until you drag
# something. Adding a dial in Godot means adding a line here.
DIALS = [
    ("lut_strength", 0.0, 0.0, 1.0),
    ("kaleidoscope_segments", 0.0, 0.0, 24.0),
    ("kaleidoscope_spin", 0.0, -3.2, 3.2),
    ("feedback_strength", 0.0, 0.0, 1.0),
    ("feedback_zoom", 1.0, 0.9, 1.1),
    ("feedback_spin", 0.0, -0.5, 0.5),
    ("chromatic_offset", 0.0, 0.0, 0.05),
    ("displacement_strength", 0.0, 0.0, 0.3),
    ("displacement_scroll", 0.3, -2.0, 2.0),
    ("cut_intensity", 0.0, 0.0, 1.0),
    ("cut_seed", 0.0, 0.0, 64.0),
    ("cut_rate", 8.0, 0.5, 30.0),
]


def _set(operator, parameter_name, value, missing):
    """Set a parameter if this TD version has it under that name.

    TouchDesigner renames parameters between releases often enough that a script
    which assumes a spelling is a script that works on one machine. Anything
    that cannot be found is collected and printed at the end with the value it
    wanted, so the two or three that need setting by hand are named rather than
    silently skipped.
    """
    parameter = getattr(operator.par, parameter_name, None)
    if parameter is None:
        missing.append((operator.path, parameter_name, value))
        return False
    try:
        parameter.val = value
    except Exception as error:  # a read-only or wrong-typed parameter
        missing.append((operator.path, parameter_name, "%s (%s)" % (value, error)))
        return False
    return True


def build(parent_path="/project1", name="wizards_dials"):
    parent = op(parent_path)
    if parent is None:
        raise RuntimeError("No operator at %s — pass the path you want it under." % parent_path)

    existing = parent.op(name)
    if existing is not None:
        existing.destroy()
    box = parent.create(containerCOMP, name)
    box.nodeX, box.nodeY = 0, 0
    missing = []

    # The dials themselves.
    dials = box.create(constantCHOP, "dials")
    dials.nodeX, dials.nodeY = 0, 0
    for index, (dial_name, default, low, high) in enumerate(DIALS):
        _set(dials, "const%dname" % index, dial_name, missing)
        _set(dials, "const%dvalue" % index, default, missing)
        # Normalised drag range, so the field behaves like a slider rather than
        # like a number box with no idea what is reasonable.
        parameter = getattr(dials.par, "const%dvalue" % index, None)
        if parameter is not None:
            try:
                parameter.normMin, parameter.normMax = low, high
            except Exception:
                pass
    # Clear every unused slot, or the CHOP ships twenty-eight channels called
    # chan1 and Godot spends its frame ignoring them.
    for index in range(len(DIALS), 40):
        if getattr(dials.par, "const%dname" % index, None) is not None:
            _set(dials, "const%dname" % index, "", missing)

    # The wire.
    sender = box.create(oscoutCHOP, "to_godot")
    sender.nodeX, sender.nodeY = 200, 0
    sender.inputConnectors[0].connect(dials)
    _set(sender, "netaddress", HOST, missing)
    _set(sender, "port", PORT, missing)
    # One message per channel, which is what makes the channel name the address.
    _set(sender, "format", "oneperchan", missing)
    _set(sender, "active", True, missing)

    # A readout, so you can see what is leaving rather than guessing.
    watch = box.create(nullCHOP, "watch")
    watch.nodeX, watch.nodeY = 200, -160
    watch.inputConnectors[0].connect(dials)
    watch.viewer = True

    print("")
    print("  built %s" % box.path)
    print("  sending %d dials to %s:%d" % (len(DIALS), HOST, PORT))
    print("  open %s and drag a value on 'dials'" % box.path)
    if missing:
        print("")
        print("  this TouchDesigner spells these differently — set them by hand:")
        for path, parameter_name, value in missing:
            print("    %-34s %-16s -> %s" % (path, parameter_name, value))
        print("  (on the OSC Out CHOP the ones that matter are the network")
        print("   address, the port, and 'one message per channel')")
    print("")
    return box


build()
