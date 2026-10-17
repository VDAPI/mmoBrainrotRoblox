# Roblox graphics research for a painterly, serious fantasy MMO (state as of Oct 2026)

Research date: 2026-10-16. Prices are approximate, so check the store page before you buy.
Mobile cost scale: **L** = low, **M** = medium, **H** = high, **VH** = avoid on mobile or gate it behind the quality level.
"Verify" marks items I could not confirm from a primary source.

## 0. New in 2025-2026 (the things that matter most)
| Item | Status (Oct 2026) | Why it matters for us | Source |
|---|---|---|---|
| **Custom terrain materials (up to 64), new terrain storage** | Early Access program since Jun 2026; Roblox showed it again at RDC (Sep 2026). Don't publish live games with it yet. | Replaces the 21-material limit, so you get real painterly biomes. Client terrain memory drops 40-60% and terrain loads 2x faster. | https://devforum.roblox.com/t/early-access-program-unlocking-massive-terrain-with-up-to-64-custom-materials/4703282 , https://www.moguravr.com/?p=317147 |
| RDC 2026: paths, projected decals, roads, UI blur, shadows and 2D particles | Announced Sep 11 2026, no rollout date | Roads and paths without part hacks; UI blur and glow for an MMO HUD | https://gamesbeat.com/roblox-dives-into-the-details-on-its-rdc-engine-updates-roblox-wallet-and-offline-play-press-briefing/ |
| **Emissive masks** (SurfaceAppearance, MaterialVariant, TerrainDetail) | Live in published games (Feb 2026) | Glowing runes, crystals, lava and windows without Neon parts. Renders at every quality level. Cost L. | https://devforum.roblox.com/t/on-hold-emissives/4034414 |
| **4K textures + texture streaming** | Live (Jan 2026) | Streaming automatically serves lower mips to weak devices. Use 1K-2K for a painterly look, since hand-painted textures don't need 4K. | https://devforum.roblox.com/t/studio-beta-4k-texture-rendering/4144950 |
| **Mesh streaming + cloud LODs** | Opt-in beta (spring 2026) | Roblox generates 3-4 LODs automatically. Needs StreamingEnabled plus MeshStreamingEnabled. No manual LOD yet. | https://www.creation.dev/learn/roblox-mesh-streaming-cloud-lod-optimization-guide |
| **SLIM** (Scalable Lightweight Interactive Models) | v1 shipped, client beta | Merges static models into a few meshes and textures with LODs, picked per device by "Harmony". Very useful for towns. | https://about.roblox.com/newsroom/2025/12/introducing-roblox-slim-scalable-lightweight-interactive-models |
| **Animation Graphs** | Full release Jul 15 2026 | Node-based blend trees and state machines (Blend1D/2D, Mask, Add) for combat and locomotion | https://devforum.roblox.com/t/full-release-animation-graphs-create-complex-character-motion-visually/4739840 |
| Adaptive animation, Character Controller library, ragdoll death | Shipped spring 2026 | Out-of-the-box player motion quality for MMO characters | https://devforum.roblox.com/t/creator-roadmap-2026-spring-update/4625473 |
| **UI Styling** (full release), StyleQuery | Shipped / rolling out | CSS-like style sheets, giving one theme across the whole MMO UI | https://devforum.roblox.com/t/full-release-stylequery-more-styling-features/4566519 |
| **UIShadow** | API exists in the docs | Native drop shadows for panels | https://create.roblox.com/docs/reference/engine/classes/UIShadow |
| Upgraded UIGradient (Radial/Conical, Repeat/Mirror) | Studio beta Sep 2 2026, can't be published yet | Radial vignettes and ornate frames | https://devforum.roblox.com/t/studio-beta-upgraded-ui-gradients/4846594 |
| **Studio built-in MCP server** | Shipped | Claude Code and other clients can read and edit the place, run Luau, playtest and take screenshots | https://create.roblox.com/docs/studio/mcp |
| Delayed to late 2026: enhanced voxel terrain, fluid dynamics; frustum streaming in mid 2026 | Roadmap | Don't plan around these | https://devforum.roblox.com/t/creator-roadmap-2026-spring-update/4625473 |

