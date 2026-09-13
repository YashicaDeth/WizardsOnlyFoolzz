/*
 * Wizards Only Foolz - "AS ABOVE, SO BELOW" teaser
 * ================================================
 *
 * Builds the whole trailer comp inside After Effects: imports the plates,
 * cuts them to the beat sheet, sets the typography, grades, grains and
 * letterboxes it, and drops comp markers at every beat so the edit can be
 * navigated without counting frames.
 *
 * This is the After Effects half of the trailer named in
 * DESIGN/THE_LONG_RUN.md - the piece that ships *before* the playable demo.
 *
 * Run it:  After Effects -> File -> Scripts -> Run Script File...
 *          -> art/trailer/build_trailer.jsx
 *
 * Every run builds a NEW comp with a version suffix, so running it twice
 * never clobbers hand edits - the old cut stays in the project.
 *
 * Everything the edit is made of lives in CONFIG and BEATS. Nothing below
 * "the machinery" needs touching to change the trailer.
 */

(function buildWizardsOnlyFoolzTrailer() {

// ------------------------------------------------------------------ config --

var CONFIG = {
  compName:  "WOF_TRAILER_AS_ABOVE_SO_BELOW",
  width:     1920,
  height:    1080,
  fps:       24,
  duration:  80.0,

  /* The plates come off a game where light is the resource, so they arrive
   * at a mean luminance of 4-20 out of 255 and are up to 98% pure black.
   * There is detail in there - the grade lifts it rather than crushing it.
   * Anything past gamma ~2.4 starts showing the shader's dither hatching. */
  gradeGamma:      2.10,
  gradeInputWhite: 0.90,
  vignette:        40,

  /* 2.39:1 letterbox. Set barHeight to 0 for a flat 16:9 cut. */
  barHeight: 139,

  /* The palette, taken off the constants the game already draws with. */
  bone:      [0.902, 0.831, 0.675],
  boneDim:   [0.616, 0.565, 0.459],
  rot:       [0.722, 0.094, 0.094],
  tar:       [0.031, 0.008, 0.008],

  /* Tried in order. The first one actually installed wins; if this version of
   * AE cannot enumerate fonts, the first is used and AE substitutes. */
  displayFonts: ["ShareTechMono-Regular", "CourierPrime", "OCRAStd",
                 "CourierNewPS-BoldMT", "Consolas"],
  titleFonts:   ["UnifrakturCook-Bold", "BebasNeue-Regular", "Impact",
                 "ArialNarrow-Bold", "Arial-BoldMT"]
};

/*
 * The beat sheet.
 *
 * Every entry is one of:
 *   plate   - a still from plates/, cut in with a slow push
 *   card    - typography over whatever is under it
 *   mark    - a brand mark from brand/
 *   black   - a hard black hold
 *   marker  - a comp marker, for navigating the edit
 *
 * Times are seconds. "push" is [startScale, endScale] as a MULTIPLIER on
 * whatever scale makes the plate cover the frame, so the numbers keep working
 * if the plates are ever recaptured at a higher resolution.
 */
var BEATS = [

  /* --- 0. Cold open. The premise, stated and then withdrawn. ------------- */
  { type:"marker", t:0.0,  label:"0 - COLD OPEN" },
  { type:"black",  tin:0.0,  tout:9.2 },
  { type:"card",   tin:1.0,  tout:3.4,  text:"THE WAR WAS TELEVISED.",          size:64, y:560 },
  { type:"card",   tin:3.6,  tout:6.0,  text:"THE WAR DID NOT HAPPEN.",         size:64, y:560 },
  { type:"card",   tin:6.2,  tout:8.9,  text:"THE GAME NEVER TELLS YOU WHICH.", size:52, y:560, color:"rot" },

  /* --- 1. The world. You did not arrive here, you were issued. ---------- */
  { type:"marker", t:9.2,  label:"1 - THE WORLD" },
  { type:"plate",  tin:9.2,  tout:16.4, file:"demo_world.png",  push:[1.00, 1.14] },
  { type:"card",   tin:10.4, tout:12.6, text:"YOU WERE NOT BORN.", size:58, y:880 },
  { type:"card",   tin:12.8, tout:15.6, text:"YOU WERE DECANTED.", size:58, y:880 },

  /* --- 2. Whose interface it is, and whose map. ------------------------- */
  { type:"marker", t:16.4, label:"2 - THE PRODUCT" },
  { type:"plate",  tin:16.4, tout:22.2, file:"demo_index.png",   push:[1.08, 1.00] },
  { type:"plate",  tin:22.2, tout:26.6, file:"demo_map.png",     push:[1.00, 1.12] },
  { type:"card",   tin:17.6, tout:21.6, text:"THE INTERFACE IS A CELLOUTZ PRODUCT.", size:46, y:880, color:"rot" },
  /* The plate says CELLOUTZ SURVEY in its own corner. The line only reads
   * what is already on screen. */
  { type:"card",   tin:23.2, tout:26.1, text:"EVEN THE MAP IS THEIRS.", size:52, y:880, color:"rot" },

  /* --- 3. The body. Fast, and getting faster. ---------------------------- */
  { type:"marker", t:26.6, label:"3 - THE BODY" },
  { type:"plate",  tin:26.6, tout:30.0, file:"demo_lockon.png",  push:[1.00, 1.09], hard:true },
  { type:"plate",  tin:30.0, tout:33.0, file:"demo_melee.png",   push:[1.06, 1.00], hard:true },
  { type:"plate",  tin:33.0, tout:35.9, file:"demo_clinch.png",  push:[1.00, 1.10], hard:true },
  { type:"plate",  tin:35.9, tout:42.2, file:"demo_gore.png",    push:[1.12, 1.00] },
  /* Deliberately held across the 30.0 cut - the line ties the two shots. */
  { type:"card",   tin:27.8, tout:30.8, text:"THERE ARE NO HEALTH BARS.", size:56, y:880 },
  { type:"card",   tin:37.0, tout:41.4, text:"ONLY ORGANS.",              size:76, y:880, color:"rot" },

  /* --- 4. The dark, and what it costs to see through it. ---------------- */
  { type:"marker", t:42.2, label:"4 - THE DARK" },
  { type:"plate",  tin:42.2, tout:48.4, file:"demo_downed.png",  push:[1.00, 1.12] },
  { type:"plate",  tin:48.4, tout:54.6, file:"demo_killcam.png", push:[1.10, 1.00] },
  { type:"card",   tin:43.4, tout:47.2, text:"LIGHT IS THE RESOURCE.",          size:58, y:880 },
  { type:"card",   tin:49.6, tout:53.8, text:"HOLDING IT UP COSTS YOU A HAND.", size:50, y:880 },

  /* --- 5. The axis. Both marks on black, mirrored: one rises, one drops. */
  { type:"marker", t:54.6, label:"5 - THE AXIS" },
  { type:"black",  tin:54.6, tout:66.8 },
  { type:"card",   tin:55.4, tout:60.6, text:"AS ABOVE", size:88, y:300 },
  { type:"mark",   tin:55.8, tout:60.6, file:"wof-wordmark-seal-2400.png", width:430, y:640, rise:-70 },
  { type:"card",   tin:61.0, tout:66.2, text:"SO BELOW", size:88, y:300, color:"rot" },
  { type:"mark",   tin:61.4, tout:66.2, file:"celloutz-mark-960.png", width:520, y:660, rise:70 },

  /* --- 6. Title. --------------------------------------------------------- */
  { type:"marker", t:66.8, label:"6 - TITLE" },
  { type:"black",  tin:66.8, tout:80.0 },
  { type:"mark",   tin:67.6, tout:80.0, file:"wof-wordmark-stacked-2400.png", width:1180, y:460, rise:0, hold:true },
  { type:"card",   tin:73.0, tout:80.0, text:"WIZARDSONLYFOOLZ.NET", size:34, y:840, color:"boneDim" },
  { type:"card",   tin:75.2, tout:80.0, text:"A CELLOUTZ PRODUCT",   size:22, y:892, color:"rot" }
];

// --------------------------------------------------------------- machinery --

function fail(msg) { alert("Trailer build stopped:\n\n" + msg); }

/* Where this script lives, so the asset folders resolve wherever the repo is. */
var scriptFile = new File($.fileName);
var root       = scriptFile.parent;
var platesDir  = new Folder(root.fsName + "/plates");
var brandDir   = new Folder(root.fsName + "/brand");

if (!platesDir.exists || !brandDir.exists) {
  fail("Expected plates/ and brand/ next to build_trailer.jsx.\nLooked in:\n" + root.fsName);
  return;
}

if (!app.project) app.newProject();
app.beginUndoGroup("Build WOF trailer");

try {

  /* ---- fonts ---- */
  function fontInstalled(psName) {
    try {
      if (app.fonts && app.fonts.allFonts) {
        var all = app.fonts.allFonts;
        for (var i = 0; i < all.length; i++) {
          if (all[i].postScriptName === psName) return true;
        }
        return false;
      }
    } catch (e) {}
    return null;                      /* this AE cannot tell us */
  }

  function pickFont(candidates) {
    for (var i = 0; i < candidates.length; i++) {
      var known = fontInstalled(candidates[i]);
      if (known === true) return candidates[i];
      if (known === null) return candidates[0];   /* cannot check; let AE substitute */
    }
    return candidates[candidates.length - 1];
  }

  var DISPLAY_FONT = pickFont(CONFIG.displayFonts);
  var TITLE_FONT   = pickFont(CONFIG.titleFonts);

  /* ---- project folders ---- */
  var binTrailer = app.project.items.addFolder("WOF TRAILER");
  var binPlates  = app.project.items.addFolder("plates");
  var binBrand   = app.project.items.addFolder("brand");
  binPlates.parentFolder = binTrailer;
  binBrand.parentFolder  = binTrailer;

  /* ---- import, once per file ---- */
  var imported = {};
  function importAsset(folder, filename, bin) {
    if (imported[filename]) return imported[filename];
    var f = new File(folder.fsName + "/" + filename);
    if (!f.exists) throw new Error("Missing asset: " + f.fsName);
    var io = new ImportOptions(f);
    io.importAs = ImportAsType.FOOTAGE;
    var item = app.project.importFile(io);
    item.parentFolder = bin;
    imported[filename] = item;
    return item;
  }

  /* ---- the comp. Versioned, so a re-run never eats a hand edit. ---- */
  var version = 1;
  for (var q = 1; q <= app.project.items.length; q++) {
    var it = app.project.items[q];
    if (it instanceof CompItem && it.name.indexOf(CONFIG.compName) === 0) version++;
  }
  var compName = CONFIG.compName + (version > 1 ? ("_v" + version) : "");

  var comp = app.project.items.addComp(compName, CONFIG.width, CONFIG.height,
                                       1.0, CONFIG.duration, CONFIG.fps);
  comp.parentFolder = binTrailer;
  comp.bgColor = [0, 0, 0];

  /* ---- keyframe easing ---- */
  function easeAll(prop, inInfluence, outInfluence) {
    var dims = 1;
    try { if (prop.value instanceof Array) dims = prop.value.length; } catch (e) {}
    var easeIn = [], easeOut = [];
    for (var d = 0; d < dims; d++) {
      easeIn.push(new KeyframeEase(0, inInfluence));
      easeOut.push(new KeyframeEase(0, outInfluence));
    }
    for (var k = 1; k <= prop.numKeys; k++) {
      try {
        prop.setInterpolationTypeAtKey(k, KeyframeInterpolationType.BEZIER,
                                          KeyframeInterpolationType.BEZIER);
        prop.setTemporalEaseAtKey(k, easeIn, easeOut);
      } catch (e) {}
    }
  }

  /* ---- fades ---- */
  function fade(layer, tIn, tOut, up, down) {
    var op = layer.property("Transform").property("Opacity");
    op.setValueAtTime(tIn, 0);
    op.setValueAtTime(tIn + up, 100);
    op.setValueAtTime(tOut - down, 100);
    op.setValueAtTime(tOut, 0);
    easeAll(op, 60, 60);
  }

  function colorOf(name) {
    if (name === "rot")     return CONFIG.rot;
    if (name === "boneDim") return CONFIG.boneDim;
    if (name === "tar")     return CONFIG.tar;
    return CONFIG.bone;
  }

  /* ---- a plate, cut in and pushed ---- */
  function addPlate(beat) {
    var item  = importAsset(platesDir, beat.file, binPlates);
    var layer = comp.layers.add(item);
    layer.name = beat.file.replace(/\.[^.]+$/, "");
    layer.startTime = beat.tin;
    layer.inPoint   = beat.tin;
    layer.outPoint  = beat.tout;

    /* Cover the frame whatever the plate resolution is. */
    var cover = Math.max(CONFIG.width / item.width, CONFIG.height / item.height) * 100;
    var a = beat.push ? beat.push[0] : 1.0;
    var b = beat.push ? beat.push[1] : 1.0;
    var s = layer.property("Transform").property("Scale");
    s.setValueAtTime(beat.tin,  [cover * a, cover * a]);
    s.setValueAtTime(beat.tout, [cover * b, cover * b]);
    easeAll(s, 35, 35);

    var edge = beat.hard ? 0.10 : 0.45;
    fade(layer, beat.tin, beat.tout, edge, edge);
    return layer;
  }

  /* ---- a typographic card ---- */
  function addCard(beat) {
    var layer = comp.layers.addText(beat.text);
    layer.name = "TXT " + beat.text.substring(0, 24);

    var td = layer.property("Source Text").value;
    td.resetCharStyle();
    td.font          = beat.title ? TITLE_FONT : DISPLAY_FONT;
    td.fontSize      = beat.size || 56;
    td.tracking      = (beat.tracking === undefined) ? 180 : beat.tracking;
    td.applyFill     = true;
    td.fillColor     = colorOf(beat.color);
    td.applyStroke   = false;
    td.justification = ParagraphJustification.CENTER_JUSTIFY;
    layer.property("Source Text").setValue(td);

    layer.property("Transform").property("Position")
         .setValue([CONFIG.width / 2, beat.y || 930]);

    /* Stamped in: a hair of scale, and a blur that resolves. */
    var s = layer.property("Transform").property("Scale");
    s.setValueAtTime(beat.tin,        [103, 103]);
    s.setValueAtTime(beat.tin + 0.45, [100, 100]);
    easeAll(s, 20, 80);

    var blur = layer.property("ADBE Effect Parade").addProperty("ADBE Gaussian Blur 2");
    var amt  = blur.property("Blurriness");
    amt.setValueAtTime(beat.tin,        9);
    amt.setValueAtTime(beat.tin + 0.30, 0);
    easeAll(amt, 10, 85);
    try { blur.property("Repeat Edge Pixels").setValue(true); } catch (e) {}

    fade(layer, beat.tin, beat.tout, 0.30, 0.45);
    return layer;
  }

  /* ---- a brand mark ---- */
  function addMark(beat) {
    var item  = importAsset(brandDir, beat.file, binBrand);
    var layer = comp.layers.add(item);
    layer.name = "MARK " + beat.file.replace(/\.[^.]+$/, "");
    layer.startTime = beat.tin;
    layer.inPoint   = beat.tin;
    layer.outPoint  = beat.tout;

    var target = (beat.width / item.width) * 100;
    var s = layer.property("Transform").property("Scale");
    if (beat.hold) {
      s.setValueAtTime(beat.tin,        [target * 1.04, target * 1.04]);
      s.setValueAtTime(beat.tin + 2.20, [target, target]);
      easeAll(s, 15, 85);
    } else {
      s.setValue([target, target]);
    }

    var p = layer.property("Transform").property("Position");
    var rise = beat.rise || 0;
    if (rise !== 0) {
      p.setValueAtTime(beat.tin,  [CONFIG.width / 2, beat.y - rise]);
      p.setValueAtTime(beat.tout, [CONFIG.width / 2, beat.y]);
      easeAll(p, 30, 40);
    } else {
      p.setValue([CONFIG.width / 2, beat.y]);
    }

    fade(layer, beat.tin, beat.tout, 0.60, 0.70);
    return layer;
  }

  /* ---- a black hold, so cards have something to sit on ---- */
  function addBlack(beat) {
    var layer = comp.layers.addSolid(CONFIG.tar, "BLACK",
                                     CONFIG.width, CONFIG.height, 1.0);
    layer.startTime = beat.tin;
    layer.inPoint   = beat.tin;
    layer.outPoint  = beat.tout;
    fade(layer, beat.tin, beat.tout, 0.25, 0.55);
    return layer;
  }

  /* ---- build, back to front so earlier beats end up on top ---- */
  var markers = [];
  for (var i = BEATS.length - 1; i >= 0; i--) {
    var beat = BEATS[i];
    if      (beat.type === "plate")  addPlate(beat);
    else if (beat.type === "card")   addCard(beat);
    else if (beat.type === "mark")   addMark(beat);
    else if (beat.type === "black")  addBlack(beat);
    else if (beat.type === "marker") markers.push(beat);
  }

  /* ---- finish: grade, grain, vignette, bars ---- */

  /* Grade. Lifts the shadows, because the plates are almost entirely shadow,
   * then pulls the white point in to put the contrast back. */
  var grade = comp.layers.addSolid([0, 0, 0], "GRADE", CONFIG.width, CONFIG.height, 1.0);
  grade.adjustmentLayer = true;
  grade.moveToBeginning();
  try {
    var lv = grade.property("ADBE Effect Parade").addProperty("ADBE Pro Levels2");
    lv.property("Gamma").setValue(CONFIG.gradeGamma);
    lv.property("Input White").setValue(CONFIG.gradeInputWhite);
  } catch (e) {}

  /* Grain, so 720p plates and clean type share one surface. */
  var grain = comp.layers.addSolid([0, 0, 0], "GRAIN", CONFIG.width, CONFIG.height, 1.0);
  grain.adjustmentLayer = true;
  grain.moveToBeginning();
  try {
    var nz = grain.property("ADBE Effect Parade").addProperty("ADBE Noise");
    nz.property("Amount of Noise").setValue(2.2);
    nz.property("Use Color Noise").setValue(false);
    nz.property("Clipping").setValue(true);
  } catch (e) {}

  /* Vignette: one feathered ellipse, subtracted. */
  var vig = comp.layers.addSolid([0, 0, 0], "VIGNETTE", CONFIG.width, CONFIG.height, 1.0);
  vig.moveToBeginning();
  try {
    var mask  = vig.property("ADBE Mask Parade").addProperty("ADBE Mask Atom");
    var shape = new Shape();
    shape.vertices    = [[-320, CONFIG.height / 2], [CONFIG.width / 2, -280],
                         [CONFIG.width + 320, CONFIG.height / 2],
                         [CONFIG.width / 2, CONFIG.height + 280]];
    shape.inTangents  = [[0, -430], [430, 0], [0, 430], [-430, 0]];
    shape.outTangents = [[0, 430], [-430, 0], [0, -430], [430, 0]];
    shape.closed = true;
    mask.property("ADBE Mask Shape").setValue(shape);
    mask.maskMode = MaskMode.SUBTRACT;
    mask.property("ADBE Mask Feather").setValue([300, 300]);
    vig.property("Transform").property("Opacity").setValue(CONFIG.vignette);
  } catch (e) {}

  /* Letterbox. */
  if (CONFIG.barHeight > 0) {
    var barTop = comp.layers.addSolid([0, 0, 0], "BAR TOP",
                                      CONFIG.width, CONFIG.barHeight, 1.0);
    barTop.property("Transform").property("Position")
          .setValue([CONFIG.width / 2, CONFIG.barHeight / 2]);
    barTop.moveToBeginning();

    var barBot = comp.layers.addSolid([0, 0, 0], "BAR BOTTOM",
                                      CONFIG.width, CONFIG.barHeight, 1.0);
    barBot.property("Transform").property("Position")
          .setValue([CONFIG.width / 2, CONFIG.height - CONFIG.barHeight / 2]);
    barBot.moveToBeginning();
  }

  /* ---- comp markers, so the beats are navigable ---- */
  for (var m = 0; m < markers.length; m++) {
    try {
      comp.markerProperty.setValueAtTime(markers[m].t,
        new MarkerValue(markers[m].label));
    } catch (e) {}
  }

  comp.openInViewer();

  alert("Trailer comp built.\n\n" +
        "Comp:    " + comp.name + "\n" +
        "Length:  " + CONFIG.duration + "s at " + CONFIG.fps + " fps\n" +
        "Display: " + DISPLAY_FONT + "\n" +
        "Title:   " + TITLE_FONT + "\n\n" +
        "Beats are on the comp markers. Edit BEATS at the top of\n" +
        "build_trailer.jsx and re-run for a new version of the cut.");

} catch (err) {
  fail(err.toString() + (err.line ? ("\nline " + err.line) : ""));
} finally {
  app.endUndoGroup();
}

})();
