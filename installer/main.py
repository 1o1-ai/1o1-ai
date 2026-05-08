"""
main.py - 1o1 AI WebSocket Server by ManjuLAB
Full-duplex conversational AI — connects to https://yogabrata.com/demo.html
"""
import asyncio, json, logging, os
from pathlib import Path
import uvicorn
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.responses import HTMLResponse

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

_TRUST_PAGE = """<!DOCTYPE html>
<html lang="en">
<head><meta charset="utf-8"><title>1o1 AI Server — Certificate Trust</title>
<style>
  body {{ font-family: Arial, sans-serif; max-width: 640px; margin: 60px auto; padding: 0 20px; }}
  h1   {{ color: #1a1a1a; }}
  .ok  {{ color: green; font-weight: bold; }}
  ol   {{ line-height: 2; }}
  a    {{ color: #0066cc; }}
</style>
</head>
<body>
<h1><span role="img" aria-label="Success">&#x2705;</span> 1o1 AI Server is running</h1>
<p class="ok">The server is up on port {port}. Your browser has accepted the certificate.</p>
<p>You can now use the demo:</p>
<p><a href="https://yogabrata.com/demo.html" target="_blank" rel="noopener noreferrer">
  <span role="img" aria-label="Game controller">&#x1F3AE;</span> Open yogabrata.com/demo.html (opens in new tab)
</a></p>
<hr>
<h2>If you still see &ldquo;Connection error&rdquo; in the demo</h2>
<ol>
  <li>Make sure this server is running (you are reading this, so it is &#x2713;).</li>
  <li>Reload <a href="https://yogabrata.com/demo.html" target="_blank" rel="noopener noreferrer">yogabrata.com/demo.html (opens in new tab)</a> in the same browser window you used to visit this page.</li>
  <li>If the problem persists, try a different browser (Chrome is recommended).</li>
</ol>
</body>
</html>
""".format(port=PORT)

app = FastAPI(title="1o1 AI Server")

@app.get("/", response_class=HTMLResponse)
def root():
    return _TRUST_PAGE

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
    if ssl_ok:
        log.info(f"  STEP 1 — Open https://{HOST}:{PORT}/ in your browser")
        log.info(f"           and click 'Advanced' -> 'Proceed' to trust the cert.")
        log.info(f"  STEP 2 — Then open https://yogabrata.com/demo.html")
    else:
        log.warning("  SSL certs missing — re-run setup.ps1 to fix")
        log.warning("  Without SSL the demo cannot connect from yogabrata.com")
    log.info("=" * 52)

    uvicorn.run(
        app,
        host=HOST,
        port=PORT,
        ssl_keyfile  = str(KEY)  if ssl_ok else None,
        ssl_certfile = str(CERT) if ssl_ok else None,
        log_level    = "info",
    )
