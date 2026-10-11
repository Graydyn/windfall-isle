"""Generation manifest, style v2 (2026-10-09): bright, colourful, cartoony.

v1 (2026-10-07) gave jig almost no style guidance beyond "cozy, warm,
salvaged wood and brass", and the batch came back brown, dark and muddy.
v2 pins a bright cartoon style in every theme string and rewrites each
subject to name its colours, so nothing defaults to raw wood and old brass.

One entry per asset: key -> (out path, canvas [w, h] at 2x, subject, theme, spec).
Run one entry with `python3 docs/art/gen/run.py <key>`; results append to
docs/art/gen/log.jsonl. `python3 docs/art/gen/prompts_doc.py` renders this
file to docs/art/style-v2-prompts.md for review.
"""

VERSION = 2

# Shared by every theme so the whole game reads as one style.
STYLE = (
    "bright colourful cartoon mobile game art, cheerful and playful, chunky simple shapes "
    "with soft rounded edges, clean bold outlines in deep navy blue, smooth cel shading with "
    "one soft highlight, high saturation candy palette of sky blue, turquoise, sunny yellow, "
    "coral red, mint green, bubblegum pink and lavender, bright sunny daylight, light and airy, "
    "clean smooth surfaces with very little texture, not realistic, not gritty"
)

THEMES = {
    "sprite": STYLE + ", single game sprite, clear readable silhouette, no text, no letters",
    "icon": STYLE + ", mobile game UI icon, big bold shape that reads at small size, no text, no letters, no numbers",
    "effect": "bright cartoon game effect, soft and airy, simple clean shapes, vivid colour, no text",
}

# Region background descriptions are composed by `jig background`, which has
# no theme flag, so the style goes into the description itself.
BG_STYLE = (
    "Bright colourful cartoon mobile game background in a clean painted style: saturated candy "
    "colours, soft simple shapes, clean outlines on the near pieces, cheerful and light, never "
    "dark or muddy. Portrait layout. The middle of the image (roughly the central 85% of the "
    "width, from 10% to 80% of the height) is open sky with only soft pale gradients and a few "
    "faint clouds, low contrast, because game pieces sit on top of it; put detail at the side "
    "edges and the far distance. The bottom 15% is a fluffy rolling cloud sea in bright white "
    "with coloured shadows, filling the full width."
)

SPECS = {
    "sprite": {"style": "painted", "background": None, "anchor": "center", "alpha_threshold": 128, "palette": None, "margin": 2},
    "bottom": {"style": "painted", "background": None, "anchor": "bottom_center", "alpha_threshold": 128, "palette": None, "margin": 2},
    "effect": {"style": "painted", "background": None, "anchor": "center", "alpha_threshold": 8, "palette": None, "margin": 2},
}

# key: (out, [w, h], subject, theme, spec)
A = {}


def add(key, out, size, subject, theme="sprite", spec="sprite"):
    A[key] = (out, size, subject, theme, spec)


R = "game/art/run/"
G = "game/art/regions/"
Z = "game/art/gizmos/"
I = "game/art/icons/"
B = "game/art/buildings/"
C = "game/art/crew/"
U = "game/art/ui/"

