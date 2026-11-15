# 3D garment assets

`generate_meshy_garment.py` runs the demo asset workflow:

1. Extract transparent front, side, and back ghost-mannequin views from one to five product photos.
2. Inject every retailer/brand-provided measurement into the reference-generation prompt.
3. Generate a PBR garment mesh with Meshy Multi-Image to 3D.
4. Apply one source-backed garment measurement as the authoritative real-world scale, or explicitly mark an automatic scale as estimated when the source publishes only body-size-chart measurements.
5. Convert the result to USDZ and validate it with `usdchecker`.
6. Optionally copy the finished USDZ into the app's synchronized model resources.

Install the one Python dependency and provide the API key through the environment:

```bash
python3 -m pip install requests
export MESHY_API_KEY="..."
```

Every run requires a dimensions manifest. Start from `source-dimensions.example.json`, record the product URL, brand, size, units, and every measurement supplied by the source. `meshy_scale` selects the garment measurement Meshy's Resize API can enforce exactly. Other measurements guide proportions but still require visual review. Do not estimate missing dimensions from a photograph or silently substitute a size chart intended for body measurements.

When a brand publishes only body-size-chart measurements, use `measurement_basis: "body_size_chart"` and `meshy_scale.mode: "auto"` only after that estimated-scale fallback is explicitly approved. The chart values are still sent to the image model, but they remain labeled as wearer measurements rather than garment dimensions.

Example:

```bash
python3 tools/3d/generate_meshy_garment.py product-reference.png \
  --slug smooth-spacer-quarter-zip \
  --description "Moonlit-green men's smooth spacer quarter-zip pullover; classic roomy fit, raglan shoulder seams, structured stand collar, quarter-length center zipper, long sleeves, ribbed cuffs and waistband, weighty modal-blend fabric" \
  --dimensions-file source-dimensions.json \
  --app-asset Shoppy/Resources/Models/garment-smooth-spacer-quarter-zip.usdz
```

Generated task metadata and intermediate views go under `tools/3d/generated/`. The API key is never written to disk.

## Fitting a garment onto the avatar

`fit_garment.py` takes a standalone garment (the USDZ or GLB from the workflow above) and the scanned avatar, and packages a dressed look for the app's 3D preview and AR.

```bash
/Applications/Blender.app/Contents/MacOS/Blender -b --python tools/3d/fit_garment.py -- \
  --garment Shoppy/Resources/Models/garment-smooth-spacer-quarter-zip.usdz \
  --look look-smooth-spacer-quarter-zip \
  --install
```

It needs Blender 3.6 or newer and the macOS USD tools (`usdcat`, `usdzip`, `usdchecker`). The steps:

1. Load both assets in one frame: Z up, front facing -Y, metres. The garment keeps the scale it arrives with. Pass `--dimensions-file` to check that scale against the manifest's `meshy_scale` measurement and correct it.
2. Place the garment: collar centred on the neck, yoke resting on the shoulders, collar below the chin.
3. Keep every sleeve straight. Each sleeve tilts as one line from the shoulder to run along the avatar's arm, and never bends at the elbow. The sleeve stands in for the arm it covers, so the scan's own arm beside it is hidden, however it is posed. Bare forearms are found by skin colour; above them the arm is the widest part of the body at that height. A cuff that would hang past the point where the bare arm stops, as at a pocket with a hand in it, is drawn up so the sleeve ends flush with that line. The sleeve is shortened by 5 cm at most, and `fit-report.json` records the amount as `cuff_raised_m`.
4. Bring the cloth out only where the body would stand well proud of it, always at the hem and cuffs, and around bare skin at the collar. The garment is never scaled up to fit.
5. Hide the scan faces the garment covers, so the clothes the avatar was scanned in cannot show through. `scan.usdz` itself is not modified.
6. Package `Look` with `Body` and `Garment` as separate prims (Y up, metres, soles on the origin), run `usdchecker --arkit`, and render the packaged file from the front, sides and back and at the collar, cuffs and hem.

Outputs go to `tools/3d/generated/fits/<look>/`: the USDZ, `fit-report.json`, `review/*.png`, and the intermediate `body.usda` and `garment.usda` layers. A run is skipped when the avatar, the garment, the manifest and the pipeline version are unchanged; `--force` rebuilds. `--install` copies the look into `Shoppy/Resources/Models/`, where a product names it in `previewAsset`.

Look at every review image before shipping a look. The result is a style preview: a geometric drape, not a cloth simulation, and it makes no claim about fit.
