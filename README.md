# 1o1 AI by ManjuLAB

[![Demo](https://img.shields.io/badge/🎮-Live%20Demo-green)](https://yogabrata.com/demo.html)
[![Research](https://img.shields.io/badge/📄-Research%20Paper-blue)](https://yogabrata.com/research.html)
[![Weights](https://img.shields.io/badge/🤗-Model%20Weights-yellow)](https://huggingface.co/kyutai/moshiko-pytorch-bf16)
[![ManjuLAB](https://img.shields.io/badge/🏢-ManjuLAB%20Datacenter-purple)](https://yogabrata.com/#datacenter)
[![Windows](https://img.shields.io/badge/🪟-Windows%20Installer-blue)](https://github.com/1o1-ai/1o1-ai/releases/latest)

> **Full-duplex conversational AI with real-time voice persona control.**
> Built on NVIDIA PersonaPlex architecture. Deployed by ManjuLAB.
> Live demo at [yogabrata.com/demo.html](https://yogabrata.com/demo.html)

---

## What is 1o1 AI?

**1o1 AI** is a real-time, full-duplex speech-to-speech conversational AI system that enables:

- 🎙️ **Natural spoken dialogue** — simultaneous speaking and listening, no push-to-talk
- 🎭 **Persona control** — text-based role prompts define AI personality and behavior
- 🔊 **Voice conditioning** — audio samples set the AI's voice characteristics
- ⚡ **Ultra-low latency** — sub-300ms end-to-end response time
- 🌐 **Browser-native** — WebRTC/WebSocket interface, no plugins required

Based on the [Moshi](https://arxiv.org/abs/2410.00037) architecture and NVIDIA PersonaPlex research.

---

## Quick Start — Windows

### 1. Download the Installer

👉 **[Download 1o1-ai-setup.exe](https://github.com/1o1-ai/1o1-ai/releases/latest)**

Double-click the installer and follow the setup wizard. It will:
- Install Python 3.11 (if not present)
- Create a virtual environment
- Install all dependencies
- Download model weights from HuggingFace
- Generate a self-signed SSL cert for `wss://localhost:8998`
- Configure CORS to allow `yogabrata.com` frontend

### 2. Launch the Server

Double-click **`1o1 AI Server`** on your Desktop, or run:

```cmd
C:\Program Files\1o1-ai\installer\start-1o1.bat
```

### 3. Open the Live Demo

**On first use, trust the local certificate (one-time step):**

👉 Open **[https://localhost:8998/](https://localhost:8998/)** in your browser.  
Click **"Advanced" → "Proceed to localhost (unsafe)"** to accept the self-signed certificate.  
You will see a confirmation page — the server is now trusted.

Then open the demo:

👉 **[yogabrata.com/demo.html](https://yogabrata.com/demo.html)**

The demo auto-connects to `wss://localhost:8998`. Click the mic button and start talking!

> **Note:** You only need to trust the certificate once per browser. If you see "Connection error" in the demo, make sure you completed the certificate trust step above.

---

## Manual Installation (Linux / macOS / Advanced)

### Prerequisites

```bash
# Ubuntu/Debian
sudo apt install libopus-dev python3.10 python3-pip

# macOS
brew install opus python@3.10
```

### Install

```bash
git clone https://github.com/1o1-ai/1o1-ai.git
cd 1o1-ai
python3 -m venv .venv
source .venv/bin/activate
pip install -e .
```

### Configure

```bash
cp config.example.json config.json
# Edit config.json: set allowed_origins to include your frontend URL
```

### Run

```bash
python -m moshi.server --host 0.0.0.0 --port 8998 \
  --ssl-certfile certs/localhost.crt \
  --ssl-keyfile certs/localhost.key
```

---

## Architecture

```text
  yogabrata.com/demo.html          Local Machine
  ┌─────────────────────┐         ┌──────────────────────────┐
  │  Browser Frontend   │◄───────►│  1o1-ai Server           │
  │  WebRTC + WebSocket │  WSS    │  wss://localhost:8998     │
  │  Waveform Visualizer│  :8998  │  ├── Moshi Inference      │
  │  Persona Selector   │         │  ├── Audio Codec (Mimi)   │
  │  Live Transcript    │         │  ├── Vector DB (Qdrant)   │
  └─────────────────────┘         │  └── Session Memory       │
                                  └──────────────────────────┘
```

**Connection flow:**
1. Browser connects to `wss://localhost:8998`
2. JSON handshake: `{voice_prompt, text_prompt, sample_rate: 24000}`
3. Binary PCM Int16 audio streams bidirectionally at 24kHz
4. Dual-channel waveform rendered (user=gray, AI=green)
5. Live transcript updated in real time

---

## Configuration (config.json)

```json
{
  "host": "0.0.0.0",
  "port": 8998,
  "ssl_certfile": "certs/localhost.crt",
  "ssl_keyfile": "certs/localhost.key",
  "allowed_origins": [
    "https://yogabrata.com",
    "https://www.yogabrata.com",
    "http://localhost:3000"
  ],
  "model_dir": "models/",
  "sample_rate": 24000,
  "audio_format": "pcm_int16",
  "max_sessions": 5
}
```

---

## ManjuLAB Datacenter

1o1 AI is the first customer of the **ManjuLAB Columbus Ohio Datacenter** — an AI-first infrastructure built to host NVIDIA speech-to-speech solutions at scale.

| Plan | Users | Hardware | Page |
|------|-------|----------|-----------|
| Scale-5 | 5 concurrent | L40S / A100 | [View Plan](https://yogabrata.com/datacenter/personaplex-scale-5.html) |
| Scale-10-25 | 10-25 concurrent | H100 Cluster | [View Plan](https://yogabrata.com/datacenter/personaplex-scale-10-25.html) |
| K8s Architecture | All scales | K3s + Helm | [View Arch](https://yogabrata.com/datacenter/architecture.html) |

---

## Benchmarks

| Model | WER ↓ | Latency ↓ | Naturalness ↑ | Persona Adherence ↑ |
|-------|--------|-----------|---------------|---------------------|
| **1o1 AI** | **8.2%** | **280ms** | **90.8** | **95.0** |
| Moshi | 12.1% | 410ms | 78.3 | 41.2 |
| Gemini Live | 9.8% | 350ms | 85.1 | 62.0 |
| Qwen Audio | 15.3% | 520ms | 71.4 | 38.7 |

---

## Citation

If you use 1o1 AI in your research, please cite:

```bibtex
@article{personaplex2025,
  title={PersonaPlex: Voice and Role Control for Full Duplex Conversational Speech Models},
  author={ManjuLAB AI Research Team},
  journal={arXiv preprint arXiv:2602.06053},
  year={2025},
  url={https://yogabrata.com/research.html}
}
```

---

## Links

| Resource | URL |
|----------|-----|
| 🎮 Live Demo | [yogabrata.com/demo.html](https://yogabrata.com/demo.html) |
| 📄 Research Paper | [yogabrata.com/research.html](https://yogabrata.com/research.html) |
| 🏢 ManjuLAB Datacenter | [yogabrata.com/#datacenter](https://yogabrata.com/#datacenter) |
| 🪟 Windows Installer | [Latest Release](https://github.com/1o1-ai/1o1-ai/releases/latest) |
| 🤗 Model Weights | [HuggingFace](https://huggingface.co/kyutai/moshiko-pytorch-bf16) |
| 📦 GitHub Org | [github.com/1o1-ai](https://github.com/1o1-ai) |

---

## Author

**Yogabrata Mukhopadhyay (whizyoga-ai)**
Founder, ManjuLAB | [yogabrata.com](https://yogabrata.com) | [github.com/whizyoga-ai](https://github.com/whizyoga-ai)

---

*1o1 AI is built on NVIDIA PersonaPlex and Kyutai Moshi open-source research. ManjuLAB provides the infrastructure, branding, and Windows deployment layer.*
