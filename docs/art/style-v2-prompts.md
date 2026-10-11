# Art prompts, style v2: bright and cartoony

Generated from [gen/manifest.py](gen/manifest.py) by `python3 docs/art/gen/prompts_doc.py`; edit the manifest, not this file.

**Why v2:** v1 gave jig almost no style direction, so "cozy salvage, wood and brass" turned into brown, dark, semi-realistic art that looks muddy on screen. v2 puts one shared cartoon style in front of every prompt, and every subject names its own bright colours instead of raw wood or old brass. Keys and output paths are unchanged, so existing wiring picks up the new art.

## Shared style (prepended to every sprite and icon)

> bright colourful cartoon mobile game art, cheerful and playful, chunky simple shapes with soft rounded edges, clean bold outlines in deep navy blue, smooth cel shading with one soft highlight, high saturation candy palette of sky blue, turquoise, sunny yellow, coral red, mint green, bubblegum pink and lavender, bright sunny daylight, light and airy, clean smooth surfaces with very little texture, not realistic, not gritty

| Theme | Added after the shared style |
|---|---|
| sprite | single game sprite, clear readable silhouette, no text, no letters |
| icon | mobile game UI icon, big bold shape that reads at small size, no text, no letters, no numbers |
| effect | bright cartoon game effect, soft and airy, simple clean shapes, vivid colour, no text |

## Plan

1. **Pilot** (pod, peg_r1_1, wind_fan, icon_scrap, bld_workshop): generate these five first and review them before spending on the rest.
2. **Everything else** in the tables below, then the edit-based variants.
3. **Region backgrounds** last, passing the pilot jobs as `--style-job` so the backdrops match the sprites.

## Region backgrounds (`jig background`, 1440x2560, painted)

Each description is sent as the shared background brief followed by the region line.

> Bright colourful cartoon mobile game background in a clean painted style: saturated candy colours, soft simple shapes, clean outlines on the near pieces, cheerful and light, never dark or muddy. Portrait layout. The middle of the image (roughly the central 85% of the width, from 10% to 80% of the height) is open sky with only soft pale gradients and a few faint clouds, low contrast, because game pieces sit on top of it; put detail at the side edges and the far distance. The bottom 15% is a fluffy rolling cloud sea in bright white with coloured shadows, filling the full width.

| Key | Region line |
|---|---|
| `bg_region_1` | Home Skies: a bright sunny morning sky in clear cyan fading to pale aqua near the bottom, puffy white cumulus clouds, tiny floating grassy islands with little trees and a waterfall at the far left and right edges, a few colourful kites and birds in the distance. |
| `bg_region_2` | Brasswork Reach: a warm sunset sky in peach, tangerine and pink, the shiny gold and copper towers, big gear wheels and pipes of an old floating sky-factory at the far left and right edges, little puffs of white steam, cheerful and inviting. |
| `bg_region_3` | Rimefall Shallows: a crisp bright winter sky in periwinkle and baby blue, floating ice shelves and snowy pastel ruins with icicles at the far left and right edges, soft sparkling snowflakes, glittering and magical. |
| `bg_region_4` | Stormglass Verge: a vivid electric sky in violet, magenta and teal, big swirling storm clouds at the far edges lit from inside with bright yellow lightning, floating glowing crystal shards in pink and cyan at the edges, exciting but playful, not scary. |

## Edge-to-edge strips (`jig background`, no shared background brief)

| Key | Size | Description |
|---|---|---|
| `airship_strip` | 1440x200 | Bright colourful cartoon mobile game art, clean bold deep-navy outlines, saturated candy colours. A flat, side-on view of the underside of a cheerful cartoon airship hull that fills the entire image from the left edge to the right edge and from top to bottom, with no sky showing: horizontal turquoise painted planks with a sunny yellow stripe along the middle, a row of small round gold-rimmed portholes, a small open cargo hatch in the exact centre, and a fringe of coral red, yellow and pink bunting triangles along the bottom edge. Even bright daylight. Seamless and evenly detailed across the width. |

## Run board

