import asyncio
import json
import sys
import urllib.parse

import websockets

PORT = int(sys.argv[1])
TOKEN = sys.argv[2]
FACTOR = sys.argv[3] if len(sys.argv) > 3 else "2.2"


async def main() -> None:
    uri = f"ws://127.0.0.1:{PORT}/{TOKEN}/ws"
    async with websockets.connect(uri, max_size=None) as ws:
        # VM service JSON-RPC: params carry the protocol metadata directly.
        request = {
            "jsonrpc": "2.0",
            "id": "ping",
            "method": "getVM",
            "params": {},
        }
        await ws.send(json.dumps(request))

        isolate_id = None
        deadline = asyncio.get_event_loop().time() + 15
        while asyncio.get_event_loop().time() < deadline:
            raw = await asyncio.wait_for(ws.recv(), timeout=15)
            payload = json.loads(raw)
            if payload.get("id") == "ping" and "result" in payload:
                isolate_id = payload["result"]["isolates"][0]["id"]
                break
        assert isolate_id, "no isolate answered getVM"
        print("isolate:", isolate_id)

        request = {
            "jsonrpc": "2.0",
            "id": "zoom",
            "method": "ext.flutter.photoBooth.previewZoom",
            "params": {
                "isolateId": isolate_id,
                "factor": FACTOR,
            },
        }
        await ws.send(json.dumps(request))
        deadline = asyncio.get_event_loop().time() + 15
        while asyncio.get_event_loop().time() < deadline:
            raw = await asyncio.wait_for(ws.recv(), timeout=15)
            payload = json.loads(raw)
            if payload.get("id") == "zoom":
                print(json.dumps(payload)[:400])
                return


asyncio.run(main())