## 1. Lighting
| Item | What it is | Mobile cost | Price | Source |
|---|---|---|---|---|
| Lighting.Technology = **Future** | Per-pixel lighting with dynamic shadows from point, spot and surface lights. The current default. Low-end devices fall back to cheaper paths automatically. | M to H. Many shadow-casting local lights are the main cost; keep `Shadows=false` on most torches. | Free | https://create.roblox.com/docs/environment/lighting |
| **LightingStyle** Realistic / Soft | Realistic gives the most advanced shadows (ShadowSoftness works). Soft gives a flatter, softer look, which can suit a painterly style. Test both. | L to M | Free | same |
| **PrioritizeLightingQuality** | true keeps high-quality shadows close up at the expense of view distance on lower quality levels | Trade-off | Free | same |
| GlobalShadows, ShadowSoftness, EnvironmentDiffuse/SpecularScale | Sun shadows and ambient from the sky. For a WoW-like look, set EnvironmentSpecularScale low (about 0.2-0.4) so hand-painted textures don't get a plastic shine. | M | Free | same |
| Ambient / OutdoorAmbient / ColorShift_Top | Painterly trick: warm ColorShift_Top and cool blue OutdoorAmbient, so the shadows read colored rather than gray | L | Free | same |
| **Atmosphere** | Density, Offset, Color, Decay, Glare, Haze. Gives aerial perspective and depth layers. This is the single best "painterly" lever. | L | Free | https://create.roblox.com/docs/environment/atmosphere |
| **Clouds** (Terrain child) | Dynamic volumetric clouds: Cover, Density, Color. Animated. | M (cheaper at low quality levels) | Free | https://create.roblox.com/docs/environment/clouds |
| **Sky** | 6-face skybox, SunTextureId, MoonTextureId, CelestialBodiesShown. Use a hand-painted skybox (1024² per face) for a stylized look. | L | Free (or ~$5-15 skybox packs) | https://create.roblox.com/docs/environment/skybox |
| Post effects: **ColorCorrection, Bloom, SunRays, DepthOfField, Blur** | Screen-space post effects under Lighting or Camera. Painterly preset: Saturation +0.1-0.2, Contrast +0.05-0.1, TintColor warm. Bloom Intensity 0.3-0.6 with Threshold ~1.5-2, so only emissives glow. | ColorCorrection L; Bloom/SunRays M; **DepthOfField H, so turn it off on mobile**; Blur M | Free | https://create.roblox.com/docs/environment/post-processing-effects |
| **ColorGradingEffect** | Picks a tonemapper preset (e.g. Retro = the pre-2019 look). Test the presets for a less filmic, more saturated look. | L | Free | https://create.roblox.com/docs/reference/engine/classes/ColorGradingEffect |
| Lighting presets | Community "realistic/stylized lighting" models in the Creator Store. Use them as a starting point only, since many over-use DoF and Bloom. | — | Free | Creator Store search "lighting preset"; tutorial: https://create.roblox.com/docs/tutorials/use-case-tutorials/lighting/enhance-outdoor-environments |

**Best practice:** keep one "Lighting profile" module per zone (forest, swamp, dungeon) and tween properties when the player moves between zones. On the client, read `UserSettings().GameSettings.SavedQualityLevel` and disable DoF, SunRays and extra shadow lights below level ~5.

## 2. Terrain
| Item | What it is | Mobile cost | Price | Source |
|---|---|---|---|---|
| Smooth voxel terrain | 23 built-in materials (21 editable). Rendered from a texture atlas, about 4K on mobile, which is why the count was capped. | M (L with streaming) | Free | https://devforum.roblox.com/t/infinite-custom-terrain-materials/3667533 |
| **MaterialService / MaterialVariant** | Override any material (parts *and* terrain) with your own Color, Normal, Roughness and Metalness maps, plus a **TerrainDetail** for separate top, side and bottom textures. Painterly approach: hand-painted color map, flat normal, roughness ~0.8-1. | L to M (atlas) | Free | https://create.roblox.com/docs/parts/materials |
| Custom terrain materials (64) | See section 0. The future path for biomes. Early Access only for now. | Lower memory than today | Free | link in section 0 |
| **Decoration grass** (Terrain.Decoration) | Animated grass on the Grass material, swaying with Workspace wind (GlobalWind). Not scriptable. Roblox plans to replace it with a broader decoration system. | M. It's distance-limited and quality-scaled. | Free | https://devforum.roblox.com/t/feedback-on-terraindecoration/4740329 , https://devforum.roblox.com/t/breeze-into-wind-beta/2400083 |
| Foliage meshes | Stylized bushes and flowers as MeshParts with alpha-cutout textures, scattered with Brushtool | M to H (overdraw from transparency). Keep counts low and stream them. | Free | Brushtool: Creator Store |
| Terrain plugins | **Terrain Studio v2** (generate, biome paint, rivers, erosion, caves, foliage scatter; Jul 2026) | — | Creator Store, price not stated | https://devforum.roblox.com/t/plugin-terrain-studio-v2-generate-paint-and-finish-terrain/4728181 |
| | **TerrainSuite** biome generator | — | Free | https://devforum.roblox.com/t/plugin-biome-terrain-generator-%E2%80%94-terrainsuite-free-map-style-regions/4754065 |
| | Built-in Terrain Editor (Generate, Import heightmap and colormap, Sculpt, Paint) | — | Free | https://devforum.roblox.com/t/update-to-our-terrain-tools/2290622 |
| **PBR SurfaceAppearance** | Per-MeshPart Color, Normal, Metalness and Roughness maps, plus emissive. For a painterly look, bake lighting and AO into the Color map with a soft normal map, the classic WoW-style approach. Up to 4K, but 1K is enough. | M (texture memory, streamed) | Free | https://create.roblox.com/docs/art/modeling/texture-specifications |

