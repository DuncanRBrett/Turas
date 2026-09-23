import pandas as pd, numpy as np, warnings; warnings.filterwarnings("ignore")
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import StratifiedKFold
from scipy.optimize import minimize
R="/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/TurasProjects/CCPB/CSAT/"
def prep(path):
    d=pd.read_excel(path,keep_default_na=False,na_values=[""])
    q=pd.to_numeric(d.Q79,errors="coerce"); d=d[q.notna()]; q=q[q.notna()]
    raw=d[["Q02","Q08","Q09","Q10","Q13","Q22","Q27","Q28"]].apply(pd.to_numeric,errors="coerce"); raw=raw.fillna(raw.median())
    L=pd.DataFrame({"Ordering":raw.Q02,"Delivery":raw[["Q08","Q09","Q10"]].mean(1),"Invoicing":raw.Q13,"Merchandising":raw.Q22,"Sales rep (Q27+Q28)":raw[["Q27","Q28"]].mean(1)})
    return L, q.values.astype(int)
rng=np.random.default_rng(5)
res={}
for yr,p in [("2025",R+"W2025/01_Data/CCPB_CSAT2025_Data.xlsx"),("2026",R+"W2026/02 Data/CCPB_CSAT_2026.xlsx")]:
    L,q=prep(p); y=(q>=9).astype(int); X=L.values-8
    def eff(m,sh,j):
        X2=X.copy(); X2[:,j]=np.clip(X2[:,j]+sh,-7,2); return 100*(m.predict_proba(X2)[:,1].mean()-m.predict_proba(X)[:,1].mean())
    m=LogisticRegression(max_iter=5000).fit(X,y); bs=[LogisticRegression(max_iter=5000).fit(X[i],y[i]) for i in [rng.integers(0,len(y),len(y)) for _ in range(200)]]
    res[yr]={c:{sh:(eff(m,sh,j),np.percentile([eff(b,sh,j) for b in bs],5),np.percentile([eff(b,sh,j) for b in bs],95)) for sh in (-1,1)} for j,c in enumerate(L.columns)}
    print(yr,"n",len(y),"promoters",y.sum(),"detractors",(q<=6).sum())
print(f"{'lever':22s} {'2025 slip':>22s} {'2026 slip':>22s} {'2025 up':>20s} {'2026 up':>20s}")
for c in res["2025"]:
    f=lambda t:f"{t[0]:+5.1f} ({t[1]:+.1f},{t[2]:+.1f})"
    print(f"{c:22s} {f(res['2025'][c][-1]):>22s} {f(res['2026'][c][-1]):>22s} {f(res['2025'][c][1]):>20s} {f(res['2026'][c][1]):>20s}")
# ordinal (proportional odds) vs multinomial, 3 classes, 2026, cv log-loss
L,q=prep(R+"W2026/02 Data/CCPB_CSAT_2026.xlsx"); X=L.values-8; y3=np.where(q>=9,2,np.where(q<=6,0,1))
def ord_fit(X,y):
    k=X.shape[1]
    def nll(t):
        b=t[:k]; c1=t[k]; c2=c1+np.exp(t[k+1]); eta=X@b
        F=lambda c:1/(1+np.exp(-(c-eta)))
        p0=F(c1); p1=F(c2)-F(c1); p2=1-F(c2)
        P=np.column_stack([p0,p1,p2]); return -np.sum(np.log(np.clip(P[np.arange(len(y)),y],1e-12,1)))+0.5*np.sum(b**2)
    t=minimize(nll,np.r_[np.zeros(k),-3,0.5],method="BFGS").x; return t
def ord_pred(t,X):
    k=X.shape[1]; b=t[:k]; c1=t[k]; c2=c1+np.exp(t[k+1]); eta=X@b; F=lambda c:1/(1+np.exp(-(c-eta)))
    return np.column_stack([F(c1),F(c2)-F(c1),1-F(c2)])
cv=StratifiedKFold(5,shuffle=True,random_state=1)
Po=np.zeros((len(y3),3)); Pm=np.zeros((len(y3),3))
for tr,te in cv.split(X,y3):
    Po[te]=ord_pred(ord_fit(X[tr],y3[tr]),X[te]); Pm[te]=LogisticRegression(max_iter=5000).fit(X[tr],y3[tr]).predict_proba(X[te])
base=np.array([(y3==k).mean() for k in range(3)]); ll0=np.mean(np.log(base[y3]))
for nm,P in [("ordinal",Po),("multinomial",Pm)]:
    print(nm,"3-class cv R2",round(1-np.mean(np.log(np.clip(P[np.arange(len(y3)),y3],1e-12,1)))/ll0,3),
          "| detractors: mean predicted P(det) among actual detractors",round(P[y3==0,0].mean(),3),"vs others",round(P[y3!=0,0].mean(),3))
t=ord_fit(X,y3); P=ord_pred(t,X)
for j,c in enumerate(L.columns):
    X2=X.copy(); X2[:,j]=np.clip(X2[:,j]-1,-7,2); P2=ord_pred(t,X2)
    print(f"  ordinal slip 1 point {c:22s}: promoters {100*(P2[:,2].mean()-P[:,2].mean()):+.1f}, detractors {100*(P2[:,0].mean()-P[:,0].mean()):+.1f}, NPS {100*((P2[:,2]-P2[:,0]).mean()-(P[:,2]-P[:,0]).mean()):+.1f}")
