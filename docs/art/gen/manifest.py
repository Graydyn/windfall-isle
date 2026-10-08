"""Generation manifest for the 2026-10-07 placeholder-graphics audit.

One entry per asset: key -> (out path, canvas [w, h] at 2x, subject, kind).
`kind` picks the theme and spec preset below. Run one entry with
`python3 docs/art/gen/run.py <key>`; results append to docs/art/gen/log.jsonl.
"""

THEMES = {
    "sprite": "cozy Ghibli-like sky-fantasy, painterly stylized 2D game sprite, soft warm lighting, handmade salvager materials of wood brass rope canvas and glass, clean readable silhouette, not pixel art, no text, no letters",
    "icon": "cozy sky-fantasy mobile game UI icon, painterly stylized 2D, bold readable silhouette at small size, soft warm lighting, not pixel art, no text, no letters, no numbers",
    "portrait": "cozy Ghibli-like sky-fantasy character portrait, painterly stylized 2D, head and shoulders, friendly expression, soft warm lighting, not pixel art, no text",
    "scene": "cozy Ghibli-like sky-fantasy, painterly stylized 2D background painting, soft atmospheric depth, low contrast and calm in the centre, not pixel art, no text, no characters",
    "effect": "soft translucent painterly 2D game effect, gentle and airy, not pixel art, no text",
}

