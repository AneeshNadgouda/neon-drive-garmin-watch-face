# Contributing

Issues and pull requests are welcome.

1. Fork the repository and create a focused branch.
2. Do not commit developer keys, local editor settings, or generated `bin/`
   output.
3. Build for the Forerunner 265 with compiler warnings enabled.
4. Test awake, partial-update, and always-on display modes in the simulator.
5. If visual assets change, regenerate the corresponding committed files under
   `resources/drawables/` and describe the visual difference in the pull
   request.

Keep changes scoped and preserve the existing approved CRT visual language
unless the proposal intentionally introduces a documented design change.
