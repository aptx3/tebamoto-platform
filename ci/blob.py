import os,hmac,hashlib,base64,datetime,urllib.request,urllib.error,re
k=base64.b64decode(os.environ['KEY']); ac=os.environ['AC']
base="https://%s.blob.core.windows.net/"%ac
def sh(method,path,qs=""):
    xd=datetime.datetime.now(datetime.timezone.utc).strftime('%a, %d %b %Y %H:%M:%S GMT')
    canon="x-ms-date:"+xd+"\nx-ms-version:2021-08-06\n"
    res="/%s/%s"%(ac,path)
    if qs:
        res+="\n"+"\n".join(kv.replace('=',':',1) for kv in sorted(qs.split('&')))
    sts="\n".join([method]+[""]*11+[canon+res])
    sig=base64.b64encode(hmac.new(k,sts.encode(),hashlib.sha256).digest()).decode()
    return {"Authorization":"SharedKey %s:%s"%(ac,sig),"x-ms-date":xd,"x-ms-version":"2021-08-06"}
def req(url,path,qs=""):
    r=urllib.request.Request(url, headers=sh("GET",path,qs))
    try:
        with urllib.request.urlopen(r,timeout=30) as resp: return resp.status, resp.read().decode('utf-8','replace')
    except urllib.error.HTTPError as e: return e.code, e.read().decode('utf-8','replace')
    except Exception as e: return 0, repr(e)
s,b=req(base+"?comp=list","","comp=list")
print("LISTCONTAINERS",s,b[:1200])
for c in re.findall(r"<Name>([^<]+)</Name>", b):
    s2,b2=req(base+"%s?restype=container&comp=list"%c, c, "restype=container&comp=list")
    print("BLOBS",c,s2,b2[:2000])
    for n in re.findall(r"<Name>([^<]+)</Name>", b2)[:15]:
        s3,b3=req(base+"%s/%s"%(c,n), "%s/%s"%(c,n))
        print("CONTENT",c,n,s3,b3[:2000])
