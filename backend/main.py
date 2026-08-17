"""
Main Entrypoint for bSafe Autonomous Agentic Backend Platform.
Runs FastAPI API Gateway, Micro-Agent orchestrations, SLA timers, and WebSocket Nostr streams.
"""

import asyncio
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from backend.routes.auth import router as auth_router
from backend.routes.journey import router as journey_router
from backend.routes.sos import router as sos_router
from backend.routes.incidents import router as incidents_router
from backend.routes.mesh import router as mesh_router
from backend.websocket.nostr_relay import router as ws_router
from backend.agents.closed_loop_sla_agent import closed_loop_sla_agent

app = FastAPI(
    title="bSafe Agentic Real-Time Safety Intelligence Gateway",
    description="Closed-loop safety ecosystem (Detect -> Assess -> Alert -> Coordinate -> Respond -> Escalate -> Resolve)",
    version="2.0.0"
)

# CORS Configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register Routers
app.include_router(auth_router)
app.include_router(journey_router)
app.include_router(sos_router)
app.include_router(incidents_router)
app.include_router(mesh_router)
app.include_router(ws_router)

# Async Background SLA Monitor
async def bg_sla_checker():
    while True:
        try:
            escalated = closed_loop_sla_agent.evaluate_open_slas(sla_timeout_seconds=45)
            if escalated:
                print(f"[Closed-Loop SLA Agent] Escalated {len(escalated)} unacknowledged incidents beyond 45s SLA threshold.")
        except Exception as e:
            print(f"[SLA Monitor Error]: {e}")
        await asyncio.sleep(10)

@app.on_event("startup")
async def startup_event():
    print("[SERVER] bSafe Agentic Real-Time Safety Ecosystem Gateway Started.")
    asyncio.create_task(bg_sla_checker())

@app.get("/")
def health_check():
    return {
        "system": "bSafe Autonomous Safety Platform",
        "status": "HEALTHY_OPERATIONAL",
        "active_agents": [
            "RouteSafetyAgent",
            "AnomalyDetectionAgent",
            "SOSTriageAgent",
            "GeospatialDispatcherAgent",
            "ClosedLoopSLAAgent"
        ]
    }