| Key | Size | Theme | Subject |
|---|---|---|---|
| `pod` | 48x48 | sprite | a small round salvage pod, a shiny sunny-yellow ball with a coral red band around its middle and two little gold rivets, perfectly round silhouette |
| `drop_marker` | 64x64 | sprite | a small shiny gold winch hook on a short coral red rope, with a soft yellow glow around it, front view |
| `slot_socket` | 192x192 | sprite | an empty round mounting ring painted turquoise with four small gold clamps, seen straight on, thin ring with a hollow open centre |
| `survivor_raft` | 112x112 | sprite | a tiny cartoon raft of bright yellow planks with a little white sail and a coral red flag, one happy stranded traveller in a turquoise coat standing on it waving both arms, side view facing right |
| `barge` | 200x200 | sprite | a small cartoon sky barge: a round open-topped boat hull painted sky blue with a white stripe, held up by two round coral red balloons on ropes, simple and plain, the hull fills the bottom half of the image with its open mouth facing up, balloons above, front view |
| `barge_fancier` | 200x200 | sprite | a cartoon sky barge: a round open-topped boat hull painted turquoise with a sunny yellow stripe and gold trim, held up by two striped pink and white balloons, a little pennant on top, the hull fills the bottom half of the image with its open mouth facing up, balloons above, front view |
| `barge_fanciest` | 200x200 | sprite | a fancy cartoon sky barge: a round open-topped boat hull painted royal purple with shiny gold trim and a gold star on its side, held up by three rainbow-striped balloons, bunting strung between them, the hull fills the bottom half of the image with its open mouth facing up, balloons above, front view |
| `pennant_cloudsilk` | 48x64 | sprite | a small plain triangular cloth pennant flag that is entirely one solid pale pink colour with no stripes and no other colours, on a short white pole with a gold ball on top |
| `pennant_brasswork` | 48x64 | sprite | a small plain triangular cloth pennant flag that is entirely one solid golden yellow colour with no stripes and no other colours, on a short white pole with a gold ball on top |
| `pennant_rimeglass` | 48x64 | sprite | a small plain triangular cloth pennant flag that is entirely one solid deep cobalt blue colour with no stripes and no other colours, on a short white pole with a gold ball on top |
| `pennant_stormglass` | 48x64 | sprite | a small plain triangular cloth pennant flag that is entirely one solid deep magenta purple colour with no stripes and no other colours, on a short white pole with a gold ball on top |

## Regions: pegs, hazards, emblems

| Key | Size | Theme | Subject |
|---|---|---|---|
| `peg_r1_1` | 56x56 | sprite | a small round floating rock in soft sand-yellow with a bright green tuft of grass on top, perfectly round silhouette |
| `peg_r1_2` | 56x56 | sprite | a small dense round cloud puff, white with soft pink and lavender shading, firm and bouncy looking, perfectly round silhouette |
| `peg_r1_3` | 56x56 | sprite | a small round carved stone disc in pale peach with a turquoise spiral painted on it, perfectly round silhouette |
| `peg_r2_1` | 56x56 | sprite | a small round cog gear in shiny polished gold seen straight on, a coral red dot in the middle, perfectly round silhouette |
| `peg_r2_2` | 56x56 | sprite | a small round domed rivet head in bright orange with a ring of gold bolts, perfectly round silhouette |
| `peg_r2_3` | 56x56 | sprite | a small round pipe flange in shiny copper-orange and turquoise, seen straight on, perfectly round silhouette |
| `peg_r3_1` | 56x56 | sprite | a small round pale lilac rock topped with fluffy white snow, perfectly round silhouette |
| `peg_r3_2` | 56x56 | sprite | a small round carved stone disc in light periwinkle with tiny white icicles around its rim, perfectly round silhouette |
| `peg_r3_3` | 56x56 | sprite | a small round bushy evergreen shrub ball in bright teal-green, dusted with white snow on top, like a tiny snowy pine bush seen from the side, perfectly round silhouette |
| `peg_r4_1` | 56x56 | sprite | a small round stone in deep periwinkle blue with glowing pink veins, perfectly round silhouette |
| `peg_r4_2` | 56x56 | sprite | a small round glossy gem-like lump of magenta glass with a bright white highlight, perfectly round silhouette |
| `peg_r4_3` | 56x56 | sprite | a small round stone in teal with a glowing yellow crack running across it, perfectly round silhouette |
| `peg_ice` | 56x56 | sprite | a small round ball of clear glossy cyan ice with a big white shine, a frozen sticky lump with a cartoon frost rim, perfectly round silhouette |
| `peg_storm` | 56x56 | sprite | a small round grumpy cartoon thundercloud in purple with a bright yellow zigzag lightning bolt crackling out of it, perfectly round silhouette |
| `emblem_r1` | 192x192 | icon | a round emblem badge showing a bright cyan sky with puffy white clouds and a tiny green floating island with a tree, thick shiny gold rim |
| `emblem_r2` | 192x192 | icon | a round emblem badge showing a peach and pink sunset sky with a big shiny gold gear and a little copper tower, thick shiny gold rim |
| `emblem_r3` | 192x192 | icon | a round emblem badge showing a periwinkle winter sky with a snowy ice shelf and big white snowflakes, thick shiny gold rim |
| `emblem_r4` | 192x192 | icon | a round emblem badge showing a violet and magenta sky with a fat purple cloud and a bright yellow lightning bolt, thick shiny gold rim |
| `emblem_locked` | 192x192 | icon | a round swirl of soft lavender-grey cloud with a chunky shiny gold padlock in the centre |
| `storm_swallow` | 112x112 | sprite | a small cartoon poof cloud in lavender and purple with yellow sparkles and stars |