# Spec presets. "fullbleed" keeps every pixel (chroma key on a colour that
# never appears) for backgrounds and the app icon.
SPECS = {
    "sprite": {"style": "painted", "background": None, "anchor": "center", "alpha_threshold": 128, "palette": None, "margin": 2},
    "bottom": {"style": "painted", "background": None, "anchor": "bottom_center", "alpha_threshold": 128, "palette": None, "margin": 2},
    "effect": {"style": "painted", "background": None, "anchor": "center", "alpha_threshold": 8, "palette": None, "margin": 2},
    "fullbleed": {"style": "painted", "background": {"type": "chroma_key", "color": [255, 0, 255], "tolerance": 0}, "anchor": "center", "alpha_threshold": 0, "palette": None, "margin": 0},
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
add("pod", R + "pod.png", [48, 48], "a small round salvage pod, a rivet-seamed brass and dark wood cargo sphere wrapped with a band of rope and a scrap of patched cream balloon silk, perfectly round silhouette, warm golden tones")
add("drop_marker", R + "drop_marker.png", [64, 64], "a small brass winch hook with a clamp hanging from a short rope, glowing softly as a release marker, viewed from the front")
add("airship_strip", R + "airship_strip.png", [1024, 142], "the underside of a large wooden salvage airship hull seen from below, a long horizontal strip of planks, brass trim, rope rigging and a cargo hatch along its belly, spanning the full width", "sprite", "bottom")
add("cloud_sea", R + "cloud_sea.png", [1024, 214], "a long low bank of rolling clouds strongly shaded in warm peach, lavender and dusty blue, deep coloured shadows between the puffs, a wide horizontal cloud ocean, outlined clearly")
add("slot_socket", R + "slot_socket.png", [192, 192], "an empty circular brass mounting ring with four small clamps and rivets, a docking socket seen straight on, hollow open centre, thin and subtle")
add("survivor_raft", R + "survivor_raft.png", [112, 112], "a tiny patched wooden raft with a little canvas sail and a small orange signal flag, one cheerful stranded traveller standing on it waving, side view facing right")

# ---------------------------------------------------------------- 2. regions
add("bg_region_1", G + "region_1_bg.png", [576, 1024], "portrait sky for Home Skies: soft daytime blue sky, gentle drifting cumulus clouds, a few tiny distant floating grassy islets near the top edges, warm sunlight, calm empty middle", "scene", "fullbleed")
add("bg_region_2", G + "region_2_bg.png", [576, 1024], "portrait sky for Brasswork Reach: amber hazy late-afternoon sky over the drifting ruins of an old brass sky-foundry, distant gear towers and pipes silhouetted at the edges, soot-gold haze, calm empty middle", "scene", "fullbleed")
add("bg_region_3", G + "region_3_bg.png", [576, 1024], "portrait sky for Rimefall Shallows: pale icy blue morning sky, frosted floating ice shelves and rime-covered ruins at the far edges, gentle snowfall, soft silver light, calm empty middle", "scene", "fullbleed")
add("bg_region_4", G + "region_4_bg.png", [576, 1024], "portrait sky for Stormglass Verge: dramatic but gentle indigo and violet storm sky, distant glowing storm clouds with soft lightning far away, shards of dark glass floating at the edges, calm empty middle", "scene", "fullbleed")

for n, s in enumerate([
    "a small round floating chunk of grey-brown rock with a tuft of moss on top",
    "a small dense round puff of cloud shaded in soft lavender and blue-grey with warm peach highlights, firm and solid looking",
    "a small round fragment of carved pale sky-ruin masonry with a worn spiral motif",
], 1):
    add(f"peg_r1_{n}", G + f"peg_r1_{n}.png", [56, 56], s + ", perfectly round silhouette")
for n, s in enumerate([
    "a small round brass cog gear seen straight on, weathered patina",
    "a small round domed brass rivet head with a ring of bolts",
    "a small round brass pipe joint flange seen straight on, copper and verdigris",
], 1):
    add(f"peg_r2_{n}", G + f"peg_r2_{n}.png", [56, 56], s + ", perfectly round silhouette")
for n, s in enumerate([
    "a small round grey rock dusted with white frost and rime crystals",
    "a small round fragment of carved ruin stone with tiny icicles",
    "a small round lump of packed snow with a frosty blue sheen",
], 1):
    add(f"peg_r3_{n}", G + f"peg_r3_{n}.png", [56, 56], s + ", perfectly round silhouette")
for n, s in enumerate([
    "a small round chunk of dark slate stone with faint violet veins",
    "a small round lump of fused smoky dark glass, glossy",
    "a small round scorched ruin fragment of dark stone with a faint violet glow in its cracks",
], 1):
    add(f"peg_r4_{n}", G + f"peg_r4_{n}.png", [56, 56], s + ", perfectly round silhouette")
add("peg_ice", G + "peg_ice.png", [56, 56], "a small round ball of slick clear blue glacial ice, glassy and wet, frozen solid, cold pale cyan, perfectly round silhouette")
add("peg_storm", G + "peg_storm.png", [56, 56], "a small round knot of swirling dark storm cloud with a bright crackling violet-white lightning core, perfectly round silhouette")
add("drift_band", G + "drift_band.png", [880, 320], "a wide horizontal band of streaming golden-brown haze and wind streaks flowing to the right, drifting soot motes and swept lines, very soft edges, mostly transparent", "effect", "effect")

# ---------------------------------------------------------------- 3. gizmos
add("wind_fan", Z + "wind_fan.png", [88, 48], "a small wooden-bladed fan in a brass housing on a little wooden base, blowing to the right, wind fan contraption, side view facing right")
add("magnet_buoy", Z + "magnet_buoy.png", [64, 64], "a small floating round buoy painted slate blue with a brass horseshoe magnet on top, round silhouette")
add("cargo_net", Z + "cargo_net.png", [120, 56], "a small rope cargo net slung between two short wooden poles, sagging in the middle like a hammock, front view")
add("crystal_prism", Z + "crystal_prism.png", [120, 108], "a glowing triangular violet aether crystal prism mounted in a small brass cradle, translucent glassy facets with soft inner light")
add("lightning_jar", Z + "lightning_jar.png", [96, 96], "a round glass jar with a brass lid and wire cage holding a crackling yellow ball of captured lightning, round silhouette")
add("chime_bell", Z + "chime_bell.png", [80, 76], "a small brass hanging bell on a short wooden yoke with a rope, warm golden shine, front view")
add("splitter_vane", Z + "splitter_vane.png", [80, 80], "a small mint-green painted metal vane with a sharp upward-pointing blade on a brass pivot, designed to split things in two, front view")
add("gyro_damper", Z + "gyro_damper.png", [80, 80], "a small spinning gyroscope inside a round brass cage of rings, steady and calm, round silhouette")
add("gyro_field", Z + "gyro_field.png", [560, 560], "a very faint soft circular golden aura disc, a glowing round stabilizing field, brighter thin rim and nearly transparent centre", "effect", "effect")
add("piston_kicker", Z + "piston_kicker.png", [96, 40], "a small brass piston on a wooden block with a padded striking head, pointing to the right, side view facing right")
add("sleet_sail", Z + "sleet_sail.png", [80, 56], "a small frosty pale-blue canvas sail stretched on a wooden frame like a kite, dusted with rime, front view")
add("gale_vent", Z + "gale_vent.png", [88, 64], "a small upward-facing brass bellows vent with a grated opening on top, a puff of air rising, front view")
add("rarity_common", Z + "rarity_common.png", [128, 128], "an empty square badge frame of plain warm wood with rounded corners, simple and modest, hollow transparent centre", "icon")
add("rarity_uncommon", Z + "rarity_uncommon.png", [128, 128], "an empty square badge frame of polished brass with rounded corners and small rivets, hollow transparent centre", "icon")
add("rarity_rare", Z + "rarity_rare.png", [128, 128], "an empty square badge frame of ornate brass inlaid with small violet aether crystals at the corners, hollow transparent centre", "icon")

# ---------------------------------------------------------------- 4. island
for key, s in [
    ("workshop", "a cozy wooden workshop hut with a sawtooth roof, a workbench out front, tools on the wall and a brass chimney"),
    ("wind_still", "a tall wooden wind still with a spinning cloth windmill on top and copper tanks and pipes collecting the wind"),
    ("dock", "a small wooden airship dock on stilts with a mooring mast, rope coils and a little wind sock"),
    ("balloonworks", "a canvas-roofed balloonworks shed with half-sewn colourful balloons and spools of silk rope"),
    ("observatory", "a small round stone observatory with a domed brass roof and a long brass telescope pointing at the sky"),
    ("gardens", "lush little terraced vegetable gardens with a round stone rain cistern and a watering can"),
    ("smeltery", "a squat brick smeltery with a glowing furnace mouth, a tall chimney and stacked metal ingots"),
    ("lens_array", "a frame of large brass-rimmed glass lenses on a wooden scaffold focusing warm golden light, lanterns hanging around it"),
    ("foundry_annex", "an old brass-plated foundry annex with banked glowing coals, iron doors and riveted pipes"),
]:
    add(f"bld_{key}", B + f"{key}.png", [192, 192], s + ", a single building on a small grassy floating plot of land, three-quarter view")
add("islet_lantern_ruined", B + "islet_lantern_shoal_ruined.png", [384, 384], "a small floating rock islet with broken dark unlit lantern posts and a snapped rope bridge dangling off its edge, overcast and forgotten")
add("islet_lantern_restored", B + "islet_lantern_shoal_restored.png", [384, 384], "a small floating rock islet strung with many warm glowing guide lanterns on posts, a mended rope bridge leading off its edge, cozy and welcoming")
add("islet_foundry_ruined", B + "islet_foundry_rock_ruined.png", [384, 384], "a small floating rock islet with cold dark brass furnace stacks, rusted pipes and a broken balloon line, abandoned")
add("islet_foundry_restored", B + "islet_foundry_rock_restored.png", [384, 384], "a small floating rock islet with brass furnace stacks glowing warmly, gentle smoke rising and a mended balloon line attached, alive again")
add("letter_panel", U + "letter_panel.png", [878, 1024], "a large blank sheet of aged warm tan parchment with softly curled torn edges and a few faint stains, completely empty with no writing, flat front view", "icon")

for key, s in [
    ("maren", "Maren, a focused middle-aged woman lens grinder with round brass spectacles pushed up on her head and a leather apron"),
    ("halvard", "Halvard, an old weathered foreman with a grey beard, soot-smudged cheeks and a brass-buttoned work coat"),
    ("odo", "Odo, a gentle stocky gardener with a straw hat, earth-stained hands and a sprig of herbs tucked behind his ear"),
    ("brisa", "Brisa, a lively young woman wind-still engineer with windswept short hair, flight goggles around her neck"),
    ("petch", "Petch, a wiry balloon rigger with a coil of rope over one shoulder and a patched silk scarf"),
    ("suno", "Suno, a calm rain-keeper with long dark braided hair and a raincoat beaded with water droplets"),
    ("immel", "Immel, an elderly tinkerer with wild white hair, a magnifying loupe and a mischievous smile"),
    ("reya", "Reya, a confident sailor smelter with a scar across her eyebrow, rolled sleeves and a grin"),
]:
    add(f"crew_{key}", C + f"{key}.png", [192, 192], s + ", facing the viewer", "portrait")

for n, s in [
    (1, "a round emblem medallion showing a sunny blue sky with fluffy clouds and a tiny floating grassy islet"),
    (2, "a round emblem medallion showing an amber hazy sky with brass gears and a distant foundry tower"),
    (3, "a round emblem medallion showing a pale icy sky with frosted ice shelves and falling snow"),
    (4, "a round emblem medallion showing an indigo storm sky with a soft lightning bolt and dark glass shards"),
]:
    add(f"emblem_r{n}", G + f"region_{n}_emblem.png", [192, 192], s + ", brass rim", "icon")
add("emblem_locked", G + "region_locked_overlay.png", [192, 192], "a round swirl of soft grey fog with a small brass padlock in the centre", "icon")

# ---------------------------------------------------------------- 5. icons
for key, s in [
    ("scrap", "a small pile of salvaged scrap: bent brass gears, bolts and a plank"),
    ("cloudsilk", "a neat folded bolt of shimmering woven cloud silk fabric with a lavender and sky-blue pearly sheen"),
    ("brasswork", "a bundle of salvaged brass fittings, a pipe elbow and a cog tied together"),
    ("rimeglass", "a frosted pale blue glass shard crystal with rime on its edges"),
    ("stormglass", "a dark violet glass shard with a tiny bolt of lightning trapped inside, glowing"),
    ("crystals", "a cluster of bright glowing violet aether crystals, premium and precious"),
    ("parts", "a tidy stack of worked machine parts: a gear, a spring and a hinge"),
    ("provisions", "a small wicker basket of bread, apples and a corked water bottle"),
    ("fuel", "a small glass canister full of swirling pale blue wind with a brass cap"),
]:
    add(f"icon_{key}", I + f"{key}.png", [96, 96], s, "icon")
for key, s in [
    ("ballast", "a small canvas sandbag of ballast crackling with a faint blue electric charge"),
    ("wind_charm", "a little hanging wind charm of glass beads and feathers on a string"),
    ("storm_oil", "a small corked bottle of glowing violet storm oil"),
]:
    add(f"icon_{key}", I + f"{key}.png", [96, 96], s, "icon")
for key, s in [
    ("barge_bounty", "a small sky barge overflowing with golden cargo"),
    ("rich_seas", "a fluffy cloud with sparkling coins and treasures nestled in it"),
    ("spare_pods", "two round salvage pods side by side with a little ribbon"),
    ("heavy_loot", "a heavy sack of loot with a brass weight tag"),
    ("featherfall", "a single soft feather in pale sky blue with golden tips floating upward"),
    ("second_wind", "a swirling gust of fresh green wind in a circle, renewal"),
]:
    add(f"boon_{key}", I + f"boon_{key}.png", [128, 128], s, "icon")
add("boon_card", U + "boon_card.png", [360, 480], "a blank tall upright card frame of warm tan parchment with an ornate brass border and rounded corners, completely empty centre, front view", "icon")
add("daily_crate", I + "daily_crate.png", [192, 192], "a closed wooden supply crate with rope handles and a balloon tied to it", "icon")
add("bonus_crate", I + "bonus_crate.png", [192, 192], "a closed fancy treasure crate with brass corners, a ribbon bow and two balloons tied to it", "icon")
add("ad_badge", I + "ad_badge.png", [64, 64], "a small brass spyglass badge with a play triangle shape on its lens", "icon")
add("timer", I + "timer.png", [64, 64], "a small brass and wood hourglass with golden sand", "icon")
add("build_slot", I + "build_slot.png", [96, 96], "an empty grassy building plot with a little wooden stake and a hammer", "icon")
add("level_pip", I + "level_pip.png", [32, 32], "a small round glowing golden star pip", "icon")

# ---------------------------------------------------------------- 6-7. app icon, theme
add("app_icon", "game/art/app_icon.png", [512, 512], "app icon: a small green home island floating above a soft cloud sea with a little salvage pod hanging under a balloon beside it, bright cheerful sky, square full-bleed composition", "scene", "fullbleed")
add("ui_panel", U + "panel.png", [512, 512], "a blank square panel of warm tan canvas stretched in a light wooden frame with brass corner caps, empty centre, flat front view, suitable for a nine-slice UI panel", "icon")
add("ui_button", U + "button.png", [384, 112], "a blank wide rounded wooden UI button with a thin brass rim, empty face, flat front view", "icon")

# ---------------------------------------------------------------- nice-to-haves (generated as edits of a base job where possible)
# key: (out, source key, instruction)  -- run.py edits the base job's image
EDITS = {
    "balloon_cluster_spent": (Z + "balloon_cluster_spent.png", "balloon_cluster", "make the balloons deflated, saggy and popped, hanging limp"),
    "lightning_jar_spent": (Z + "lightning_jar_spent.png", "lightning_jar", "make the jar empty and dark, no lightning inside"),
    "chime_bell_spent": (Z + "chime_bell_spent.png", "chime_bell", "make the bell dull and tarnished, hanging still"),
    "cargo_net_spent": (Z + "cargo_net_spent.png", "cargo_net", "make the net torn and hanging slack"),
    "pod_split": (R + "pod_split.png", "pod", "make it look lighter and cracked open along one seam"),
    "piston_extended": (Z + "piston_kicker_extended.png", "piston_kicker", "extend the piston fully outward to the right"),
    "daily_crate_open": (I + "daily_crate_open.png", "daily_crate", "open the lid with warm light and loot spilling out"),
    "slot_socket_hover": (R + "slot_socket_hover.png", "slot_socket", "make the ring glow warm gold as if highlighted"),
}
for key, s in [
    ("wind_column", "a tall narrow vertical column of soft pale blue wind streaks and tiny leaves flowing sideways"),
    ("sleet_column", "a tall narrow vertical column of slowly falling soft snowflakes and pale blue mist"),
]:
    add(key, Z + f"{key}.png", [180, 840], s + ", mostly transparent, soft edges", "effect", "effect")
add("magnet_ring", Z + "magnet_ring.png", [640, 640], "a very faint thin circular blue glowing ring, a magnetic field outline, nearly transparent centre", "effect", "effect")
add("zap_arc", Z + "zap_arc.png", [300, 120], "a short horizontal crackling yellow-white lightning arc")
add("gale_puff", Z + "gale_puff.png", [120, 160], "a soft rising upward puff of pale sky-blue air and swirls")
add("storm_swallow", G + "storm_swallow.png", [112, 112], "a small round burst puff of dark violet storm smoke with sparkles")
add("construction", B + "construction_overlay.png", [192, 192], "wooden scaffolding with ropes, a ladder and a small canvas tarp, nothing else")
for mat, s in [("cloudsilk", "pearl white"), ("brasswork", "brass gold"), ("rimeglass", "pale ice blue"), ("stormglass", "deep violet")]:
    add(f"pennant_{mat}", R + f"barge_pennant_{mat}.png", [48, 64], f"a small triangular cloth pennant flag on a short pole, {s} colour")
add("seal_lantern", U + "seal_lantern.png", [96, 96], "a round red wax seal stamped with a little lantern shape", "icon")
add("clasp_foundry", U + "clasp_foundry.png", [96, 96], "a small ornate brass book clasp with a cog motif", "icon")

# jig validates that all four corners are transparent, so full-bleed art
# (backgrounds, app icon) cannot come out of it (job 6c13fb88, 2026-10-07).
BLOCKED = {k for k in A if A[k][4] == "fullbleed"}
# Background removal yields binary alpha (job 9cb071b6), so soft translucent
# overlays belong to Godot shaders/particles instead.
# White-on-white clouds come back blank (job 23dcc701) and edge-to-edge
# bands come back as a centred blob (9d2decb6); the cloud sea is scene work.
BLOCKED |= {"cloud_sea", "drift_band", "gyro_field", "magnet_ring", "wind_column", "sleet_column"}

REQUIRED_ORDER = [k for k in A if k not in BLOCKED and not k.startswith(("wind_column", "sleet_column", "magnet_ring", "zap_arc", "gale_puff", "storm_swallow", "construction", "pennant_", "seal_", "clasp_"))]
NICE_ORDER = [k for k in A if k not in REQUIRED_ORDER and k not in BLOCKED] + list(EDITS)
