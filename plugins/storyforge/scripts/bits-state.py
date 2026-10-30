#!/usr/bin/env python3
"""Transactional, evidence-gated StoryForge ledger (Python 3 stdlib only)."""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import sqlite3
import subprocess
import sys

REQUIRED={"direct":["diff"],"light":["test","lint","typecheck"],"full":["test","lint","typecheck","review","security"]}
EDGES={"todo":{"doing","blocked","cancelled"},
       "doing":{"verifying","blocked","interrupted","failed","cancelled"},
       "verifying":{"done","doing","blocked","interrupted","failed","cancelled"},
       "blocked":{"doing","cancelled"},"interrupted":{"doing","blocked","cancelled"},
       "failed":{"doing","cancelled"},"done":set(),"cancelled":set()}
SHA=re.compile(r"^[0-9a-f]{40}$")
def utc():return datetime.datetime.now(datetime.timezone.utc).isoformat()
def gp(*args):
    r=subprocess.run(["git",*args],text=True,capture_output=True)
    return r.stdout.strip() if r.returncode==0 else ""
def current():
    s=gp("rev-parse","HEAD")
    if not SHA.fullmatch(s):raise ValueError("git HEAD unavailable")
    if gp("status","--porcelain"):raise ValueError("working tree dirty; commit and reverify")
    return s
def base():return gp("rev-parse","refs/remotes/origin/main") or gp("rev-parse","HEAD")
def conf():
    p=Path("storyforge.config.json")
    return hashlib.sha256(p.read_bytes()).hexdigest() if p.exists() else "no-config"
def connect():
    p=Path(os.getenv("STORYFORGE_DB",str(Path(os.getenv("STORYFORGE_TASKS",".storyforge/tasks.tsv")).with_name("tasks.sqlite"))))
    p.parent.mkdir(parents=True,exist_ok=True)
    db=sqlite3.connect(p,timeout=15,isolation_level=None)
    db.row_factory=sqlite3.Row
    db.execute("PRAGMA foreign_keys=ON")
    db.execute("PRAGMA busy_timeout=15000")
    db.execute("PRAGMA journal_mode=WAL")
    db.executescript("""
CREATE TABLE IF NOT EXISTS runs(id TEXT PRIMARY KEY, request TEXT NOT NULL DEFAULT '', status TEXT NOT NULL DEFAULT 'ACTIVE');
CREATE TABLE IF NOT EXISTS tasks(id INTEGER PRIMARY KEY AUTOINCREMENT,run_id TEXT NOT NULL REFERENCES runs(id),title TEXT NOT NULL,mode TEXT NOT NULL,status TEXT NOT NULL,note TEXT NOT NULL DEFAULT '-',attempts INTEGER NOT NULL DEFAULT 0,required TEXT NOT NULL,builder TEXT,verifier TEXT,verified_sha TEXT,verified_base TEXT,verified_config TEXT,pr TEXT,pr_sha TEXT,pr_verdict TEXT);
CREATE TABLE IF NOT EXISTS deps(task INTEGER NOT NULL REFERENCES tasks(id), requires INTEGER NOT NULL REFERENCES tasks(id),PRIMARY KEY(task,requires));
CREATE TABLE IF NOT EXISTS evidence(seq INTEGER PRIMARY KEY AUTOINCREMENT,task INTEGER NOT NULL REFERENCES tasks(id),gate TEXT NOT NULL,verdict TEXT NOT NULL,exit_code INTEGER NOT NULL,sha TEXT NOT NULL,base TEXT NOT NULL,config TEXT NOT NULL,verifier TEXT NOT NULL,created TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS approvals(id TEXT PRIMARY KEY,task INTEGER REFERENCES tasks(id),action TEXT NOT NULL,status TEXT NOT NULL,actor TEXT,reason TEXT);
CREATE TABLE IF NOT EXISTS events(seq INTEGER PRIMARY KEY AUTOINCREMENT,task INTEGER,kind TEXT NOT NULL,details TEXT NOT NULL,created TEXT NOT NULL);
""")
    db.execute("INSERT OR IGNORE INTO runs(id) VALUES('default')")
    return db
def tx(db):db.execute("BEGIN IMMEDIATE")
def get(db,id):
    x=db.execute("SELECT * FROM tasks WHERE id=?",(id,)).fetchone()
    if x is None:raise ValueError("unknown task")
    return x
def ev(db,id,kind,details):
    db.execute("INSERT INTO events(task,kind,details,created) VALUES(?,?,?,?)",(id,kind,json.dumps(details),utc()))
def ready(db,id):
    return db.execute("SELECT COUNT(*) FROM deps d JOIN tasks t ON t.id=d.requires WHERE d.task=? AND t.status!='done'",(id,)).fetchone()[0]==0
