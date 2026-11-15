#!/usr/bin/env python3
"""Generate a source-dimensioned garment USDZ through Meshy's image workflow.

Requires MESHY_API_KEY and the requests package. The key is read only from the
environment. Intermediate task metadata and reference views are written under
tools/3d/generated, which is intentionally ignored by git. A dimensions
manifest from the retailer or brand is mandatory.
"""

import argparse
import base64
import json
import os
import shutil
import subprocess
import time
from pathlib import Path

import requests


API_ROOT = "https://api.meshy.ai/openapi/v1"
FINAL_STATUSES = {"SUCCEEDED", "FAILED", "CANCELED"}


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("source_images", type=Path, nargs="+")
    parser.add_argument("--slug", required=True)
    parser.add_argument("--description", required=True)
    parser.add_argument("--dimensions-file", type=Path, required=True)
    parser.add_argument("--output-root", type=Path, default=Path(__file__).parent / "generated")
    parser.add_argument("--app-asset", type=Path)
    parser.add_argument("--image-model", default="gpt-image-2-5-sunburst")
    parser.add_argument("--mesh-model", default="meshy-7.1")
    parser.add_argument("--poll-seconds", type=float, default=5)
    parser.add_argument("--timeout-minutes", type=float, default=15)
    return parser.parse_args()


class Meshy:
    def __init__(self, api_key, poll_seconds, timeout_minutes):
        self.headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        }
        self.poll_seconds = poll_seconds
        self.timeout_seconds = timeout_minutes * 60

    def create(self, task_type, payload):
        response = requests.post(
            f"{API_ROOT}/{task_type}",
            headers=self.headers,
            json=payload,
            timeout=120,
        )
        self._raise(response)
        task_id = response.json()["result"]
        print(f"{task_type}: created {task_id}")
        return task_id

    def wait(self, task_type, task_id):
        deadline = time.monotonic() + self.timeout_seconds
        while time.monotonic() < deadline:
            response = requests.get(
                f"{API_ROOT}/{task_type}/{task_id}",
                headers={"Authorization": self.headers["Authorization"]},
                timeout=60,
            )
            self._raise(response)
            task = response.json()
            print(f"{task_type}: {task.get('status')} {task.get('progress', 0)}%")
            if task.get("status") in FINAL_STATUSES:
                if task["status"] != "SUCCEEDED":
                    raise RuntimeError(f"{task_type} failed: {task.get('task_error')}")
                return task
            time.sleep(self.poll_seconds)
        raise TimeoutError(f"{task_type} {task_id} did not finish before the timeout")

    @staticmethod
    def _raise(response):
        if not response.ok:
            raise RuntimeError(f"Meshy HTTP {response.status_code}: {response.text[:1200]}")


def image_data_uri(path):
    mime = "image/png" if path.suffix.lower() == ".png" else "image/jpeg"
    return f"data:{mime};base64,{base64.b64encode(path.read_bytes()).decode()}"


def download(url, destination):
    response = requests.get(url, timeout=240)
    response.raise_for_status()
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(response.content)


def write_task(directory, name, task):
    (directory / f"{name}-task.json").write_text(json.dumps(task, indent=2))


def load_dimensions(path):
    if not path.is_file():
        raise SystemExit(f"Dimensions manifest not found: {path}")
    try:
        manifest = json.loads(path.read_text())
    except (OSError, json.JSONDecodeError) as error:
        raise SystemExit(f"Invalid dimensions manifest: {error}") from error

    source = manifest.get("source")
    measurements = manifest.get("measurements")
    scale = manifest.get("meshy_scale")
    units = manifest.get("units")
    if not isinstance(source, dict) or not all(source.get(key) for key in ("brand", "product_url", "size_label")):
        raise SystemExit("Dimensions manifest source requires brand, product_url, and size_label")
    if units not in {"cm", "in", "m"}:
        raise SystemExit("Dimensions manifest units must be cm, in, or m")
    if not isinstance(measurements, dict) or not measurements:
        raise SystemExit("Dimensions manifest requires at least one source-provided measurement")
    if any(not isinstance(value, (int, float)) or value <= 0 for value in measurements.values()):
        raise SystemExit("Every source-provided measurement must be a positive number")
    if not isinstance(scale, dict) or scale.get("mode") not in {"height", "longest_side", "auto"}:
        raise SystemExit("meshy_scale.mode must be height, longest_side, or auto")
    if scale["mode"] == "auto":
        if manifest.get("measurement_basis") != "body_size_chart":
            raise SystemExit("Automatic scale requires measurement_basis body_size_chart")
        return manifest, {"auto_size": True, "origin_at": "bottom"}
    scale_measurement = scale.get("measurement")
    if scale_measurement not in measurements:
        raise SystemExit("meshy_scale.measurement must name one of the source-provided measurements")

    meters_per_unit = {"cm": 0.01, "in": 0.0254, "m": 1}[units]
    scale_meters = round(measurements[scale_measurement] * meters_per_unit, 6)
    resize_key = "resize_height" if scale["mode"] == "height" else "resize_longest_side"
    return manifest, {resize_key: scale_meters, "origin_at": "bottom"}