# ---------------------------------------------------------------- 1. run board
add("pod", R + "pod.png", [48, 48], "a small round salvage pod, a shiny sunny-yellow ball with a coral red band around its middle and two little gold rivets, perfectly round silhouette")
add("drop_marker", R + "drop_marker.png", [64, 64], "a small shiny gold winch hook on a short coral red rope, with a soft yellow glow around it, front view")
# airship_strip is a STRIPS entry (jig background) below.
add("slot_socket", R + "slot_socket.png", [192, 192], "an empty round mounting ring painted turquoise with four small gold clamps, seen straight on, thin ring with a hollow open centre")
add("survivor_raft", R + "survivor_raft.png", [112, 112], "a tiny cartoon raft of bright yellow planks with a little white sail and a coral red flag, one happy stranded traveller in a turquoise coat standing on it waving both arms, side view facing right")
for tier, s in [
    ("", "a small cartoon sky barge: a round open-topped boat hull painted sky blue with a white stripe, held up by two round coral red balloons on ropes, simple and plain"),
    ("_fancier", "a cartoon sky barge: a round open-topped boat hull painted turquoise with a sunny yellow stripe and gold trim, held up by two striped pink and white balloons, a little pennant on top"),
    ("_fanciest", "a fancy cartoon sky barge: a round open-topped boat hull painted royal purple with shiny gold trim and a gold star on its side, held up by three rainbow-striped balloons, bunting strung between them"),
]:
    add(f"barge{tier}", R + f"barge{tier}.png", [200, 200], s + ", the hull fills the bottom half of the image with its open mouth facing up, balloons above, front view", "sprite", "bottom")

# ---------------------------------------------------------------- 2. regions
for n, s in enumerate([
    "a small round floating rock in soft sand-yellow with a bright green tuft of grass on top",
    "a small dense round cloud puff, white with soft pink and lavender shading, firm and bouncy looking",
    "a small round carved stone disc in pale peach with a turquoise spiral painted on it",
], 1):
    add(f"peg_r1_{n}", G + f"peg_r1_{n}.png", [56, 56], s + ", perfectly round silhouette")
for n, s in enumerate([
    "a small round cog gear in shiny polished gold seen straight on, a coral red dot in the middle",
    "a small round domed rivet head in bright orange with a ring of gold bolts",
    "a small round pipe flange in shiny copper-orange and turquoise, seen straight on",
], 1):
    add(f"peg_r2_{n}", G + f"peg_r2_{n}.png", [56, 56], s + ", perfectly round silhouette")
for n, s in enumerate([
    "a small round pale lilac rock topped with fluffy white snow",
    "a small round carved stone disc in light periwinkle with tiny white icicles around its rim",
    "a small round bushy evergreen shrub ball in bright teal-green, dusted with white snow on top, like a tiny snowy pine bush seen from the side",
], 1):
    add(f"peg_r3_{n}", G + f"peg_r3_{n}.png", [56, 56], s + ", perfectly round silhouette")
for n, s in enumerate([
    "a small round stone in deep periwinkle blue with glowing pink veins",
    "a small round glossy gem-like lump of magenta glass with a bright white highlight",
    "a small round stone in teal with a glowing yellow crack running across it",
], 1):
    add(f"peg_r4_{n}", G + f"peg_r4_{n}.png", [56, 56], s + ", perfectly round silhouette")
add("peg_ice", G + "peg_ice.png", [56, 56], "a small round ball of clear glossy cyan ice with a big white shine, a frozen sticky lump with a cartoon frost rim, perfectly round silhouette")
add("peg_storm", G + "peg_storm.png", [56, 56], "a small round grumpy cartoon thundercloud in purple with a bright yellow zigzag lightning bolt crackling out of it, perfectly round silhouette")

BACKGROUNDS = {
    "bg_region_1": (G + "region_1_bg.png", "Home Skies: a bright sunny morning sky in clear cyan fading to pale aqua near the bottom, puffy white cumulus clouds, tiny floating grassy islands with little trees and a waterfall at the far left and right edges, a few colourful kites and birds in the distance."),
    "bg_region_2": (G + "region_2_bg.png", "Brasswork Reach: a warm sunset sky in peach, tangerine and pink, the shiny gold and copper towers, big gear wheels and pipes of an old floating sky-factory at the far left and right edges, little puffs of white steam, cheerful and inviting."),
    "bg_region_3": (G + "region_3_bg.png", "Rimefall Shallows: a crisp bright winter sky in periwinkle and baby blue, floating ice shelves and snowy pastel ruins with icicles at the far left and right edges, soft sparkling snowflakes, glittering and magical."),
    "bg_region_4": (G + "region_4_bg.png", "Stormglass Verge: a vivid electric sky in violet, magenta and teal, big swirling storm clouds at the far edges lit from inside with bright yellow lightning, floating glowing crystal shards in pink and cyan at the edges, exciting but playful, not scary."),
}
BG_SIZE = "1440x2560"

