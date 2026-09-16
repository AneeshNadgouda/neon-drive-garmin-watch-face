# Background artwork

`reference-watch-face.png` is the user's original mockup and design reference.
`synthwave-background-source.png` is the clean, high-resolution project artwork
created with OpenAI's built-in image-generation tool. The 416-pixel runtime asset
is generated from it at `resources/drawables/background.png`. Run
`powershell -ExecutionPolicy Bypass -File art/generate-background.ps1` to rebuild
the runtime asset with its 5% top-centered zoom.

The source and generated project artwork are distributed under the repository's
MIT License.

Final image prompt:

> Use case: precise-object-edit. Asset type: square background artwork for a
> 416×416 round Garmin AMOLED watch face. Turn the supplied watch-face mockup
> into clean background artwork. Preserve the synthwave sunset, ocean horizon,
> neon grid road, palm silhouettes, and white 1980s wedge-shaped sports car.
> Remove every piece of interface content, the outer watch bezel, and the
> checkerboard. Extend the scene naturally underneath removed content. Reserve
> readable dark/low-detail areas for live overlays. Keep a crisp retro-futurist
> vaporwave pixel/CRT character. No text, digits, letters, icons, UI, bezel,
> checkerboard, transparency, or watermark.
