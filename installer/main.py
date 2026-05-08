"""
main.py - 1o1 AI WebSocket Server by ManjuLAB
Full-duplex conversational AI — connects to https://yogabrata.com/demo.html
"""
import asyncio, json, logging, os
from pathlib import Path
import uvicorn
from fastapi import FastAPI, WebSocket, WebSocketDisconnect

logging.basicConfig(
    level=logging.INFO,
    format="[%(asctime)s] [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S"
)
log = logging.getLogger(__name__)

BASE   = Path(__file__).parent
CERT   = BASE / "server.crt"
KEY    = BASE / "server.key"
CONFIG = BASE / "config.json"

config = json.loads(CONFIG.read_text(encoding="utf-8-sig")) if CONFIG.exists() else {}
HOST   = config.get("host", "localhost")
PORT   = int(config.get("port", 8998))

app = FastAPI(title="1o1 AI Server")

@app.get("/health")
def health():
    return {"status": "ok", "server": "1o1 AI by ManjuLAB"}

@app.websocket("/")
async def ws_endpoint(ws: WebSocket):
    await ws.accept()
    client = str(ws.client)
    log.info(f"Client connected: {client}")
    session = {"persona": "assistant", "system": "", "sample_rate": 16000}

    try:
        while True:
            msg = await ws.receive()
            if msg["type"] == "websocket.disconnect":
                break

            # --- Text messages (JSON) ---
            if msg.get("text"):
                try:
                    data = json.loads(msg["text"])
                except Exception:
                    continue
                t = data.get("type", "")

                if t == "config":
                    session["persona"]     = data.get("persona", "assistant")
                    session["system"]      = data.get("system", "")
                    session["sample_rate"] = data.get("sampleRate", 16000)
                    log.info(f"Session: persona={session['persona']} sr={session['sample_rate']}")
                    await ws.send_json({"type": "status", "message": "ready"})

                elif t == "ping":
                    await ws.send_json({"type": "pong"})

                elif t == "start":
                    log.info(f"{client}: audio stream started")

                elif t == "stop":
                    log.info(f"{client}: audio stream stopped")
                    # TODO: replace stub with real ASR -> LLM -> TTS pipeline
                    await ws.send_json({
                        "type": "transcript",
                        "role": "assistant",
                        "text": "1o1 AI server is running. Model pipeline not yet loaded — see README for next steps."
                    })

            # --- Binary messages (raw PCM audio) ---
            elif msg.get("bytes"):
                pcm = msg["bytes"]
                log.debug(f"Audio chunk received: {len(pcm)} bytes")
                # TODO: pipe PCM through VAD -> ASR -> LLM -> TTS and stream audio back

    except WebSocketDisconnect:
        pass
    except Exception as e:
        log.error(f"Session error ({client}): {e}")
    finally:
        log.info(f"Client disconnected: {client}")


if __name__ == "__main__":
    ssl_ok = CERT.exists() and KEY.exists()
    proto  = "wss" if ssl_ok else "ws"

    log.info("=" * 52)
    log.info("  1o1 AI Server  |  ManjuLAB")
    log.info(f"  Listening: {proto}://{HOST}:{PORT}")
    log.info(f"  Demo UI:   https://yogabrata.com/demo.html")
    if not ssl_ok:
        log.warning("  SSL certs missing — re-run setup.ps1 to fix")
    log.info("=" * 52)

    uvicorn.run(
        app,
        host=HOST,
        port=PORT,
        ssl_keyfile  = str(KEY)  if ssl_ok else None,
        ssl_certfile = str(CERT) if ssl_ok else None,
        log_level    = "info",
    )