# Edge-to-edge strips: `jig generate` always centres a small subject (v1 and
# v2 both came back as a blob), so these go through `jig background` with
# their own description and no BG_STYLE. key: (out, size, description)
STRIPS = {
    "airship_strip": (R + "airship_strip.png", "1440x200", "Bright colourful cartoon mobile game art, clean bold deep-navy outlines, saturated candy colours. A flat, side-on view of the underside of a cheerful cartoon airship hull that fills the entire image from the left edge to the right edge and from top to bottom, with no sky showing: horizontal turquoise painted planks with a sunny yellow stripe along the middle, a row of small round gold-rimmed portholes, a small open cargo hatch in the exact centre, and a fringe of coral red, yellow and pink bunting triangles along the bottom edge. Even bright daylight. Seamless and evenly detailed across the width."),
}

# ---------------------------------------------------------------- 3. gizmos
add("wind_fan", Z + "wind_fan.png", [88, 48], "a small cartoon fan with three sky-blue blades in a sunny yellow round housing on a little coral red stand, blowing to the right, side view facing right")
add("magnet_buoy", Z + "magnet_buoy.png", [64, 64], "a small round floating buoy in red and white stripes with a bright red horseshoe magnet on top with silver tips, round silhouette")
add("cargo_net", Z + "cargo_net.png", [120, 56], "a small bright orange rope net slung between two short turquoise posts, sagging in the middle like a hammock, front view")
add("crystal_prism", Z + "crystal_prism.png", [120, 108], "a glowing triangular crystal prism in bright violet and pink with rainbow sparkles, sitting in a small gold cradle, translucent glassy facets")
add("lightning_jar", Z + "lightning_jar.png", [96, 96], "a round glass jar with a coral red lid holding a bright crackling yellow ball of lightning, round silhouette")
add("chime_bell", Z + "chime_bell.png", [80, 76], "a small shiny golden bell hanging from a turquoise wooden yoke with a pink ribbon, front view")
add("splitter_vane", Z + "splitter_vane.png", [80, 80], "a small mint green blade vane with a sharp upward-pointing tip on a sunny yellow pivot, front view")
add("gyro_damper", Z + "gyro_damper.png", [80, 80], "a small spinning gyroscope with a turquoise wheel inside three gold rings, round silhouette")
add("piston_kicker", Z + "piston_kicker.png", [96, 40], "a small cartoon piston in coral red on a sunny yellow block with a round white boxing-glove style pad on its tip, pointing to the right, side view facing right")
add("sleet_sail", Z + "sleet_sail.png", [80, 56], "a small sail stretched on a frame like a kite, pale aqua with white snowflake patterns, on a lavender frame, front view")
add("gale_vent", Z + "gale_vent.png", [88, 64], "a small upward-facing vent in mint green with a gold grate on top, a curly white puff of air rising out of it, front view")
add("rarity_common", Z + "rarity_common.png", [128, 128], "an empty square badge frame with rounded corners, plain cream white painted wood with a soft sky-blue inner edge, hollow transparent centre", "icon")
add("rarity_uncommon", Z + "rarity_uncommon.png", [128, 128], "an empty square badge frame with rounded corners, bright mint green with small gold rivets, hollow transparent centre", "icon")
add("rarity_rare", Z + "rarity_rare.png", [128, 128], "an empty square badge frame with rounded corners, royal violet with shiny gold trim and a pink gem at each corner, hollow transparent centre", "icon")