## 3. Meshes, LOD, streaming
| Item | What it is | Mobile cost | Price | Source |
|---|---|---|---|---|
| **StreamingEnabled** (instance streaming) | The client only holds nearby parts. Set StreamingTargetRadius, StreamingMinRadius and StreamOutBehavior=Opportunistic. **Required for an MMO world.** | Saves a lot of memory | Free | https://create.roblox.com/docs/workspace/streaming , https://devforum.roblox.com/t/updates-to-streaming-enabled/2391960 |
| **Model.ModelStreamingMode** (Atomic, Persistent, PersistentPerPlayer) and **Model.LevelOfDetail = StreamingMesh** | Distant models are drawn as a merged imposter mesh when streamed out, giving you a horizon of mountains and castles. | Lowers draw calls | Free | https://devforum.roblox.com/t/upgrades-to-model-streaming/2699921 |
| **MeshPart.RenderFidelity** (Automatic, Precise, Performance) | Automatic uses engine LODs by distance. Precise has no LOD, so use it only for heroes and bosses. | Automatic: L | Free | https://create.roblox.com/docs/reference/engine/classes/MeshPart |
| Mesh streaming / cloud LODs | Section 0. Opt-in beta. Budget 5-20k tris for hero assets and avoid anything over 100k. | Big win on mid-range Android | Free | creation.dev guide above |
| SLIM | Section 0 | Big win | Free | about.roblox.com link above |
| CollisionFidelity / CanQuery / CanTouch off on decor | Cuts physics and memory cost | L | Free | docs |
| Texture strategy | Shared trim sheets and atlases, so many meshes share one texture. Fewer unique SurfaceAppearances means fewer draw calls. Twin Atlas (World // Zero, Dragon Adventures) uses Color and Material properties instead of textures wherever possible. | — | — | https://gamesbeat.com/twin-atlas-is-among-the-studios-changing-what-roblox-games-look-like-exclusive-interview/ |

## 4. VFX
| Item | What it is | Mobile cost | Price | Source |
|---|---|---|---|---|
| **ParticleEmitter flipbooks** | Spritesheet animation (2x2, 4x4, 8x8; Loop, OneShot, PingPong, Random), with Squash, Drag and LockedToPart. Hand-painted flipbook fire and smoke gives a WoW look. | M. Overdraw is the cost, so keep Rate low and particles small. Roblox scales particle counts by quality level automatically. | Free | https://devforum.roblox.com/t/particles%E2%80%99-flipbook-release/2029388 |
| **Beam** | Textured ribbon between 2 attachments (curved, scrolling). Good for lightning, healing streams and portals. | L | Free | https://create.roblox.com/docs/effects/beams |
| **Trail** | Motion ribbon for sword swings and projectiles | L | Free | https://create.roblox.com/docs/effects/trails |
| Mesh VFX | Animated MeshParts (slash arcs, shockwaves, domes) with a scrolling Texture/Decal plus TweenService on size and transparency. The core of modern Roblox combat VFX. | L to M | Free | https://create.roblox.com/docs/effects |
| Highlight | Outline and fill for targeting and loot | M. Limit ~31 on screen. | Free | https://create.roblox.com/docs/reference/engine/classes/Highlight |
| Emissive masks + Bloom | Glowing gear without Neon | L | Free | section 0 |
| **Effect Designer Suite** (iGottic) | Plugin: emit controls, curve editor, Oklab color sequences, about 5,800 flipbook/texture presets. Open source. | — | **Free** (since Aug 2026) | https://devforum.roblox.com/t/effect-designer-suite-%E2%80%94-vfx-tooling-assets-and-more/4754553 |
| VFX Forge | Standalone or plugin VFX editor | — | itch.io (pay-what-you-want / check) | https://zilibobi.itch.io/vfx-forge |
| Paid VFX packs (BuiltByBit) | e.g. RPG & Combat Effects Pack: 24 effects for **$5.99**. "500+ Abilities & 1300+ VFX" packs cost ~$10-40. Most are anime style, so recolor and repaint for a serious fantasy look. | varies | $5-40 | https://builtbybit.com/resources/rpg-combat-effects-pack.110092/ , https://builtbybit.com/resources/500-abilities-1300-vfx-assets-2026.93693/ |

**Best practice:** keep a VFX pool (pre-instantiated, reused), and run all VFX on the client only (the server sends an event). Use a "VFX quality" setting: on mobile, Rate x0.5 and no secondary particles.

## 5. Animation
| Item | What it is | Mobile cost | Price | Source |
|---|---|---|---|---|
| Animation Editor (built-in) + Curve Editor, glTF/FBX import (Clip Editor importer, spring 2026) | Keyframe animation in Studio. Import from Blender or Maya is the pro path. | — | Free | https://create.roblox.com/docs/animation/editor |
| **Animation Graphs** | Section 0 | L (engine-side) | Free | link above |
| **IKControl** | Engine IK (Transform, LookAt, Position, Rotation): foot planting, look-at head, hands on weapons | L to M per character. Enable only close to the camera. | Free | https://create.roblox.com/docs/reference/engine/classes/IKControl |
| Procedural (Luau) | Spring-based head and spine bob, cape and tail physics, foot planting | L if LOD'd by distance | Free | https://devforum.roblox.com/t/procedural-animation/4014790 |
| **Moon Animator 2** (xSIXx) | The most popular 3rd-party animator: cutscenes, cameras, multi-rig, easing | — | **~$29.99 one-time** (Creator Store, USD pricing) | https://create.roblox.com/store/asset/4725618216/Moon-Animator-2 , https://thetoolstrunk.com/how-much-is-moon-animator/ |
| Blender + Roblox add-on | Rig and animate in Blender, then import | — | Free | https://create.roblox.com/docs/art/modeling/blender |
| Planned: Prompt-to-Animation (late 2026), motion-matching default avatar (RDC 2026) | — | — | — | roadmap / RDC links |

## 6. UI
| Item | What it is | Mobile cost | Price | Source |
|---|---|---|---|---|
| **9-slice** (ImageLabel.ScaleType=Slice, SliceCenter, SliceScale) | Ornate fantasy frames (parchment, stone, gold borders) that scale to any size. The key technique for a WoW-style UI. | L | Free | https://create.roblox.com/docs/ui/9-slice |
| **UIStroke** | Outline on text and frames. For readable text over the 3D world, use a dark 1-2px stroke at Transparency 0.3. | L | Free | https://create.roblox.com/docs/reference/engine/classes/UIStroke |
| **UIGradient** (plus radial/conical beta) | Gold metal and health bar gradients | L | Free | https://devforum.roblox.com/t/studio-beta-upgraded-ui-gradients/4846594 |
| UICorner, UIPadding, UIAspectRatioConstraint, UIScale, UIFlexLayout (flexbox) | Responsive layout from PC to phone. Always test on the 'Phone' device emulator. | L | Free | https://create.roblox.com/docs/ui |
| **UI Styling / StyleSheets, StyleQuery** | Centralized theme tokens | L | Free | https://devforum.roblox.com/t/full-release-stylequery-more-styling-features/4566519 |
| **UIShadow**, coming: UI blur and 2D particles (RDC 2026) | Native shadows and glow | L to M | Free | https://create.roblox.com/docs/reference/engine/classes/UIShadow |
| Fonts | Use Font.fromId or Creator Store fonts, e.g. a serif such as Cinzel-like or Merriweather from the built-in families, for a serious fantasy tone | L | Free | https://create.roblox.com/docs/reference/engine/datatypes/Font |
| ViewportFrame | 3D item and character previews in inventory | M. Each one is an extra render, so keep it to a few at once. | Free | https://create.roblox.com/docs/ui/viewport-frames |

## 7. Plugins and tools
| Tool | Purpose | Price | Source |
|---|---|---|---|
| **Studio MCP (built-in)** | Claude Code and other AI clients drive Studio: scripts, insert assets, run Luau, playtest, screen capture, generate_material, generate_mesh | Free | https://create.roblox.com/docs/studio/mcp |
| **Archimedes** (Archimedes Two) | Arches, circles, curved walls; useful for towers and bridges | Free per creation.dev (verify: the "Two" version was historically a small paid plugin) | https://www.creation.dev/de/tools/building-plugins , https://devforum.roblox.com/t/create-perfect-arcs/168753 |
| **F3X Building Tools** | Classic move, resize, paint and surface tools | Free | creation.dev link above |
| Brushtool, ResizeAlign, Stravant GapFill, Model Reflect, Tag Editor | Scatter foliage, align parts, fill gaps, mirror, manage tags | Free | creation.dev link above |
| Terrain Studio v2, TerrainSuite | Terrain generation and painting | Free / Creator Store | section 2 |
| Effect Designer Suite, VFX Forge | VFX authoring | Free | section 4 |
| Moon Animator 2 | Animation | ~$30 | section 5 |
| Rojo + VS Code / Luau LSP | File-based code, git | Free | https://rojo.space |
| Assistant (built-in), Material Generator (generate_material) | AI textures for MaterialVariants. Repaint the results for consistency. | Free | https://create.roblox.com/docs/studio/mcp |
| Paid asset marketplaces | BuiltByBit (VFX, UI kits, maps $5-60), Creator Store paid models (USD) | $ | https://builtbybit.com |

## 8. Visual references (Roblox RPG/MMO)
| Game | Why look at it | Link |
|---|---|---|
| **Deepwoken** | Dark, serious fantasy; atmosphere, fog and lighting moods; on PocketGamer's "best-looking" list | https://www.roblox.com/games/4111023553/Deepwoken |
| **Arcane Odyssey** | Stylized painterly islands, sky and ocean; magic VFX | https://www.roblox.com/games/3272915504/Arcane-Odyssey |
| **Vesteria** | Closest to a classic MMORPG (WoW/MapleStory) with a stylized look; caves with glow | https://www.roblox.com/games/2376885433/Vesteria |
| **World // Zero** (Twin Atlas) | Colorful hand-painted dungeon crawler, "among the best visuals on Roblox" | https://www.roblox.com/discover?Keyword=World%20Zero (verify id) |
| **Pilgrammed** | Stylized open-world RPG; consistent art direction | https://www.roblox.com/games/6735572261/ |
| **Dragon Adventures** (Twin Atlas) | Stylized fantasy biomes, terrain materials, creature shading | https://www.roblox.com/games/3475397644/Dragon-Adventures |
| **The Forge** | Fantasy RPG; armor and weapon glow | https://www.roblox.com/games/76558904092080/The-Forge |
| **Rune Slayer** | 2025 fantasy MMORPG (classes, open world): the closest genre match | https://www.sportskeeda.com/roblox-news/rune-slayer-a-beginner-s-guide (search "Rune Slayer" on roblox.com) |
| Hellreaver Arena, Mist | High-end lighting showcases (PocketGamer list) | https://www.pocketgamer.com/roblox/best-looking-games |

## 9. Painterly recipe (summary)
1. Use Future lighting with LightingStyle Realistic (test Soft too). Set ShadowSoftness ~0.3-0.5, EnvironmentSpecularScale low, warm ColorShift_Top and cool OutdoorAmbient.
2. Atmosphere Density 0.3-0.4 with Haze 1-2, tinted per zone. Add Clouds and a hand-painted Sky.
3. Use ColorCorrection plus light Bloom. Keep DoF and SunRays to PC only.
4. Textures: hand-painted Color maps with baked AO, through MaterialVariants and terrain materials. Roughness high, metalness 0, and emissive masks for magic.
5. Use StreamingEnabled with Model LOD StreamingMesh for landmarks, RenderFidelity Automatic, and SLIM or mesh streaming once stable.
6. VFX: flipbooks plus mesh VFX, client-side, pooled, with quality scaling.
7. UI: 9-slice ornate frames, UIStroke, a serif font, and StyleSheets.
