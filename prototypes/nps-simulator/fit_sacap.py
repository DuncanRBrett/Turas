import pandas as pd, numpy as np, json, warnings; warnings.filterwarnings("ignore")
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import cross_val_predict
SRC="/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/Projects/SACAP/Student_Annual/03_Waves/Student_Annual-2025/03_Data/SACAP_Student_Annual-2025_Data_weighted.xlsx"
d=pd.read_excel(SRC,keep_default_na=False,na_values=[""])
d=d[d.Q001.isin(["Complete","Converted"])].reset_index(drop=True)
w=d.weight.astype(float).values
s=pd.to_numeric(d.Q017,errors="coerce")
y=np.where(s>=9,2,np.where(s<=6,0,1))  # 0 Detractor 1 Passive 2 Promoter
sc={"Terrible":1,"Not very good":2,"About average":3,"Good":4,"Excellent":5}
LEV={"Q025":"Educators delivering content","Q026":"Assessment feedback","Q027":"Course content",
     "Q021":"Value for money","Q029":"MySACAP usability","Q063":"Staff friendly and approachable",
     "Q064":"Student admin","Q065":"Email responsiveness"}
R=d[list(LEV)].apply(lambda c:c.map(sc)).astype(float)
dk={c:int(R[c].isna().sum()) for c in LEV}
R=R.fillna(R.median()).round()
def yr(v):
    v=str(v)
    if "Honours" in v: return "Honours"
    if "Masters" in v: return "Masters"
    for k in ["1st","2nd","3rd"]:
        if v.startswith(k): return k+" year"
    return "Other"
course=d.Q005.fillna("Other"); vc=course.value_counts(); course=course.where(course.map(vc)>=40,"Other courses")
CTX={"campus":d.Q002.fillna("Unknown"),"course":course,"year":d.Q006.map(yr),"reg":d.Q009.map(lambda v:"First-time" if "1st" in str(v) else "Returning")}
CTXLAB={"campus":"studies at","course":"on","year":"in","reg":"a"}
levels={k:sorted(v.unique(),key=lambda x:-(v==x).sum()) for k,v in CTX.items()}
# design: context dummies (drop most common level) + ratings centred at 3
cols=[];Xparts=[]
for k in CTX:
    for lv in levels[k][1:]:
        cols.append(("ctx",k,lv)); Xparts.append((CTX[k]==lv).astype(float).values)
for c in LEV:
    cols.append(("lev",c,None)); Xparts.append(R[c].values-3)
X=np.column_stack(Xparts)
C=1.0
m=LogisticRegression(max_iter=5000,C=C)
yi=y
base=np.array([np.average(y==k,weights=w) for k in range(3)])
ll0=np.average(np.log(base[yi]),weights=w)
def cvr2(Xm):
    p=cross_val_predict(LogisticRegression(max_iter=5000,C=C),Xm,y,cv=5,method="predict_proba",params={"sample_weight":w})
    return round(1-np.average(np.log(p[np.arange(len(y)),yi]),weights=w)/ll0,3)
nctx=sum(1 for c in cols if c[0]=="ctx")
r2={"context_only":cvr2(X[:,:nctx]),"ratings_only":cvr2(X[:,nctx:]),"hybrid":cvr2(X)}
print("cv pseudo-R2",r2)
m.fit(X,y,sample_weight=w)
def pack(mod): return {"b0":mod.intercept_.tolist(),"B":mod.coef_.tolist()}
fits=[pack(m)]
rng=np.random.default_rng(20260923)
for b in range(200):
    idx=rng.integers(0,len(y),len(y))
    mb=LogisticRegression(max_iter=5000,C=C).fit(X[idx],y[idx],sample_weight=w[idx]); fits.append(pack(mb))
p=m.predict_proba(X)
nps_w=lambda yy,ww:100*(np.average(yy==2,weights=ww)-np.average(yy==0,weights=ww))
print("actual weighted NPS",round(nps_w(y,w),1),"model mean",round(100*np.average(p[:,2]-p[:,0],weights=w),1))
for k in CTX:
    for lv in levels[k]:
        msk=(CTX[k]==lv).values
        print(f"  {k}={lv[:30]:30s} n={msk.sum():4d} actual={nps_w(y[msk],w[msk]):6.1f} model={100*np.average(p[msk,2]-p[msk,0],weights=w[msk]):6.1f}")
resp={"ctx":{k:[levels[k].index(v) for v in CTX[k]] for k in CTX},"r":R.astype(int).values.T.tolist(),"w":np.round(w,4).tolist(),"y":y.tolist()}
out={"levers":[{"code":c,"label":LEV[c],"dk":dk[c]} for c in LEV],"ctx":[{"key":k,"levels":levels[k]} for k in CTX],
     "cols":cols,"fits":fits,"resp":resp,"r2":r2,"n":int(len(y)),"wave":"2025","actual_nps":round(nps_w(y,w),1)}
json.dump(out,open("build/model_sacap.json","w"))
print("json kb",round(len(json.dumps(out))/1024))