# ---------------------------------------------------------------- 4. island
for key, s in [
    ("workshop", "a cute cartoon workshop cottage with a turquoise sawtooth roof, cream walls, a yellow door, a workbench out front and a little red chimney"),
    ("wind_still", "a tall cartoon windmill tower with bright rainbow cloth sails, white walls and shiny copper tanks and curly pipes at its base"),
    ("dock", "a cartoon airship dock: a small turquoise wooden pier on stilts with a red and white striped mooring mast and an orange wind sock"),
    ("balloonworks", "a cartoon tent workshop with a pink and white striped canvas roof, half-sewn colourful balloons floating above it and spools of bright ribbon"),
    ("observatory", "a small round cartoon observatory with white walls, a sky-blue dome with gold stars and a gold telescope pointing at the sky"),
    ("gardens", "cheerful little terraced vegetable gardens with bright red tomatoes, orange pumpkins and sunflowers, a round turquoise rain barrel and a yellow watering can"),
    ("smeltery", "a cute squat cartoon furnace house of coral red brick with a glowing orange furnace mouth, a tall chimney puffing a white cloud and shiny gold ingots stacked out front"),
    ("lens_array", "a frame of big round glass lenses with gold rims on a turquoise scaffold, focusing bright beams of sunny light, colourful lanterns hanging around it"),
    ("foundry_annex", "a cartoon factory building with shiny gold-plated walls, a teal roof, round porthole windows glowing orange and curly copper pipes"),
]:
    add(f"bld_{key}", B + f"{key}.png", [192, 192], s + ", a single building on a small bright green grassy floating island plot, three-quarter view")
add("islet_lantern_ruined", B + "islet_lantern_shoal_ruined.png", [384, 384], "a small floating island of pale rock and faded green grass with a few wobbly unlit lantern posts and a snapped rope bridge dangling off its edge, sleepy and a little lonely but still cute, soft pastel colours")
add("islet_lantern_restored", B + "islet_lantern_shoal_restored.png", [384, 384], "a small floating island of pale rock and bright green grass strung with lots of glowing yellow, pink and turquoise lanterns on posts, a mended rope bridge leading off its edge, festive and welcoming")
add("islet_foundry_ruined", B + "islet_foundry_rock_ruined.png", [384, 384], "a small floating island of pale rock with cold unlit gold-and-teal chimney stacks, tangled pipes and a broken balloon line, sleepy and quiet but still cute, soft pastel colours")
add("islet_foundry_restored", B + "islet_foundry_rock_restored.png", [384, 384], "a small floating island of pale rock with shiny gold-and-teal chimney stacks puffing fluffy white clouds, glowing orange windows and a mended balloon line with a red balloon, busy and cheerful")
add("letter_panel", U + "letter_panel.png", [878, 1024], "a large blank letter sheet of warm buttery yellow paper filling most of the image, a soft peach shading toward its gently curled corners and a thin sky-blue border line, a solid opaque sheet with no holes, completely empty with no writing, flat front view", "icon")

# Crew portraits are kept from v1 (they already read well), so none here.

for n, s in [
    (1, "a round emblem badge showing a bright cyan sky with puffy white clouds and a tiny green floating island with a tree"),
    (2, "a round emblem badge showing a peach and pink sunset sky with a big shiny gold gear and a little copper tower"),
    (3, "a round emblem badge showing a periwinkle winter sky with a snowy ice shelf and big white snowflakes"),
    (4, "a round emblem badge showing a violet and magenta sky with a fat purple cloud and a bright yellow lightning bolt"),
]:
    add(f"emblem_r{n}", G + f"region_{n}_emblem.png", [192, 192], s + ", thick shiny gold rim", "icon")
add("emblem_locked", G + "region_locked_overlay.png", [192, 192], "a round swirl of soft lavender-grey cloud with a chunky shiny gold padlock in the centre", "icon")

