import pandas as pd, numpy as np, warnings; warnings.filterwarnings("ignore")
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import StratifiedKFold, cross_val_predict
R26="/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/TurasProjects/CCPB/CSAT/"
d=pd.read_excel(R26+"W2026/02 Data/CCPB_CSAT_2026.xlsx",keep_default_na=False,na_values=[""])
q=pd.to_numeric(d.Q79); y=(q>=9).astype(int).values
num=lambda c: pd.to_numeric(d[c],errors="coerce")
raw=d[["Q02","Q08","Q09","Q10","Q13","Q22","Q27","Q28","Q202"]].apply(pd.to_numeric,errors="coerce"); raw=raw.fillna(raw.median())
L=pd.DataFrame({"ordering":raw.Q02,"delivery":raw[["Q08","Q09","Q10"]].mean(1),"invoicing":raw.Q13,"merch":raw.Q22,"rep":raw[["Q27","Q28","Q202"]].mean(1)})
Xr=L.values-8
cv=StratifiedKFold(5,shuffle=True,random_state=1); base=y.mean(); ll0=np.mean(np.log(np.where(y==1,base,1-base)))
def r2(X):
    p=cross_val_predict(LogisticRegression(max_iter=5000),X,y,cv=cv,method="predict_proba")[:,1]
    return 1-np.mean(np.log(np.where(y==1,p,1-p)))/ll0
r0=r2(Xr)
ACC={"Has Coca-Cola coolers (Q43)":d.Q43.eq("Yes"),
     "Allows Coke signage (Q37)":d.Q37.eq("Yes"),
     "Requested signage in 12m (Q38)":d.Q38.eq("Yes"),
     "Requested a cooler in 12m (Q47)":d.Q47.eq("Yes"),
     "Has a fountain machine (Q50)":d.Q50.eq("Yes"),
     "Aware of sales manager (Q33)":d.Q33.eq("Yes"),
     "Offered promotion in 3m (Q29)":d.Q29.eq("Yes"),
     "CCPB rep/merchandiser does merchandising (Q16)":d.Q16.isin(["CCPB sales person / rep","CCPB merchandiser"]),
     "Nobody merchandises (Q16)":d.Q16.eq("Nobody"),
     "Called CCPB in last 12m (Q35)":~d.Q35.isin(["Never","More than 12 months"]),
     "Buys Coke via a wholesaler (Q65)":d.Q65.eq("Yes"),
     "Shops around (Q05)":d.Q05.isin(["Sometimes shop around","Always shop around"])}
rng=np.random.default_rng(3)
print(f"baseline ratings-only cv R2 {r0:.3f}; promoter share {100*base:.1f}%")
print(f"{'access':48s} {'n yes':>6s} {'pro% yes':>8s} {'pro% no':>8s} {'raw gap':>7s} {'adj gap (90%)':>18s} {'dR2':>7s}")
for k,v in ACC.items():
    a=v.astype(float).values; n1=int(a.sum())
    if n1<20 or n1>len(a)-20: 
        print(f"{k:48s} {n1:6d}  too few to test"); continue
    X=np.column_stack([Xr,a]); m=LogisticRegression(max_iter=5000).fit(X,y)
    def ame(mod,Xm):
        X1=Xm.copy();X1[:,-1]=1;X0=Xm.copy();X0[:,-1]=0
        return 100*(mod.predict_proba(X1)[:,1]-mod.predict_proba(X0)[:,1]).mean()
    g=ame(m,X); bs=[]
    for _ in range(200):
        i=rng.integers(0,len(y),len(y)); bs.append(ame(LogisticRegression(max_iter=5000).fit(X[i],y[i]),X))
    print(f"{k:48s} {n1:6d} {100*y[a==1].mean():8.1f} {100*y[a==0].mean():8.1f} {100*(y[a==1].mean()-y[a==0].mean()):+7.1f} {g:+6.1f} ({np.percentile(bs,5):+.1f},{np.percentile(bs,95):+.1f}) {r2(X)-r0:+7.3f}")
# nested service ratings among those who have the service
for lab,has,rc in [("Cooler satisfaction Q46 | has coolers",d.Q43.eq("Yes"),"Q46"),("Signage condition Q42 | allows signage",d.Q37.eq("Yes"),"Q42")]:
    idx=has.values & num(rc).notna().values
    yy=y[idx]; Xb=Xr[idx]; Xn=np.column_stack([Xb,num(rc).values[idx]-8])
    b=yy.mean(); l0=np.mean(np.log(np.where(yy==1,b,1-b)))
    def r2s(X):
        p=cross_val_predict(LogisticRegression(max_iter=5000),X,yy,cv=cv,method="predict_proba")[:,1]; return 1-np.mean(np.log(np.where(yy==1,p,1-p)))/l0
    m=LogisticRegression(max_iter=5000).fit(Xn,yy)
    X1=Xn.copy(); X1[:,-1]=np.clip(X1[:,-1]-1,-7,2)
    print(f"{lab}: n={idx.sum()}, mean={num(rc)[idx].mean():.2f}, cv R2 without {r2s(Xb):.3f} with {r2s(Xn):.3f}, coef {m.coef_[0][-1]:+.3f}, -1 point slip {100*(m.predict_proba(X1)[:,1].mean()-m.predict_proba(Xn)[:,1].mean()):+.1f} pro pts")
# impossible combinations
ctx=pd.DataFrame({"channel":d.S09,"size":d.S04,"method":d.S11,"centre":d.S01,"office":d.S05})
cells=np.prod([ctx[c].nunique() for c in ctx]); obs=ctx.drop_duplicates().shape[0]
print(f"context cells possible {cells}, combinations that exist {obs}, singletons {(ctx.value_counts()==1).sum()}")
print(pd.crosstab(d.S04,d.S11).to_string()); print(pd.crosstab(d.S05,d.S01).to_string())