def proof(db,t,sha):
    if not SHA.fullmatch(sha or ""):raise ValueError("invalid SHA")
    b=base();h=conf()
    if t["mode"]!="direct" and (not t["builder"] or not t["verifier"] or t["builder"]==t["verifier"]):
        raise ValueError("independent builder and verifier required")
    for gate in json.loads(t["required"]):
        e=db.execute("SELECT * FROM evidence WHERE task=? AND gate=? AND sha=? AND base=? AND config=? ORDER BY seq DESC LIMIT 1",(t["id"],gate,sha,b,h)).fetchone()
        if e is None or e["verdict"]!="PASS" or e["exit_code"]!=0:raise ValueError("missing/failed required gate: "+gate)
        if t["mode"]!="direct" and e["verifier"]!=t["verifier"]:raise ValueError("verifier mismatch")
    return b,h
def run(a):
    db=connect()
    try:
        op=a.command
        if op=="init":
            if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,79}",a.run_id):raise ValueError("invalid run id")
            with db:db.execute("INSERT OR IGNORE INTO runs(id,request) VALUES(?,?)",(a.run_id,a.request))
            print(a.run_id);return
        if op=="add":
            if not a.title.strip() or len(a.title)>500:raise ValueError("invalid title")
            dep=[] if a.deps in ("-","") else [int(v) for v in a.deps.split(",")]
            if len(set(dep))!=len(dep) or any(v<=0 for v in dep):raise ValueError("invalid dependencies")
            required=REQUIRED[a.mode] if a.required is None else a.required.split(",")
            if not required or any(not re.fullmatch("[a-z][a-z0-9_-]*",g) for g in required):raise ValueError("invalid required gates")
            tx(db)
            if not db.execute("SELECT 1 FROM runs WHERE id=?",(a.run_id,)).fetchone():raise ValueError("run not found")
            for x in dep:
                if get(db,x)["run_id"]!=a.run_id:raise ValueError("cross-run dependency")
            cur=db.execute("INSERT INTO tasks(run_id,title,mode,status,required) VALUES(?,?,?,?,?)",(a.run_id,a.title,a.mode,"todo",json.dumps(required)))
            for x in dep:db.execute("INSERT INTO deps VALUES(?,?)",(cur.lastrowid,x))
            ev(db,cur.lastrowid,"created",{"deps":dep})
            db.commit();print(cur.lastrowid);return
        if op in ("next","claim"):
            tx(db)
            avail=[r for r in db.execute("SELECT * FROM tasks WHERE status='todo' AND run_id=? ORDER BY id",(a.run_id,)) if ready(db,r["id"])]
            for r in avail[:a.limit] if op=="claim" else avail:
                if op=="claim":
                    db.execute("UPDATE tasks SET status='doing',attempts=attempts+1 WHERE id=?",(r["id"],))
                    ev(db,r["id"],"claimed",{})
                print(r["id"])
            db.commit();return
        if op=="set":
            tx(db);t=get(db,a.id)
            if a.status not in EDGES[t["status"]]:raise ValueError("invalid state transition")
            if a.status=="doing" and t["status"]=="todo" and not ready(db,a.id):raise ValueError("unsatisfied dependencies")
            if a.status=="done":
                s=current()
                if t["verified_sha"]!=s or t["verified_base"]!=base() or t["verified_config"]!=conf():raise ValueError("stale attestation")
                proof(db,t,s)
            db.execute("UPDATE tasks SET status=?,note=? WHERE id=?",(a.status,a.note,a.id))
            ev(db,a.id,"state",{"from":t["status"],"to":a.status})
            db.commit();return
        if op=="identity":
            tx(db);t=get(db,a.id)
            if t["status"] not in ("doing","verifying"):raise ValueError("inactive task")
            if not a.builder or not a.verifier or a.builder==a.verifier:raise ValueError("independent identities required")
            db.execute("UPDATE tasks SET builder=?,verifier=? WHERE id=?",(a.builder,a.verifier,a.id))
            ev(db,a.id,"identities",{"builder":a.builder,"verifier":a.verifier});db.commit();return
        if op=="evidence":
            if a.verdict not in ("PASS","FAIL","BLOCKED","SKIPPED"):raise ValueError("bad verdict")
            if a.verdict=="PASS" and a.exit_code!=0:raise ValueError("PASS requires exit 0")
            if a.verdict!="PASS" and a.exit_code==0:raise ValueError("non-PASS cannot have exit 0")
            if not SHA.fullmatch(a.sha) or not a.base or not a.config:raise ValueError("missing immutable revision/context")
            tx(db);t=get(db,a.id)
            if t["status"] not in ("doing","verifying"):raise ValueError("inactive task")
            if t["mode"]!="direct" and a.verifier!=t["verifier"]:raise ValueError("verifier mismatch")
            db.execute("INSERT INTO evidence(task,gate,verdict,exit_code,sha,base,config,verifier,created) VALUES(?,?,?,?,?,?,?,?,?)",(a.id,a.gate,a.verdict,a.exit_code,a.sha,a.base,a.config,a.verifier,utc()))
            ev(db,a.id,"evidence",{"gate":a.gate,"verdict":a.verdict});db.commit();return
        if op=="attest":
            tx(db);t=get(db,a.id)
            if t["status"]!="verifying":raise ValueError("must be verifying")
            s=current();b,h=proof(db,t,s)
            db.execute("UPDATE tasks SET verified_sha=?,verified_base=?,verified_config=? WHERE id=?",(s,b,h,a.id))
            ev(db,a.id,"attested",{"sha":s,"base":b,"config":h});db.commit();print(s);return
        if op=="pr":
            tx(db);t=get(db,a.id)
            if a.builder==a.verifier or not a.builder or not a.verifier or not SHA.fullmatch(a.sha):raise ValueError("bad PR metadata")
            db.execute("UPDATE tasks SET pr=?,pr_sha=?,pr_verdict=?,builder=?,verifier=? WHERE id=?",(a.number,a.sha,a.verdict,a.builder,a.verifier,a.id))
            ev(db,a.id,"pr",{"sha":a.sha,"number":a.number});db.commit();return
        if op=="mergeable":
            t=get(db,a.id)
            if t["status"]!="done" or t["pr_verdict"] not in ("unit-test-verified","live-ui-verified") or a.sha!=t["pr_sha"] or a.sha!=t["verified_sha"]:raise ValueError("PR not verified at current SHA")
            if t["verified_base"]!=base() or t["verified_config"]!=conf():raise ValueError("stale base or config")
            proof(db,t,a.sha)
            print("mergeable: verification evidence matches SHA");return
        if op=="show":
            for t in db.execute("SELECT * FROM tasks WHERE run_id=? ORDER BY id",(a.run_id,)):
                deps=[str(r[0]) for r in db.execute("SELECT requires FROM deps WHERE task=?",(t["id"],))]
                print("%s\t%s\t%s\t%s\t%s"%(t["id"],t["status"],t["mode"],",".join(deps) or "-",t["title"]))
            return
        if op=="status":
            rows=db.execute("SELECT status,COUNT(*) n FROM tasks WHERE run_id=? GROUP BY status",(a.run_id,))
            counts={r["status"]:r["n"] for r in rows};total=sum(counts.values())
            print("tasks: %d  todo: %d  doing: %d  verifying: %d  blocked: %d  done: %d"%(total,counts.get("todo",0),counts.get("doing",0),counts.get("verifying",0),counts.get("blocked",0),counts.get("done",0)))
            if not total or counts.get("done",0)!=total:raise ValueError("GOAL_NOT_VERIFIED")
            print("GOAL_VERIFIED");return
        if op in ("recover","cancel"):
            tx(db)
            statuses=("doing","verifying") if op=="recover" else ("todo","doing","verifying","blocked","failed","interrupted")
            rows=list(db.execute("SELECT * FROM tasks WHERE run_id=? AND status IN (%s)"%(",".join("?" for _ in statuses)),(a.run_id,*statuses)))
            target="interrupted" if op=="recover" else "cancelled"
            for t in rows:
                db.execute("UPDATE tasks SET status=?,note=? WHERE id=?",(target,("reconcile external side effects before restart" if op=="recover" else "cancelled"),t["id"]))
                ev(db,t["id"],target,{})
            if op=="cancel":db.execute("UPDATE runs SET status='CANCELLED' WHERE id=?",(a.run_id,))
            db.commit();print(target,len(rows));return
    finally:db.close()