# ---------------------------------------------------------------- 5. icons
for key, s in [
    ("scrap", "a small cheerful pile of salvage: a gold gear, a silver bolt, a sky-blue spring and a coral red plank"),
    ("cloudsilk", "a neat folded bolt of shimmering fabric in white, pink and lavender with a pearly rainbow sheen"),
    ("brasswork", "a bundle of shiny gold pipe fittings and a cog tied with a red ribbon"),
    ("rimeglass", "a bright icy cyan crystal shard with white frosty edges and sparkles"),
    ("stormglass", "a magenta and violet crystal shard with a tiny bright yellow lightning bolt glowing inside"),
    ("crystals", "a cluster of bright glowing pink and violet gems with sparkles, precious and special"),
    ("parts", "a tidy stack of shiny machine parts: a silver gear, a sky-blue spring and a gold hinge"),
    ("provisions", "a small wicker basket with a loaf of bread, red apples and a turquoise water bottle"),
    ("fuel", "a small glass canister full of swirling bright sky-blue wind with a gold cap and a lightning-bolt shaped swirl"),
]:
    add(f"icon_{key}", I + f"{key}.png", [96, 96], s, "icon")
for key, s in [
    ("ballast", "a small round canvas sandbag in sky blue tied with a red string, crackling with little yellow sparks"),
    ("wind_charm", "a little hanging wind charm of turquoise and pink glass beads and white feathers on a string"),
    ("storm_oil", "a small round corked bottle of glowing violet liquid with a yellow lightning bolt label shape"),
]:
    add(f"icon_{key}", I + f"{key}.png", [96, 96], s, "icon")
for key, s in [
    ("barge_bounty", "a small sky-blue barge boat overflowing with shiny gold coins and gems"),
    ("rich_seas", "a fluffy white cloud with sparkling gold coins and pink gems nestled in it"),
    ("spare_pods", "two round sunny-yellow salvage pods with coral red bands, tied together with a pink ribbon bow"),
    ("heavy_loot", "a chunky bulging sack in coral red with a gold coin spilling out and a heavy gold weight tag"),
    ("featherfall", "a single soft feather in sky blue with pink and gold tips floating upward with little sparkles"),
    ("second_wind", "a swirling circle of bright mint green wind with a few leaves, a fresh renewal"),
]:
    add(f"boon_{key}", I + f"boon_{key}.png", [128, 128], s, "icon")
add("boon_card", U + "boon_card.png", [360, 480], "a blank tall upright card with rounded corners, a cream white face and a thick sky-blue border with a thin gold inner line, completely empty centre, front view", "icon")
add("daily_crate", I + "daily_crate.png", [192, 192], "a closed wooden supply crate painted turquoise with sunny yellow edges, rope handles and a red balloon tied to it", "icon")
add("bonus_crate", I + "bonus_crate.png", [192, 192], "a closed fancy treasure chest in royal purple with shiny gold corners, a big pink ribbon bow and two balloons tied to it", "icon")
add("ad_badge", I + "ad_badge.png", [64, 64], "a small round coral red badge with a white play triangle on it and a gold rim", "icon")
add("timer", I + "timer.png", [64, 64], "a small hourglass with a turquoise frame and bright pink sand", "icon")
add("build_slot", I + "build_slot.png", [96, 96], "an empty patch of bright green grass with a little wooden stake, a red flag and a yellow hammer", "icon")
add("level_pip", I + "level_pip.png", [32, 32], "a small chunky bright yellow star with a white shine", "icon")

# ---------------------------------------------------------------- 7. theme
add("ui_panel", U + "panel.png", [512, 512], "a blank square UI panel with rounded corners: a thick sky-blue painted wooden frame with small gold corner caps around a solid opaque butter-yellow canvas face with a fine woven cloth texture and soft peach shading toward the frame, no objects or pictures on the face, flat front view, suitable for a nine-slice UI panel", "icon")
add("ui_button", U + "button.png", [384, 112], "a blank wide rounded pill-shaped cartoon game button in sunny yellow with a darker orange bottom edge and a glossy white highlight on top, empty face, flat front view", "icon")

