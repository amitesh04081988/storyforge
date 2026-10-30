#!/usr/bin/env python3
"""Run mandatory local checks and store their real exit codes, never model assertions.

Usage: bash scripts/bits-tasks.sh verify TASK_ID --verifier reviewer-02
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
import shutil

def find_bash():
    """Git Bash on Windows: a bare "bash" can be the WSL launcher in System32, which fails when no distro is installed."""
    if os.environ.get("STORYFORGE_BASH"):return os.environ["STORYFORGE_BASH"]
    found=shutil.which("bash")
    if os.name=="nt" and (not found or "system32" in found.lower()):
        for c in (r"C:\Program Files\Git\bin\bash.exe",r"C:\Program Files (x86)\Git\bin\bash.exe"):
            if Path(c).exists():return c
    return found or "bash"
BASH=find_bash()
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
base=subprocess.run([sys.executable,str(STATE),"base"],capture_output=True,text=True)
if base.returncode:raise SystemExit("BLOCKED: "+base.stderr.strip())
base_sha=base.stdout.strip()
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
            result=subprocess.run([BASH,"-c",cmd],capture_output=True,text=True,timeout=args.timeout)
            rc=result.returncode;status="PASS" if rc==0 else "FAIL"
            output=(result.stdout+"\n"+result.stderr)[-24000:]
        except subprocess.TimeoutExpired:
            status="BLOCKED";rc=124;output="gate timed out"
    log=logs/("%s-%s.log"%(args.task_id,gate))
    log.write_text(output)
    cli=[sys.executable,str(STATE),"evidence",str(args.task_id),gate,status,
         "--exit-code",str(rc),"--sha",sha,"--base",base_sha,
         "--config",config_sha,"--verifier",args.verifier,"--source","verify-run"]
    stored=subprocess.run(cli,capture_output=True,text=True)
    if stored.returncode:
        print("BLOCKED: could not save evidence for",gate,stored.stderr.strip(),file=sys.stderr)
        all_pass=False
    print("%s: %s (exit %s, log %s)"%(gate,status,rc,log))
    if status!="PASS":all_pass=False
if not all_pass:sys.exit(1)
