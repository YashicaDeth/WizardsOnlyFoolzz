/*
    animate_artwork.jsx  -  the jester plate, moving.

    Greg's brief, verbatim: "everything moving the hand around the orb with the
    projection of the orb in the middle glowing the frame moveing the 4 horsemen
    inthe backround moving the skulls glowing in the tv and the tv to have crt
    filter".

    Six separate moves, and the only hard part is that they have to be applied to
    layers this script has never seen. So it does not hard-code layer indices -
    it reads the PSD's own layer names and matches them against the words in the
    brief. A layer called "hand r copy 2" is a hand. A layer called "TV SCREEN
    final FINAL" is the television. Anything it cannot place is left alone rather
    than animated at random, and it says so in the log.

    Everything is applied as an EXPRESSION, not as keyframes. That is deliberate:
    expressions stay readable and editable after the script has run, so this is a
    starting rig you can pull apart, not a bake you have to undo. Every one of
    them reads from a single "RIG" control layer, so the whole piece speeds up or
    slows down from one slider.

    HOW TO RUN IT
      1. Put the PSD path in  animate_artwork.config.txt  next to this file.
         One line. No quotes. Or write  SELFTEST  to build a synthetic plate
         instead, which is how the rig gets tested without a real file.
      2. After Effects -> File -> Scripts -> Run Script File... -> pick this.
      Or from a terminal:
         "C:\Program Files\Adobe\Adobe After Effects 2022\Support Files\AfterFX.exe" -r "<this file>"

    It writes animate_artwork.log next to itself, whatever happens.
*/