def dimensions_prompt(manifest):
    source = manifest["source"]
    measurements = ", ".join(
        f"{name.replace('_', ' ')}={value:g} {manifest['units']}"
        for name, value in manifest["measurements"].items()
    )
    basis = (
        "These are wearer body-size-chart values, not garment dimensions; use them only to "
        "construct the selected size and keep the final real-world scale explicitly estimated. "
        if manifest.get("measurement_basis") == "body_size_chart"
        else ""
    )
    reference_model = manifest.get("reference_model")
    model_context = ""
    if isinstance(reference_model, dict):
        model_context = (
            f" The source model is {reference_model.get('height', 'an unspecified height')} "
            f"wearing size {reference_model.get('worn_size', 'unspecified')}."
        )
    return (
        f"Authoritative {source['brand']} measurements for size {source['size_label']}: "
        f"{measurements}. {basis}Preserve these proportions.{model_context} "
        f"Source: {source['product_url']}."
    )


def ghost_prompt(description, dimensions):
    return (
        f"Extract only this garment: {description}. Remove the person, hands, other clothing, "
        "shoes, branding, hanger, and background. Reconstruct the complete garment as a realistic "
        "hollow ghost-mannequin product asset with no body visible. Preserve its construction, "
        "silhouette, seams, closures, cuffs, collar, hem, material, and color. Generate internally "
        "consistent front, side, and back orthographic views of the exact same garment, centered at "
        "identical scale and neutral pose, with soft even studio lighting. Preserve only authentic "
        "logos visible in the references; add no text or invented branding. "
        f"{dimensions_prompt(dimensions)}"
    )


def validate_usdz(path):
    checker = shutil.which("usdchecker")
    if checker is None:
        print("usdchecker not found; skipped USDZ validation")
        return
    subprocess.run([checker, str(path)], check=True)


def main():
    args = parse_args()
    api_key = os.environ.get("MESHY_API_KEY")
    if not api_key:
        raise SystemExit("Set MESHY_API_KEY in the environment; never put it in the repository.")
    if len(args.source_images) > 5:
        raise SystemExit("Meshy accepts at most five source images")
    missing_images = [path for path in args.source_images if not path.is_file()]
    if missing_images:
        raise SystemExit(f"Source image not found: {missing_images[0]}")
    dimensions, resize_parameters = load_dimensions(args.dimensions_file)

    output = args.output_root / args.slug
    output.mkdir(parents=True, exist_ok=True)
    shutil.copy2(args.dimensions_file, output / "source-dimensions.json")
    meshy = Meshy(api_key, args.poll_seconds, args.timeout_minutes)

    image_task_id = meshy.create(
        "image-to-image",
        {
            "ai_model": args.image_model,
            "prompt": ghost_prompt(args.description, dimensions),
            "reference_image_urls": [image_data_uri(path) for path in args.source_images],
            "generate_multi_view": True,
            "remove_background": True,
        },
    )
    image_task = meshy.wait("image-to-image", image_task_id)
    write_task(output, "image", image_task)
    for index, url in enumerate(image_task.get("image_urls", []), 1):
        download(url, output / f"view-{index}.png")

    model_task_id = meshy.create(
        "multi-image-to-3d",
        {
            "input_task_id": image_task_id,
            "ai_model": args.mesh_model,
            "geometry_resolution": "2k",
            "should_texture": True,
            "texture_model": "meshy-7",
            "texture_resolution": "2k",
            "enable_pbr": True,
            "remove_lighting": True,
            "image_enhancement": False,
            "should_remesh": True,
            "target_polycount": 50_000,
            "target_formats": ["glb"],
            "multi_view_thumbnails": True,
        },
    )
    model_task = meshy.wait("multi-image-to-3d", model_task_id)
    write_task(output, "model", model_task)

    resize_task_id = meshy.create(
        "resize",
        {
            "input_task_id": model_task_id,
            **resize_parameters,
        },
    )
    resize_task = meshy.wait("resize", resize_task_id)
    write_task(output, "resize", resize_task)

    convert_task_id = meshy.create(
        "convert",
        {
            "input_task_id": resize_task_id,
            "target_formats": ["usdz"],
        },
    )
    convert_task = meshy.wait("convert", convert_task_id)
    write_task(output, "convert", convert_task)

    usdz_url = convert_task.get("model_urls", {}).get("usdz")
    if not usdz_url:
        raise RuntimeError("The convert task did not return a USDZ URL")
    usdz_path = output / f"{args.slug}.usdz"
    download(usdz_url, usdz_path)
    validate_usdz(usdz_path)

    if args.app_asset:
        args.app_asset.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(usdz_path, args.app_asset)
        print(f"app asset: {args.app_asset}")
    print(f"generated: {usdz_path}")


if __name__ == "__main__":
    main()
