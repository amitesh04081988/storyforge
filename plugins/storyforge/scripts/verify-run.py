#!/usr/bin/env python3
"""Run mandatory local checks and store their real exit codes, never model assertions.

Usage: python3 scripts/verify-run.py TASK_ID --verifier reviewer-02
The task must already be in 'verifying' with distinct builder/verifier identities.
Commands come from trusted storyforge.config.json. Do not use on untrusted code
outside a sandbox. Security/review approvals are separate gates, not faked here.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import os

HERE=Path(__file__).resolve().parent
STATE=HERE/"bits-state.py"
p=argparse.ArgumentParser()
p.add_argument("task_id",type=int)
p.add_argument("--verifier",required=True)
p.add_argument("--timeout",type=int,default=300)
p.add_argument("--gates",default="test,lint,typecheck")
args=p.parse_args()
if args.timeout<1 or args.timeout>3600:
    raise SystemExit("timeout must be between 1 and 3600 seconds")
cfg_path=Path("storyforge.config.json")
if not cfg_path.exists():
    raise SystemExit("BLOCKED: missing storyforge.config.json")
cfg=json.loads(cfg_path.read_text())
sha=subprocess.check_output(["git","rev-parse","HEAD"],text=True).strip()
dirty=subprocess.check_output(["git","status","--porcelain"],text=True).strip()
if dirty:raise SystemExit("BLOCKED: commit changes before verification")
base=subprocess.run(["git","rev-parse","refs/remotes/origin/main"],capture_output=True,text=True)
base_sha=base.stdout.strip() if base.returncode==0 else sha
config_sha=hashlib.sha256(cfg_path.read_bytes()).hexdigest()
logs=Path(".storyforge/logs");logs.mkdir(parents=True,exist_ok=True)
all_pass=True
for gate in args.gates.split(","):
    gate=gate.strip()
    if gate not in {"test","lint","typecheck","integration_test","e2e_test","diff"}:
        raise SystemExit("Unsupported executable gate: "+gate)
    cmd=cfg.get(gate,"")
    if gate=="diff":cmd="git diff --check HEAD^ HEAD"
    if not isinstance(cmd,str) or not cmd.strip():
        status="BLOCKED";rc=3;output="required command not configured"
    else:
        try:
            result=subprocess.run(["bash","-c",cmd],capture_output=True,text=True,timeout=args.timeout)
            rc=result.returncode;status="PASS" if rc==0 else "FAIL"
            output=(result.stdout+"\n"+result.stderr)[-24000:]
        except subprocess.TimeoutExpired:
            status="BLOCKED";rc=124;output="gate timed out"
    log=logs/("%s-%s.log"%(args.task_id,gate))
    log.write_text(output)
    cli=[sys.executable,str(STATE),"evidence",str(args.task_id),gate,status,
         "--exit-code",str(rc),"--sha",sha,"--base",base_sha,
         "--config",config_sha,"--verifier",args.verifier]
    stored=subprocess.run(cli,capture_output=True,text=True)
    if stored.returncode:
        print("BLOCKED: could not save evidence for",gate,stored.stderr.strip(),file=sys.stderr)
        all_pass=False
    print("%s: %s (exit %s, log %s)"%(gate,status,rc,log))
    if status!="PASS":all_pass=False
if not all_pass:sys.exit(1)