## Gizmos and rarity frames

| Key | Size | Theme | Subject |
|---|---|---|---|
| `wind_fan` | 88x48 | sprite | a small cartoon fan with three sky-blue blades in a sunny yellow round housing on a little coral red stand, blowing to the right, side view facing right |
| `magnet_buoy` | 64x64 | sprite | a small round floating buoy in red and white stripes with a bright red horseshoe magnet on top with silver tips, round silhouette |
| `cargo_net` | 120x56 | sprite | a small bright orange rope net slung between two short turquoise posts, sagging in the middle like a hammock, front view |
| `crystal_prism` | 120x108 | sprite | a glowing triangular crystal prism in bright violet and pink with rainbow sparkles, sitting in a small gold cradle, translucent glassy facets |
| `lightning_jar` | 96x96 | sprite | a round glass jar with a coral red lid holding a bright crackling yellow ball of lightning, round silhouette |
| `chime_bell` | 80x76 | sprite | a small shiny golden bell hanging from a turquoise wooden yoke with a pink ribbon, front view |
| `splitter_vane` | 80x80 | sprite | a small mint green blade vane with a sharp upward-pointing tip on a sunny yellow pivot, front view |
| `gyro_damper` | 80x80 | sprite | a small spinning gyroscope with a turquoise wheel inside three gold rings, round silhouette |
| `piston_kicker` | 96x40 | sprite | a small cartoon piston in coral red on a sunny yellow block with a round white boxing-glove style pad on its tip, pointing to the right, side view facing right |
| `sleet_sail` | 80x56 | sprite | a small sail stretched on a frame like a kite, pale aqua with white snowflake patterns, on a lavender frame, front view |
| `gale_vent` | 88x64 | sprite | a small upward-facing vent in mint green with a gold grate on top, a curly white puff of air rising out of it, front view |
| `rarity_common` | 128x128 | icon | an empty square badge frame with rounded corners, plain cream white painted wood with a soft sky-blue inner edge, hollow transparent centre |
| `rarity_uncommon` | 128x128 | icon | an empty square badge frame with rounded corners, bright mint green with small gold rivets, hollow transparent centre |
| `rarity_rare` | 128x128 | icon | an empty square badge frame with rounded corners, royal violet with shiny gold trim and a pink gem at each corner, hollow transparent centre |
| `balloon_cluster` | 104x104 | sprite | a bunch of four round shiny cartoon balloons in coral red, sunny yellow, sky blue and pink, tied together with curly strings, round silhouette |
| `zap_arc` | 300x120 | sprite | a short horizontal crackling zigzag bolt of bright yellow and white lightning |
| `gale_puff` | 120x160 | sprite | a curly cartoon puff of white and pale aqua air rising upward with little swirls |

## Buildings and islets