# ---------------------------------------------------------------- nice-to-haves
# key: (out, source key, instruction)  -- run.py edits the base job's image
EDITS = {
    "balloon_cluster_spent": (Z + "balloon_cluster_spent.png", "balloon_cluster", "make the balloons deflated, saggy and wrinkled, hanging limp, colours a little paler"),
    "lightning_jar_spent": (Z + "lightning_jar_spent.png", "lightning_jar", "make the jar empty: clear pale blue glass with no lightning inside, keep the red lid"),
    "chime_bell_spent": (Z + "chime_bell_spent.png", "chime_bell", "make the bell a paler faded yellow, hanging still, no shine"),
    "cargo_net_spent": (Z + "cargo_net_spent.png", "cargo_net", "make the net torn and hanging slack"),
    "pod_split": (R + "pod_split.png", "pod", "make it a little smaller and paler with a cartoon crack running along one side"),
    "piston_extended": (Z + "piston_kicker_extended.png", "piston_kicker", "extend the piston fully outward to the right"),
    "daily_crate_open": (I + "daily_crate_open.png", "daily_crate", "open the lid with bright golden light, coins and gems spilling out"),
    "slot_socket_hover": (R + "slot_socket_hover.png", "slot_socket", "make the ring glow bright sunny yellow as if highlighted"),
}
# Balloon Cluster had no manifest entry in v1 (hand-picked). In v2 it is a
# normal entry so the spent edit can start from it.
add("balloon_cluster", Z + "balloon_cluster.png", [104, 104], "a bunch of four round shiny cartoon balloons in coral red, sunny yellow, sky blue and pink, tied together with curly strings, round silhouette")
add("zap_arc", Z + "zap_arc.png", [300, 120], "a short horizontal crackling zigzag bolt of bright yellow and white lightning")
add("gale_puff", Z + "gale_puff.png", [120, 160], "a curly cartoon puff of white and pale aqua air rising upward with little swirls")
add("storm_swallow", G + "storm_swallow.png", [112, 112], "a small cartoon poof cloud in lavender and purple with yellow sparkles and stars")
add("construction", B + "construction_overlay.png", [192, 192], "cartoon scaffolding of turquoise poles with orange ropes, a yellow ladder, a striped orange and white safety cone and a little pink tarp, nothing else")
# Pennants tell material barges apart, so each is ONE solid colour (v2 first
# pass came back rainbow-striped for all four).
for mat, s in [("cloudsilk", "pale pink"), ("brasswork", "golden yellow"), ("rimeglass", "deep cobalt blue"), ("stormglass", "deep magenta purple")]:
    add(f"pennant_{mat}", R + f"barge_pennant_{mat}.png", [48, 64], f"a small plain triangular cloth pennant flag that is entirely one solid {s} colour with no stripes and no other colours, on a short white pole with a gold ball on top")
add("seal_lantern", U + "seal_lantern.png", [96, 96], "a round bright coral red wax seal stamped with a little lantern shape", "icon")
add("clasp_foundry", U + "clasp_foundry.png", [96, 96], "a small shiny gold book clasp with a cog shape and a turquoise gem", "icon")

# Not regenerated, known jig limits from v1 (still true for `jig generate`):
# soft translucent overlays come back with binary alpha (job 9cb071b6) and
# white-on-white clouds come back blank (23dcc701), so the cloud sea, drift
# band and the field/column overlays stay Godot shader/particle work. The
# cloud sea is now painted into the bottom of each region background.
# App icon: full-bleed square; make it with `jig background` once the
# region-1 background has set the look.

BASES = [k for k in A if k not in ("zap_arc", "gale_puff", "storm_swallow", "construction", "seal_lantern", "clasp_foundry") and not k.startswith("pennant_")]
REQUIRED_ORDER = BASES
NICE_ORDER = [k for k in A if k not in BASES] + list(EDITS)
# Generated first and reviewed before the rest, so the style can be tuned
# cheaply: one board sprite, one peg, one gizmo, one icon, one building.
PILOT = ["pod", "peg_r1_1", "wind_fan", "icon_scrap", "bld_workshop"]