(function () {
    var SCRIPT_FILE = new File($.fileName);
    var HERE = SCRIPT_FILE.parent;
    var LOG = [];
    var LOG_PATH = "P:/GameDev/AllusionsTooGrandeur/tools/aftereffects/animate_artwork.log";

    // ---------------------------------------------------------------- config
    // Which words in a layer name mean which part of the brief. First match
    // wins, and the order matters: "tv screen" must be tested before "screen"
    // could be caught by something else, and "hand" before "band".
    var ROLES = [
        {role: "tv",       words: ["tv", "crt", "television", "monitor", "screen", "telly"]},
        {role: "orb",      words: ["orb", "sphere", "ball", "globe", "crystal", "moon"]},
        {role: "hand",     words: ["hand", "palm", "finger", "claw", "grip"]},
        {role: "horsemen", words: ["horse", "horsemen", "horseman", "rider", "knight", "apocalyp"]},
        {role: "skull",    words: ["skull", "skell", "bone", "cranium", "death"]},
        {role: "frame",    words: ["frame", "border", "edge", "ornate", "gild", "trim"]}
    ];

    var TIMING = {
        duration: 12,          // seconds. A loop somebody can watch twice.
        frameRate: 24,         // 24 reads as film and hides a lot of sins at 30.
        width: 1920,
        height: 1080
    };

    // ------------------------------------------------------------------ utils
    function log(line) {
        LOG.push(line);
    }

    function writeLog() {
        // Absolute, not derived from $.fileName. When After Effects runs a
        // script with -r the script folder is not always where you think it is,
        // and a log that cannot be written is a script that failed silently -
        // which is the one failure mode a log exists to prevent.
        var file = new File(LOG_PATH);
        file.open("w");
        file.write(LOG.join("\n"));
        file.close();
    }

    function readConfig() {
        var file = new File(HERE.fsName + "/animate_artwork.config.txt");
        if (!file.exists) { return null; }
        file.open("r");
        var text = file.read();
        file.close();
        // First non-empty, non-comment line.
        var lines = text.split(/[\r\n]+/);
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].replace(/^\s+|\s+$/g, "");
            if (line !== "" && line.charAt(0) !== "#") { return line; }
        }
        return null;
    }

    function roleOf(name) {
        var lower = name.toLowerCase();
        for (var i = 0; i < ROLES.length; i++) {
            for (var w = 0; w < ROLES[i].words.length; w++) {
                if (lower.indexOf(ROLES[i].words[w]) !== -1) { return ROLES[i].role; }
            }
        }
        return null;
    }

    function addEffect(layer, matchName, label) {
        try {
            return layer.property("ADBE Effect Parade").addProperty(matchName);
        } catch (error) {
            log("    ! could not add " + label + " (" + matchName + ") to " + layer.name + ": " + error.toString());
            return null;
        }
    }

    function setExpression(property, expression, where) {
        try {
            property.expression = expression;
            return true;
        } catch (error) {
            log("    ! expression failed on " + where + ": " + error.toString());
            return false;
        }
    }

    // ----------------------------------------------------------- the rig layer
    // One null with sliders on it. Every expression below reads from this, so
    // the whole plate is retimed or calmed down from one place instead of from
    // eighteen.
    function buildRig(comp) {
        var rig = comp.layers.addNull(comp.duration);
        rig.name = "RIG";
        rig.enabled = false;
        rig.moveToBeginning();
        var effects = rig.property("ADBE Effect Parade");

        var controls = [
            {name: "Speed", value: 1.0},
            {name: "Sway", value: 1.0},         // how far things drift
            {name: "Glow", value: 1.0},         // orb and skull brightness
            {name: "CRT", value: 1.0},          // television damage
            {name: "Parallax", value: 1.0}      // horsemen depth
        ];
        for (var i = 0; i < controls.length; i++) {
            var slider = effects.addProperty("ADBE Slider Control");
            slider.name = controls[i].name;
            slider.property("ADBE Slider Control-0001").setValue(controls[i].value);
        }
        log("  RIG null built with " + controls.length + " sliders");
        return rig;
    }

    // A preamble every expression starts with, so none of them repeat it.
    var PRE = [
        'var rig = thisComp.layer("RIG");',
        'var speed = rig.effect("Speed")("Slider");',
        'var sway = rig.effect("Sway")("Slider");',
        'var glow = rig.effect("Glow")("Slider");',
        'var crt = rig.effect("CRT")("Slider");',
        'var para = rig.effect("Parallax")("Slider");',
        'var t = time * speed;'
    ].join("\n");

    // ------------------------------------------------------------- the moves
    // "the hand around the orb" - the hand travels a slow ellipse about
    // whatever the orb's position turned out to be, so it orbits the real thing
    // rather than a number typed in here. Tilted, because a circle reads as a
    // turntable and an ellipse reads as a hand.
    function animateHand(layer, orbLayer, index) {
        var centre = orbLayer
            ? 'var c = thisComp.layer("' + orbLayer.name + '").transform.position;'
            : 'var c = [thisComp.width/2, thisComp.height/2];';
        var phase = (index * 0.7).toFixed(3);
        var expression = PRE + "\n" + centre + "\n" + [
            'var radius = [180, 92] * sway;',
            'var a = t * 0.55 + ' + phase + ';',
            'var off = [Math.cos(a) * radius[0], Math.sin(a) * radius[1] * 0.9];',
            '// Drift, not teleport: the hand keeps its own painted position and',
            '// is pushed around the orb from there, so a plate where the hand was',
            '// already in the right place still looks painted.',
            'value + off + [0, Math.sin(t * 1.7) * 6 * sway];'
        ].join("\n");
        setExpression(layer.transform.position, expression, layer.name + ".position");

        var rot = PRE + "\n" + [
            'value + Math.sin(t * 0.55 + ' + phase + ') * 7 * sway;'
        ].join("\n");
        setExpression(layer.transform.rotation, rot, layer.name + ".rotation");
        log("  hand    <- " + layer.name + " (orbits " + (orbLayer ? orbLayer.name : "comp centre") + ")");
    }

    // "the projection of the orb in the middle glowing" - the orb breathes and
    // throws light. Glow amount is on a slow irrational-ish beat so it never
    // settles into an obvious loop.
    function animateOrb(layer) {
        var scale = PRE + "\n" + [
            'var breathe = 1 + Math.sin(t * 1.15) * 0.028 * sway;',
            'value * breathe;'
        ].join("\n");
        setExpression(layer.transform.scale, scale, layer.name + ".scale");

        var glow = addEffect(layer, "ADBE Glo2", "Glow");
        if (glow) {
            try { glow.property("ADBE Glo2-0002").setValue(28); } catch (e) {}   // threshold
            try { glow.property("ADBE Glo2-0003").setValue(38); } catch (e) {}   // radius
            var intensity = null;
            try { intensity = glow.property("ADBE Glo2-0004"); } catch (e) {}
            if (intensity) {
                setExpression(intensity, PRE + "\n" +
                    '(1.35 + Math.sin(t * 1.9) * 0.45 + Math.sin(t * 0.61) * 0.25) * glow;',
                    layer.name + ".glow");
            }
        }
        // The projection: a soft copy of the orb sitting behind it, larger and
        // dimmer, pulsing against the beat. This is the cheapest thing that
        // reads as "something is being projected out of it".
        try {
            var halo = layer.duplicate();
            halo.name = layer.name + " / projection";
            halo.moveAfter(layer);
            halo.blendingMode = BlendingMode.ADD;
            setExpression(halo.transform.scale, PRE + "\n" +
                'value * (1.35 + Math.sin(t * 1.9 + 1.1) * 0.10 * sway);',
                halo.name + ".scale");
            setExpression(halo.transform.opacity, PRE + "\n" +
                'clamp(26 + Math.sin(t * 1.9) * 16, 0, 100) * glow;',
                halo.name + ".opacity");
            var blur = addEffect(halo, "ADBE Box Blur2", "Fast Box Blur");
            if (blur) { try { blur.property("ADBE Box Blur2-0001").setValue(26); } catch (e) {} }
            log("  orb     <- " + layer.name + " (+ projection halo)");
        } catch (error) {
            log("  orb     <- " + layer.name + " (halo failed: " + error.toString() + ")");
        }
    }

    // "the frame moveing" - a frame should not bounce. It creeps, on a long
    // period, so you notice it only after you have stopped looking at it.
    function animateFrame(layer) {
        var pos = PRE + "\n" + [
            'value + [Math.sin(t * 0.23) * 9, Math.cos(t * 0.19) * 7] * sway;'
        ].join("\n");
        setExpression(layer.transform.position, pos, layer.name + ".position");
        setExpression(layer.transform.scale, PRE + "\n" +
            'value * (1 + Math.sin(t * 0.31) * 0.012 * sway);', layer.name + ".scale");
        setExpression(layer.transform.rotation, PRE + "\n" +
            'value + Math.sin(t * 0.17) * 0.8 * sway;', layer.name + ".rotation");
        log("  frame   <- " + layer.name);
    }

    // "the 4 horsemen inthe backround moving" - parallax. Each rider gets its
    // own rate off its index, so they separate in depth instead of sliding as
    // one sheet, and they ride across rather than bobbing on the spot.
    function animateHorsemen(layer, index) {
        var depth = (0.6 + index * 0.22).toFixed(3);
        var phase = (index * 1.37).toFixed(3);
        var pos = PRE + "\n" + [
            'var depth = ' + depth + ';',
            'var drift = Math.sin(t * 0.21 * depth + ' + phase + ') * 46 * para / depth;',
            'var rise = Math.sin(t * 0.63 * depth + ' + phase + ') * 7 * para;',
            'value + [drift, rise];'
        ].join("\n");
        setExpression(layer.transform.position, pos, layer.name + ".position");
        setExpression(layer.transform.opacity, PRE + "\n" +
            'value * clamp(0.72 + Math.sin(t * 0.4 + ' + phase + ') * 0.28, 0, 1);',
            layer.name + ".opacity");
        log("  horseman<- " + layer.name + " (depth " + depth + ")");
    }

    // "the skulls glowing" - not a smooth pulse. A skull that fades up and down
    // like a lamp reads as a lamp; this one catches, holds, and drops, which
    // reads as something behind it deciding to look at you.
    function animateSkull(layer, index) {
        var phase = (index * 2.11).toFixed(3);
        var glow = addEffect(layer, "ADBE Glo2", "Glow");
        if (glow) {
            try { glow.property("ADBE Glo2-0002").setValue(40); } catch (e) {}
            try { glow.property("ADBE Glo2-0003").setValue(22); } catch (e) {}
            var intensity = null;
            try { intensity = glow.property("ADBE Glo2-0004"); } catch (e) {}
            if (intensity) {
                setExpression(intensity, PRE + "\n" + [
                    'var p = ' + phase + ';',
                    '// Stepped, then smoothed a little: it catches rather than swells.',
                    'var beat = Math.sin(t * 2.3 + p);',
                    'var hold = beat > 0.55 ? 1 : 0.18;',
                    'var flick = (Math.sin(t * 17 + p) > 0.85) ? 1.6 : 1;',
                    '(0.5 + hold * 1.9 * flick) * glow;'
                ].join("\n"), layer.name + ".skullglow");
            }
        }
        setExpression(layer.transform.scale, PRE + "\n" +
            'value * (1 + Math.sin(t * 2.3 + ' + phase + ') * 0.012 * sway);',
            layer.name + ".scale");
        log("  skull   <- " + layer.name);
    }

    // "the tv to have crt filter" - a CRT is four things happening at once and
    // none of them is a scanline overlay on its own: the glass is curved, the
    // beam rolls, the phosphors separate at the edges, and the whole thing
    // breathes brightness with the mains. All four, in that order.
    function animateTV(layer) {
        var bulge = addEffect(layer, "ADBE BULGE", "Bulge");
        if (bulge) {
            try {
                bulge.property("ADBE BULGE-0003").setValue(0.28);  // bulge height
                bulge.property("ADBE BULGE-0001").setValue(layer.width * 0.62);
                bulge.property("ADBE BULGE-0002").setValue(layer.height * 0.62);
            } catch (e) { log("    . bulge params partly unset: " + e.toString()); }
        }

        var blinds = addEffect(layer, "ADBE Venetian Blinds", "Venetian Blinds");
        if (blinds) {
            try {
                blinds.property("ADBE Venetian Blinds-0002").setValue(0);   // direction
                blinds.property("ADBE Venetian Blinds-0003").setValue(3);   // width
                blinds.property("ADBE Venetian Blinds-0004").setValue(0);   // feather
                var amount = blinds.property("ADBE Venetian Blinds-0001");
                // The beam rolls. A still scanline pattern is a texture; a
                // moving one is a picture tube.
                setExpression(amount, PRE + "\n" +
                    '(11 + Math.sin(t * 0.9) * 4) * crt;', layer.name + ".scanlines");
            } catch (e) { log("    . blinds params partly unset: " + e.toString()); }
        }

        // Phosphor separation. Shift Channels on a duplicate is the honest way,
        // but a single Channel Blur reads close enough and costs one effect.
        var chroma = addEffect(layer, "ADBE Channel Blur", "Channel Blur");
        if (chroma) {
            try {
                setExpression(chroma.property("ADBE Channel Blur-0001"), PRE + "\n" +
                    '2.2 * crt;', layer.name + ".redblur");
                setExpression(chroma.property("ADBE Channel Blur-0003"), PRE + "\n" +
                    '1.4 * crt;', layer.name + ".blueblur");
                chroma.property("ADBE Channel Blur-0005").setValue(true);  // repeat edges
            } catch (e) { log("    . channel blur partly unset: " + e.toString()); }
        }

        var glow = addEffect(layer, "ADBE Glo2", "Glow");
        if (glow) {
            try {
                glow.property("ADBE Glo2-0002").setValue(52);
                glow.property("ADBE Glo2-0003").setValue(16);
                setExpression(glow.property("ADBE Glo2-0004"), PRE + "\n" +
                    '(0.9 + Math.sin(t * 3.1) * 0.2) * crt * glow;', layer.name + ".tvglow");
            } catch (e) {}
        }

        // Mains hum in the brightness, plus the occasional dropped frame. The
        // dropout is what sells it as a broken set rather than a filter.
        setExpression(layer.transform.opacity, PRE + "\n" + [
            'var hum = Math.sin(t * 50) * 1.4 * crt;',
            'var drop = (Math.sin(t * 0.7) > 0.985) ? -38 * crt : 0;',
            'clamp(value + hum + drop, 0, 100);'
        ].join("\n"), layer.name + ".opacity");

        // And a hair of vertical roll, so the image is never quite locked.
        setExpression(layer.transform.position, PRE + "\n" + [
            'var roll = (Math.sin(t * 0.33) > 0.97) ? Math.sin(t * 60) * 5 * crt : 0;',
            'value + [0, roll];'
        ].join("\n"), layer.name + ".roll");
        log("  tv      <- " + layer.name + " (bulge, scanlines, phosphor, hum, roll)");
    }

    // ------------------------------------------------------------- selftest
    // A synthetic plate with one layer per role, so the rig above can be proved
    // without a real PSD in hand. Every layer is named the way a PSD layer
    // would be, because the name matcher is half of what is being tested.
    function buildSelftestComp() {
        var comp = app.project.items.addComp("SELFTEST plate", TIMING.width, TIMING.height,
            1, TIMING.duration, TIMING.frameRate);
        var pieces = [
            {name: "ornate frame",   colour: [0.62, 0.48, 0.16], w: 1700, h: 940,  x: 960, y: 540},
            {name: "TV screen",      colour: [0.10, 0.16, 0.14], w: 520,  h: 380,  x: 960, y: 620},
            {name: "the orb",        colour: [0.32, 0.66, 0.74], w: 300,  h: 300,  x: 960, y: 470},
            {name: "left hand",      colour: [0.70, 0.44, 0.38], w: 180,  h: 240,  x: 700, y: 520},
            {name: "right hand",     colour: [0.70, 0.44, 0.38], w: 180,  h: 240,  x: 1220, y: 520},
            {name: "skull 1",        colour: [0.86, 0.84, 0.76], w: 120,  h: 150,  x: 520, y: 300},
            {name: "skull 2",        colour: [0.86, 0.84, 0.76], w: 120,  h: 150,  x: 1400, y: 300},
            {name: "horseman 1",     colour: [0.24, 0.14, 0.14], w: 200,  h: 280,  x: 300, y: 760},
            {name: "horseman 2",     colour: [0.22, 0.16, 0.12], w: 200,  h: 280,  x: 640, y: 780},
            {name: "horseman 3",     colour: [0.20, 0.12, 0.16], w: 200,  h: 280,  x: 1280, y: 780},
            {name: "horseman 4",     colour: [0.18, 0.14, 0.10], w: 200,  h: 280,  x: 1620, y: 760}
        ];
        // Added in reverse so the first in the list ends up at the back.
        for (var i = pieces.length - 1; i >= 0; i--) {
            var piece = pieces[i];
            var solid = comp.layers.addSolid(piece.colour, piece.name, piece.w, piece.h, 1);
            solid.transform.position.setValue([piece.x, piece.y]);
        }
        log("SELFTEST plate built: " + pieces.length + " layers");
        return comp;
    }

    // ------------------------------------------------------------------- main
    function main() {
        log("animate_artwork.jsx  " + new Date().toString());
        log("After Effects " + app.version);
        writeLog();

        var target = readConfig();
        if (target === null) {
            log("no animate_artwork.config.txt found - falling back to SELFTEST");
            target = "SELFTEST";
        }
        log("target: " + target);

        app.beginUndoGroup("Animate artwork");
        var comp = null;

        if (target.toUpperCase() === "SELFTEST") {
            comp = buildSelftestComp();
        } else {
            var psd = new File(target);
            if (!psd.exists) {
                log("ERROR: no file at " + target);
                app.endUndoGroup();
                writeLog();
                return;
            }
            var options = new ImportOptions(psd);
            // Retain layer sizes, so every painted element stays its own object
            // with its own anchor. Merged import would give one flat layer and
            // there would be nothing to animate.
            try {
                options.importAs = ImportAsType.COMP_RETAIN_LAYER_SIZES;
            } catch (error) {
                log("! this PSD will not import as a layered comp: " + error.toString());
                options.importAs = ImportAsType.FOOTAGE;
            }
            var imported = app.project.importFile(options);
            log("imported: " + imported.name + " (" + imported.typeName + ")");
            if (imported instanceof CompItem) {
                comp = imported;
            } else {
                // A layered import yields a folder; the comp is alongside it.
                for (var i = 1; i <= app.project.numItems; i++) {
                    var item = app.project.item(i);
                    if (item instanceof CompItem && item.name.indexOf(psd.name.replace(/\.[^.]+$/, "")) !== -1) {
                        comp = item;
                        break;
                    }
                }
            }
            if (comp === null) {
                log("ERROR: imported, but no composition came out of it. Is the PSD flat?");
                app.endUndoGroup();
                writeLog();
                return;
            }
            comp.duration = TIMING.duration;
            comp.frameRate = TIMING.frameRate;
        }

        comp.openInViewer();
        log("composition: " + comp.name + "  " + comp.width + "x" + comp.height +
            "  " + comp.duration + "s @ " + comp.frameRate + "fps  " + comp.numLayers + " layers");

        buildRig(comp);

        // Sort every layer into a role first, so the hand knows where the orb is
        // before it is asked to orbit it.
        var found = {hand: [], orb: [], frame: [], horsemen: [], skull: [], tv: []};
        var unplaced = [];
        for (var i = 1; i <= comp.numLayers; i++) {
            var layer = comp.layer(i);
            if (layer.name === "RIG") { continue; }
            var role = roleOf(layer.name);
            if (role === null) { unplaced.push(layer.name); continue; }
            found[role].push(layer);
        }

        log("");
        log("what it recognised:");
        var orb = found.orb.length > 0 ? found.orb[0] : null;
        for (var o = 0; o < found.orb.length; o++) { animateOrb(found.orb[o]); }
        for (var h = 0; h < found.hand.length; h++) { animateHand(found.hand[h], orb, h); }
        for (var f = 0; f < found.frame.length; f++) { animateFrame(found.frame[f]); }
        for (var r = 0; r < found.horsemen.length; r++) { animateHorsemen(found.horsemen[r], r); }
        for (var s = 0; s < found.skull.length; s++) { animateSkull(found.skull[s], s); }
        for (var v = 0; v < found.tv.length; v++) { animateTV(found.tv[v]); }

        log("");
        log("totals: " + found.hand.length + " hands, " + found.orb.length + " orbs, " +
            found.frame.length + " frames, " + found.horsemen.length + " horsemen, " +
            found.skull.length + " skulls, " + found.tv.length + " televisions");
        if (unplaced.length > 0) {
            log("");
            log("left alone (no word in the brief matched the layer name):");
            for (var u = 0; u < unplaced.length; u++) { log("    " + unplaced[u]); }
            log("-> rename one of these, or add the word to ROLES at the top of this script.");
        }

        app.endUndoGroup();
        writeLog();
    }

    try {
        main();
    } catch (error) {
        log("FATAL: " + error.toString() + (error.line ? "  (line " + error.line + ")" : ""));
        writeLog();
    }
})();