| Key | Size | Theme | Subject |
|---|---|---|---|
| `bld_workshop` | 192x192 | sprite | a cute cartoon workshop cottage with a turquoise sawtooth roof, cream walls, a yellow door, a workbench out front and a little red chimney, a single building on a small bright green grassy floating island plot, three-quarter view |
| `bld_wind_still` | 192x192 | sprite | a tall cartoon windmill tower with bright rainbow cloth sails, white walls and shiny copper tanks and curly pipes at its base, a single building on a small bright green grassy floating island plot, three-quarter view |
| `bld_dock` | 192x192 | sprite | a cartoon airship dock: a small turquoise wooden pier on stilts with a red and white striped mooring mast and an orange wind sock, a single building on a small bright green grassy floating island plot, three-quarter view |
| `bld_balloonworks` | 192x192 | sprite | a cartoon tent workshop with a pink and white striped canvas roof, half-sewn colourful balloons floating above it and spools of bright ribbon, a single building on a small bright green grassy floating island plot, three-quarter view |
| `bld_observatory` | 192x192 | sprite | a small round cartoon observatory with white walls, a sky-blue dome with gold stars and a gold telescope pointing at the sky, a single building on a small bright green grassy floating island plot, three-quarter view |
| `bld_gardens` | 192x192 | sprite | cheerful little terraced vegetable gardens with bright red tomatoes, orange pumpkins and sunflowers, a round turquoise rain barrel and a yellow watering can, a single building on a small bright green grassy floating island plot, three-quarter view |
| `bld_smeltery` | 192x192 | sprite | a cute squat cartoon furnace house of coral red brick with a glowing orange furnace mouth, a tall chimney puffing a white cloud and shiny gold ingots stacked out front, a single building on a small bright green grassy floating island plot, three-quarter view |
| `bld_lens_array` | 192x192 | sprite | a frame of big round glass lenses with gold rims on a turquoise scaffold, focusing bright beams of sunny light, colourful lanterns hanging around it, a single building on a small bright green grassy floating island plot, three-quarter view |
| `bld_foundry_annex` | 192x192 | sprite | a cartoon factory building with shiny gold-plated walls, a teal roof, round porthole windows glowing orange and curly copper pipes, a single building on a small bright green grassy floating island plot, three-quarter view |
| `islet_lantern_ruined` | 384x384 | sprite | a small floating island of pale rock and faded green grass with a few wobbly unlit lantern posts and a snapped rope bridge dangling off its edge, sleepy and a little lonely but still cute, soft pastel colours |
| `islet_lantern_restored` | 384x384 | sprite | a small floating island of pale rock and bright green grass strung with lots of glowing yellow, pink and turquoise lanterns on posts, a mended rope bridge leading off its edge, festive and welcoming |
| `islet_foundry_ruined` | 384x384 | sprite | a small floating island of pale rock with cold unlit gold-and-teal chimney stacks, tangled pipes and a broken balloon line, sleepy and quiet but still cute, soft pastel colours |
| `islet_foundry_restored` | 384x384 | sprite | a small floating island of pale rock with shiny gold-and-teal chimney stacks puffing fluffy white clouds, glowing orange windows and a mended balloon line with a red balloon, busy and cheerful |
| `construction` | 192x192 | sprite | cartoon scaffolding of turquoise poles with orange ropes, a yellow ladder, a striped orange and white safety cone and a little pink tarp, nothing else |

## Icons

| Key | Size | Theme | Subject |
|---|---|---|---|
| `icon_scrap` | 96x96 | icon | a small cheerful pile of salvage: a gold gear, a silver bolt, a sky-blue spring and a coral red plank |
| `icon_cloudsilk` | 96x96 | icon | a neat folded bolt of shimmering fabric in white, pink and lavender with a pearly rainbow sheen |
| `icon_brasswork` | 96x96 | icon | a bundle of shiny gold pipe fittings and a cog tied with a red ribbon |
| `icon_rimeglass` | 96x96 | icon | a bright icy cyan crystal shard with white frosty edges and sparkles |
| `icon_stormglass` | 96x96 | icon | a magenta and violet crystal shard with a tiny bright yellow lightning bolt glowing inside |
| `icon_crystals` | 96x96 | icon | a cluster of bright glowing pink and violet gems with sparkles, precious and special |
| `icon_parts` | 96x96 | icon | a tidy stack of shiny machine parts: a silver gear, a sky-blue spring and a gold hinge |
| `icon_provisions` | 96x96 | icon | a small wicker basket with a loaf of bread, red apples and a turquoise water bottle |
| `icon_fuel` | 96x96 | icon | a small glass canister full of swirling bright sky-blue wind with a gold cap and a lightning-bolt shaped swirl |
| `icon_ballast` | 96x96 | icon | a small round canvas sandbag in sky blue tied with a red string, crackling with little yellow sparks |
| `icon_wind_charm` | 96x96 | icon | a little hanging wind charm of turquoise and pink glass beads and white feathers on a string |
| `icon_storm_oil` | 96x96 | icon | a small round corked bottle of glowing violet liquid with a yellow lightning bolt label shape |
| `boon_barge_bounty` | 128x128 | icon | a small sky-blue barge boat overflowing with shiny gold coins and gems |
| `boon_rich_seas` | 128x128 | icon | a fluffy white cloud with sparkling gold coins and pink gems nestled in it |
| `boon_spare_pods` | 128x128 | icon | two round sunny-yellow salvage pods with coral red bands, tied together with a pink ribbon bow |
| `boon_heavy_loot` | 128x128 | icon | a chunky bulging sack in coral red with a gold coin spilling out and a heavy gold weight tag |
| `boon_featherfall` | 128x128 | icon | a single soft feather in sky blue with pink and gold tips floating upward with little sparkles |
| `boon_second_wind` | 128x128 | icon | a swirling circle of bright mint green wind with a few leaves, a fresh renewal |
| `daily_crate` | 192x192 | icon | a closed wooden supply crate painted turquoise with sunny yellow edges, rope handles and a red balloon tied to it |
| `bonus_crate` | 192x192 | icon | a closed fancy treasure chest in royal purple with shiny gold corners, a big pink ribbon bow and two balloons tied to it |
| `ad_badge` | 64x64 | icon | a small round coral red badge with a white play triangle on it and a gold rim |
| `timer` | 64x64 | icon | a small hourglass with a turquoise frame and bright pink sand |
| `build_slot` | 96x96 | icon | an empty patch of bright green grass with a little wooden stake, a red flag and a yellow hammer |
| `level_pip` | 32x32 | icon | a small chunky bright yellow star with a white shine |

