#!/usr/bin/env python3
"""Deterministic minimum-risk mode for StoryForge's Bits-Mode router."""
import argparse
import json
import re

STRICT_WORDS=[
    r"\bauth(?:entication|orization)?\b",r"\bpermissions?\b",r"\baccess control\b",
    r"\bpassword\b",r"\btoken\b",r"\bsecret\b",r"\bcredential\b",
    r"\bpayments?\b",r"\bfinancial\b",r"\bpersonal data\b",r"\bpii\b",
    r"\bmigrat(?:e|ion|ions)\b",r"\bprod(?:uction)? database\b",r"\bdelete data\b",
    r"\bencrypt(?:ion)?\b",r"\bcrypto(?:graphy)?\b",r"\bconcurren(?:cy|t)\b",
    r"\brace condition\b",r"\bsecurity policy\b",r"\bdeploy(?:ment)?\b",
]
STRICT_PATHS=[
    r"(^|/)(auth|iam|permissions|secrets|migrations|payments|security)(/|$)",
    r"^\.github/workflows/",r"^\.claude/",r"(^|/)storyforge\.config\.json$",
    r"^plugins/storyforge/(hooks|scripts)/",r"(^|/)(Dockerfile|terraform|helm)/",
]
DOC_PATHS=r"(^|/)(README|CHANGELOG|CONTRIBUTING)(\..*)?$|^docs/|\.md$"
def classify(request,paths,requested):
    hay=request.lower()
    flags=[]
    for pat in STRICT_WORDS:
        if re.search(pat,hay):flags.append("request:"+pat)
    for path in paths:
        normalized=path.replace("\\","/").lstrip("./")
        if any(re.search(pattern,normalized,re.I) for pattern in STRICT_PATHS):
            flags.append("sensitive path:"+normalized)
    if flags:
        mode="strict"
    elif paths and all(re.search(DOC_PATHS,p,re.I) for p in paths):
        mode="fast"
    else:
        mode="standard"
    ranks={"fast":0,"standard":1,"strict":2}
    if requested!="auto" and ranks[requested]>ranks[mode]:mode=requested
    return {"mode":mode,"internal_mode":{"fast":"direct","standard":"full","strict":"full"}[mode],
            "risk_flags":sorted(set(flags)),"requested_mode":requested,
            "escalated":requested!="auto" and ranks[mode]>ranks[requested]}
if __name__=="__main__":
    p=argparse.ArgumentParser()
    p.add_argument("request")
    p.add_argument("--path",action="append",default=[])
    p.add_argument("--requested",choices=["auto","fast","standard","strict"],default="auto")
    args=p.parse_args()
    print(json.dumps(classify(args.request,args.path,args.requested),indent=2))