def parse():
    p=argparse.ArgumentParser()
    p.add_argument("--run-id",default=os.getenv("STORYFORGE_RUN_ID","default"))
    sp=p.add_subparsers(dest="command",required=True)
    x=sp.add_parser("init");x.add_argument("request",nargs="?",default="")
    x=sp.add_parser("add");x.add_argument("title");x.add_argument("--deps",default="-");x.add_argument("--mode",choices=list(REQUIRED),default="full");x.add_argument("--required")
    sp.add_parser("next")
    x=sp.add_parser("claim");x.add_argument("--limit",type=int,default=1)
    x=sp.add_parser("set");x.add_argument("id",type=int);x.add_argument("status");x.add_argument("note",nargs="?",default="-")
    x=sp.add_parser("identity");x.add_argument("id",type=int);x.add_argument("builder");x.add_argument("verifier")
    x=sp.add_parser("evidence");x.add_argument("id",type=int);x.add_argument("gate");x.add_argument("verdict");x.add_argument("--exit-code",type=int,required=True);x.add_argument("--sha",required=True);x.add_argument("--base",required=True);x.add_argument("--config",required=True);x.add_argument("--verifier",required=True)
    x=sp.add_parser("attest");x.add_argument("id",type=int)
    x=sp.add_parser("pr");x.add_argument("id",type=int);x.add_argument("number");x.add_argument("sha");x.add_argument("verdict");x.add_argument("builder");x.add_argument("verifier")
    x=sp.add_parser("mergeable");x.add_argument("id",type=int);x.add_argument("sha")
    sp.add_parser("show");sp.add_parser("status");sp.add_parser("recover");sp.add_parser("cancel")
    return p.parse_args()
if __name__=="__main__":
    try:run(parse())
    except (ValueError,sqlite3.Error,PermissionError) as error:
        print("StoryForge BLOCKED:",error,file=sys.stderr);sys.exit(1)
