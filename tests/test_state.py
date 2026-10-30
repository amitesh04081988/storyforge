"""Durable Bits-Mode state, dependency, evidence and recovery regression tests."""
import hashlib
import json
import os
from pathlib import Path
import sqlite3
import subprocess
import sys
import tempfile
import unittest

SRC=Path(__file__).resolve().parents[1]/"plugins/storyforge/scripts/bits-state.py"
VERIFY=SRC.parent/"verify-run.py"

class StateTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.cwd=Path(self.temp.name)
        self.env=dict(os.environ,STORYFORGE_DB=str(self.cwd/"state.sqlite"))
        self.exec(["git","init","-q"])
        self.exec(["git","config","user.email","test@example.invalid"])
        self.exec(["git","config","user.name","Test"])
        (self.cwd/"storyforge.config.json").write_text(json.dumps({"test":"true","lint":"true","typecheck":"true"}))
        (self.cwd/".gitignore").write_text("state.sqlite*\n.storyforge/\n")
        (self.cwd/"initial.txt").write_text("one")
        self.exec(["git","add","."])
        self.exec(["git","commit","-qm","init"])
    def exec(self,cmd):
        r=subprocess.run(cmd,cwd=self.cwd,env=self.env,text=True,capture_output=True)
        self.assertEqual(r.returncode,0,r.stderr)
        return r.stdout.strip()
    def cmd(self,*args,success=True):
        r=subprocess.run([sys.executable,str(SRC),*map(str,args)],cwd=self.cwd,env=self.env,text=True,capture_output=True)
        if success:self.assertEqual(r.returncode,0,r.stderr)
        else:self.assertNotEqual(r.returncode,0,r.stdout)
        return r
    def context(self):
        sha=self.exec(["git","rev-parse","HEAD"])
        base=sha
        cfg=hashlib.sha256((self.cwd/"storyforge.config.json").read_bytes()).hexdigest()
        return sha,base,cfg
    def test_missing_evidence_prevents_done(self):
        task=self.cmd("add","Add endpoint","--mode","full").stdout.strip()
        self.cmd("set",task,"doing")
        self.cmd("identity",task,"builder","verifier")
        self.cmd("set",task,"verifying")
        self.cmd("set",task,"done",success=False)
        self.cmd("attest",task,success=False)
    def test_atomic_claim_and_dependency(self):
        one=self.cmd("add","First","--mode","direct").stdout.strip()
        two=self.cmd("add","Second","--deps",one,"--mode","direct").stdout.strip()
        self.assertEqual(self.cmd("next").stdout.strip(),one)
        self.assertEqual(self.cmd("claim","--limit","2").stdout.strip(),one)
        self.assertEqual(self.cmd("claim","--limit","2").stdout.strip(),"")
        self.cmd("set",one,"verifying")
        self.cmd("set",one,"done",success=False)
        self.assertEqual(self.cmd("next").stdout.strip(),"")
        self.cmd("add","Bad","--deps","999",success=False)
    def test_evidence_bound_to_sha_config_and_verifier(self):
        task=self.cmd("add","Feature","--mode","light").stdout.strip()
        self.cmd("set",task,"doing")
        self.cmd("identity",task,"builder","verifier")
        self.cmd("set",task,"verifying")
        sha,base,cfg=self.context()
        for gate in ("test","lint","typecheck"):
            self.cmd("evidence",task,gate,"PASS","--exit-code","0","--sha",sha,"--base",base,"--config",cfg,"--verifier","verifier")
        self.assertEqual(self.cmd("attest",task).stdout.strip(),sha)
        self.cmd("set",task,"done")
        self.assertIn("GOAL_VERIFIED",self.cmd("status").stdout)
    def test_repair_and_interruption(self):
        task=self.cmd("add","Repairable","--mode","light").stdout.strip()
        self.cmd("set",task,"doing")
        self.cmd("set",task,"verifying")
        self.cmd("set",task,"doing")
        self.cmd("recover")
        self.cmd("set",task,"doing")
        self.cmd("set",task,"blocked")
        self.assertNotIn(task,self.cmd("next").stdout)
    def test_same_builder_verifier_rejected(self):
        task=self.cmd("add","Risky","--mode","full").stdout.strip()
        self.cmd("set",task,"doing")
        self.cmd("identity",task,"same","same",success=False)
    def test_config_invalidation(self):
        task=self.cmd("add","Docs","--mode","direct").stdout.strip()
        self.cmd("set",task,"doing")
        self.cmd("set",task,"verifying")
        sha,base,cfg=self.context()
        self.cmd("evidence",task,"diff","PASS","--exit-code","0","--sha",sha,"--base",base,"--config",cfg,"--verifier","reviewer")
        self.cmd("attest",task)
        (self.cwd/"storyforge.config.json").write_text(json.dumps({"test":"false"}))
        self.cmd("set",task,"done",success=False)
    def test_verification_runner(self):
        task=self.cmd("add","Unit","--mode","light").stdout.strip()
        self.cmd("set",task,"doing");self.cmd("identity",task,"builder","verifier");self.cmd("set",task,"verifying")
        r=subprocess.run([sys.executable,str(VERIFY),task,"--verifier","verifier"],cwd=self.cwd,env=self.env,capture_output=True,text=True)
        self.assertEqual(r.returncode,0,r.stdout+"\n"+r.stderr)
        self.cmd("attest",task);self.cmd("set",task,"done")

if __name__=="__main__":unittest.main()
