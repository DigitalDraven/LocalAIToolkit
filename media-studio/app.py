import base64
import os
import uuid
from datetime import datetime
from pathlib import Path
from urllib.parse import urlparse

import gradio as gr
import requests
from PIL import Image
from io import BytesIO

API_BASE = os.environ.get("COSMOS_API_BASE", "http://127.0.0.1:8000/v1").rstrip("/")
OUT_DIR = Path(os.environ.get("MEDIA_OUTPUT_DIR", "/outputs"))
OUT_DIR.mkdir(parents=True, exist_ok=True)
MODEL = "nvidia/Cosmos3-Nano"


def status_text():
    try:
        r = requests.get(f"{API_BASE}/models", timeout=3)
        r.raise_for_status()
        ids = [m.get("id", "") for m in r.json().get("data", [])]
        if MODEL in ids:
            return f"Connected to Cosmos 3 Nano · {API_BASE}"
        return f"Backend is responding, but {MODEL} was not listed. Models: {', '.join(ids) or 'none'}"
    except Exception as exc:
        return f"Cosmos backend unavailable at {API_BASE}: {exc}"


def generate_image(prompt, width, height, steps, seed):
    if not prompt or not prompt.strip():
        raise gr.Error("Enter a prompt first.")
    payload = {
        "model": MODEL, "prompt": prompt.strip(), "n": 1,
        "size": f"{int(width)}x{int(height)}",
        "num_inference_steps": int(steps), "response_format": "b64_json"
    }
    if seed is not None and str(seed).strip():
        try:
            payload["seed"] = int(seed)
        except ValueError:
            raise gr.Error("Seed must be an integer or left blank.")
    try:
        response = requests.post(f"{API_BASE}/images/generations", json=payload, timeout=600)
        response.raise_for_status()
        data = response.json()["data"][0]
        if data.get("b64_json"):
            image_bytes = base64.b64decode(data["b64_json"])
        elif data.get("url"):
            image_bytes = requests.get(data["url"], timeout=60).content
        else:
            raise ValueError("The API response contained neither b64_json nor url.")
        image = Image.open(BytesIO(image_bytes)).convert("RGB")
        path = OUT_DIR / f"image-{datetime.now():%Y%m%d-%H%M%S}-{uuid.uuid4().hex[:6]}.png"
        image.save(path)
        return image, str(path), f"Image generated and saved: {path.name}"
    except requests.HTTPError as exc:
        detail = exc.response.text[:2000] if exc.response is not None else str(exc)
        raise gr.Error(f"Image API error: {detail}")
    except Exception as exc:
        raise gr.Error(f"Image generation failed: {exc}")


def generate_video(prompt, width, height, frames, fps, steps):
    if not prompt or not prompt.strip():
        raise gr.Error("Enter a prompt first.")
    fields = {
        "prompt": prompt.strip(), "size": f"{int(width)}x{int(height)}",
        "num_frames": str(int(frames)), "fps": str(int(fps)),
        "num_inference_steps": str(int(steps)), "generate_sound": "false"
    }
    try:
        response = requests.post(f"{API_BASE}/videos/sync", data=fields, timeout=1800)
        response.raise_for_status()
        if not response.content or not response.content[:4] == b"\x00\x00\x00\x18" and b"ftyp" not in response.content[:32]:
            content_type = response.headers.get("content-type", "unknown")
            raise ValueError(f"Expected MP4 bytes; received content-type {content_type}. Check API support for reference images.")
        path = OUT_DIR / f"video-{datetime.now():%Y%m%d-%H%M%S}-{uuid.uuid4().hex[:6]}.mp4"
        path.write_bytes(response.content)
        return str(path), str(path), f"Video generated and saved: {path.name} ({len(response.content) / 1024 / 1024:.1f} MiB)"
    except requests.HTTPError as exc:
        detail = exc.response.text[:2000] if exc.response is not None else str(exc)
        raise gr.Error(f"Video API error: {detail}")
    except Exception as exc:
        raise gr.Error(f"Video generation failed: {exc}")


with gr.Blocks(theme=gr.themes.Soft(), title="Cosmos 3 Nano Media Studio", css=".gradio-container {max-width: 1500px !important}") as demo:
    gr.Markdown("# Cosmos 3 Nano · Media Studio\nCreate images and short videos using the Cosmos 3 Nano backend on your DGX Spark.")
    connection = gr.Textbox(label="Backend status", value=status_text, interactive=False)
    refresh = gr.Button("Refresh backend status", size="sm")
    refresh.click(status_text, outputs=connection)
    with gr.Tabs():
        with gr.Tab("Image"):
            with gr.Row():
                with gr.Column(scale=1):
                    image_prompt = gr.Textbox(label="Prompt", placeholder="Describe the image you want to create…", lines=5)
                    with gr.Row():
                        image_width = gr.Dropdown([512, 768, 1024], value=512, label="Width")
                        image_height = gr.Dropdown([512, 768, 1024], value=512, label="Height")
                    image_steps = gr.Slider(1, 30, value=15, step=1, label="Inference steps")
                    image_seed = gr.Textbox(label="Seed (optional)", placeholder="Leave blank for default")
                    image_button = gr.Button("Generate image", variant="primary")
                with gr.Column(scale=1):
                    image_result = gr.Image(label="Generated image", type="pil")
                    image_file = gr.File(label="Saved image")
                    image_status = gr.Textbox(label="Result", interactive=False)
            image_button.click(generate_image, inputs=[image_prompt, image_width, image_height, image_steps, image_seed], outputs=[image_result, image_file, image_status])
        with gr.Tab("Video"):
            with gr.Row():
                with gr.Column(scale=1):
                    video_prompt = gr.Textbox(label="Prompt", placeholder="Describe the action, camera movement, and scene…", lines=5)
                    with gr.Row():
                        video_width = gr.Dropdown([256, 512, 832], value=256, label="Width")
                        video_height = gr.Dropdown([256, 512, 480], value=256, label="Height")
                    video_frames = gr.Slider(8, 64, value=16, step=8, label="Frames")
                    video_fps = gr.Dropdown([8, 12, 16, 24], value=8, label="Frames per second")
                    video_steps = gr.Slider(1, 30, value=15, step=1, label="Inference steps")
                    video_button = gr.Button("Generate video", variant="primary")
                with gr.Column(scale=1):
                    video_result = gr.Video(label="Generated video", format="mp4")
                    video_file = gr.File(label="Saved video")
                    video_status = gr.Textbox(label="Result", interactive=False)
            video_button.click(generate_video, inputs=[video_prompt, video_width, video_height, video_frames, video_fps, video_steps], outputs=[video_result, video_file, video_status])
    gr.Markdown("Generated files are retained in the toolkit's Cosmos Nano Media output directory. Reference-image video conditioning is not included until the backend request format is verified.")

if __name__ == "__main__":
    demo.launch(server_name="0.0.0.0", server_port=7860, share=False, show_error=True, allowed_paths=["/outputs"])