## UI

| Key | Size | Theme | Subject |
|---|---|---|---|
| `letter_panel` | 878x1024 | icon | a large blank letter sheet of warm buttery yellow paper filling most of the image, a soft peach shading toward its gently curled corners and a thin sky-blue border line, a solid opaque sheet with no holes, completely empty with no writing, flat front view |
| `boon_card` | 360x480 | icon | a blank tall upright card with rounded corners, a cream white face and a thick sky-blue border with a thin gold inner line, completely empty centre, front view |
| `ui_panel` | 512x512 | icon | a blank square UI panel with rounded corners: a thick sky-blue painted wooden frame with small gold corner caps around a solid opaque butter-yellow canvas face with a fine woven cloth texture and soft peach shading toward the frame, no objects or pictures on the face, flat front view, suitable for a nine-slice UI panel |
| `ui_button` | 384x112 | icon | a blank wide rounded pill-shaped cartoon game button in sunny yellow with a darker orange bottom edge and a glossy white highlight on top, empty face, flat front view |
| `seal_lantern` | 96x96 | icon | a round bright coral red wax seal stamped with a little lantern shape |
| `clasp_foundry` | 96x96 | icon | a small shiny gold book clasp with a cog shape and a turquoise gem |

## Variants (`jig edit` of the base image)

| Key | From | Instruction |
|---|---|---|
| `balloon_cluster_spent` | `balloon_cluster` | make the balloons deflated, saggy and wrinkled, hanging limp, colours a little paler |
| `lightning_jar_spent` | `lightning_jar` | make the jar empty: clear pale blue glass with no lightning inside, keep the red lid |
| `chime_bell_spent` | `chime_bell` | make the bell a paler faded yellow, hanging still, no shine |
| `cargo_net_spent` | `cargo_net` | make the net torn and hanging slack |
| `pod_split` | `pod` | make it a little smaller and paler with a cartoon crack running along one side |
| `piston_extended` | `piston_kicker` | extend the piston fully outward to the right |
| `daily_crate_open` | `daily_crate` | open the lid with bright golden light, coins and gems spilling out |
| `slot_socket_hover` | `slot_socket` | make the ring glow bright sunny yellow as if highlighted |

## Not in this batch

- **Cloud sea, drift band, gyro field, magnet ring, wind and sleet columns:** v1 showed `jig generate` can't make soft translucent overlays or white-on-white clouds. The cloud sea is now painted into the bottom of each region background; the rest stay Godot shader or particle work.
- **Crew portraits:** kept from v1; they already read well.
- **App icon:** full-bleed, so it needs `jig background`; do it after the region-1 backdrop sets the look.

## Wiring

- **Barges** moved from `game/assets/sprites/` (100 px) to `game/art/run/barge*.png` (200 px); `_barge_visual()` scales to the catch width.
- **Region backgrounds** are drawn by `Skyfield._build_background()` behind the board at 720x1280.
