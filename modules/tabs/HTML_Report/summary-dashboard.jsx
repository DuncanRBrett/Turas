import { useState } from "react";

const BRAND = {
  navy: "#1a2744",
  teal: "#0d8a8a",
  tealLight: "#e6f5f5",
  coral: "#e8614d",
  gold: "#d4a843",
  slate: "#64748b",
  warmGray: "#f8f7f5",
  white: "#ffffff",
  text: "#1e293b",
  textLight: "#94a3b8",
  border: "#e2e8f0",
  sigUp: "#059669",
};

const SUMMARY_DATA = {
  topline: {
    totalN: 1363,
    questions: 118,
    fieldwork: "Nov - Dec 2025",
    methodology: "Online survey",
  },
  nps: {
    question: "Q017 - Would you recommend SACAP to others?",
    score: 45,
    promoters: 61,
    passives: 23,
    detractors: 16,
    byBanner: [
      { label: "Online", score: 47 },
      { label: "Cape Town", score: 34 },
      { label: "Jhb", score: 52 },
      { label: "Pretoria", score: 49 },
      { label: "Durban", score: 39 },
    ],
  },
  trust: {
    question: "Q016 - Trust SACAP to provide good education",
    score: 50,
    fully: 59,
    some: 31,
    doNot: 10,
  },
  ratings: [
    { q: "Q008", label: "Admissions support", positive: 84, neutral: 12, negative: 4, base: 519, note: "1st time registrants only" },
    { q: "Q011", label: "Re-registration experience", positive: 65, neutral: 19, negative: 15, base: 837, note: "Re-registrants only" },
    { q: "Q013", label: "Orientation preparation", positive: 72, neutral: 16, negative: 12, base: 1363, note: null },
  ],
  bannerHighlights: [
    { metric: "NPS", finding: "Cape Town significantly lower at +34 vs total +45", direction: "down", sig: true },
    { metric: "NPS", finding: "1st years significantly higher than Honours students (+54 vs +28)", direction: "up", sig: true },
    { metric: "Trust", finding: "Johannesburg, Pretoria & Online significantly higher trust than Cape Town", direction: "up", sig: true },
    { metric: "Re-reg", finding: "Online campus rated re-registration significantly higher (78% positive) than physical campuses", direction: "up", sig: true },
    { metric: "Re-reg", finding: "35+ age group significantly more positive than 18-20 year olds", direction: "up", sig: true },
    { metric: "Age", finding: "18-20 year olds over-index at Johannesburg (34%) and Pretoria (20%)", direction: "neutral", sig: true },
  ],
  netScoreGrid: [
    { q: "Q008", label: "Admissions support", total: 80, campus: { "Online": 82, "CT": 76, "Jhb": 79, "Pta": 83, "Dbn": 85 }, year: { "1st": 82, "2nd": 88, "3rd": 50, "Hon": 74 }, age: { "18-20": 83, "21-24": 82, "25-34": 73, "35+": 80 } },
    { q: "Q011", label: "Re-registration", total: 49, campus: { "Online": 71, "CT": 27, "Jhb": 35, "Pta": 26, "Dbn": 74 }, year: { "1st": 56, "2nd": 47, "3rd": 47, "Hon": 54 }, age: { "18-20": 30, "21-24": 43, "25-34": 55, "35+": 64 } },
    { q: "Q016", label: "Trust in education", total: 50, campus: { "Online": 51, "CT": 32, "Jhb": 57, "Pta": 59, "Dbn": 39 }, year: { "1st": 52, "2nd": 49, "3rd": 56, "Hon": 40 }, age: { "18-20": 54, "21-24": 49, "25-34": 41, "35+": 56 } },
    { q: "Q017", label: "Recommend (NPS)", total: 45, campus: { "Online": 47, "CT": 34, "Jhb": 52, "Pta": 49, "Dbn": 39 }, year: { "1st": 54, "2nd": 44, "3rd": 49, "Hon": 28 }, age: { "18-20": 56, "21-24": 45, "25-34": 39, "35+": 48 } },
  ],
};

function ScoreGauge({ score, size = 100, label }) {
  const angle = (score + 100) / 200 * 180;
  const rad = (angle - 180) * Math.PI / 180;
  const r = size * 0.38;
  const cx = size / 2;
  const cy = size * 0.52;
  const x = cx + r * Math.cos(rad);
  const y = cy + r * Math.sin(rad);
  
  const getColor = (s) => {
    if (s >= 50) return "#059669";
    if (s >= 20) return BRAND.gold;
    if (s >= 0) return "#f59e0b";
    return BRAND.coral;
  };

  return (
    <div style={{ textAlign: "center" }}>
      <svg width={size} height={size * 0.6} viewBox={`0 0 ${size} ${size * 0.6}`}>
        {/* Background arc */}
        <path
          d={`M ${cx - r} ${cy} A ${r} ${r} 0 0 1 ${cx + r} ${cy}`}
          fill="none"
          stroke="#e2e8f0"
          strokeWidth={size * 0.08}
          strokeLinecap="round"
        />
        {/* Score arc */}
        <path
          d={`M ${cx - r} ${cy} A ${r} ${r} 0 ${angle > 90 ? 1 : 0} 1 ${x} ${y}`}
          fill="none"
          stroke={getColor(score)}
          strokeWidth={size * 0.08}
          strokeLinecap="round"
        />
        <text x={cx} y={cy - 2} textAnchor="middle" style={{ fontSize: size * 0.28, fontWeight: 700, fontFamily: "'DM Mono', monospace", fill: getColor(score) }}>
          +{score}
        </text>
        <text x={cx} y={cy + size * 0.12} textAnchor="middle" style={{ fontSize: size * 0.09, fontWeight: 500, fontFamily: "'DM Sans', sans-serif", fill: BRAND.slate }}>
          {label}
        </text>
      </svg>
    </div>
  );
}

function StackedBar({ positive, neutral, negative, height = 24 }) {
  return (
    <div style={{ display: "flex", borderRadius: 4, overflow: "hidden", height, width: "100%" }}>
      <div style={{ width: `${positive}%`, background: "#059669", transition: "width 0.4s ease" }} />
      <div style={{ width: `${neutral}%`, background: "#fbbf24", transition: "width 0.4s ease" }} />
      <div style={{ width: `${negative}%`, background: BRAND.coral, transition: "width 0.4s ease" }} />
    </div>
  );
}

function HeatCell({ value, isTotal }) {
  const getColor = (v) => {
    if (v >= 60) return { bg: "rgba(5,150,105,0.15)", text: "#059669" };
    if (v >= 40) return { bg: "rgba(5,150,105,0.08)", text: "#059669" };
    if (v >= 20) return { bg: "rgba(251,191,36,0.1)", text: "#b45309" };
    if (v >= 0) return { bg: "rgba(251,191,36,0.15)", text: "#b45309" };
    return { bg: "rgba(232,97,77,0.12)", text: BRAND.coral };
  };
  const c = getColor(value);
  return (
    <td style={{
      padding: "6px 8px",
      textAlign: "center",
      fontSize: 12,
      fontFamily: "'DM Mono', monospace",
      fontWeight: isTotal ? 700 : 500,
      color: isTotal ? BRAND.navy : c.text,
      background: isTotal ? "rgba(26,39,68,0.06)" : c.bg,
      borderBottom: `1px solid ${BRAND.border}`,
      transition: "background 0.15s",
    }}>
      {value >= 0 ? "+" : ""}{value}
    </td>
  );
}

export default function Dashboard() {
  const [hoveredRow, setHoveredRow] = useState(null);
  const d = SUMMARY_DATA;
  const campusCols = ["Online", "CT", "Jhb", "Pta", "Dbn"];
  const yearCols = ["1st", "2nd", "3rd", "Hon"];
  const ageCols = ["18-20", "21-24", "25-34", "35+"];

  return (
    <div style={{ fontFamily: "'DM Sans', sans-serif", background: BRAND.warmGray, minHeight: "100vh", color: BRAND.text }}>
      <link href="https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600;700&family=DM+Mono:wght@400;500&display=swap" rel="stylesheet" />

      {/* Header */}
      <div style={{ background: `linear-gradient(135deg, ${BRAND.navy} 0%, #2a3f5f 100%)`, padding: "24px 32px", borderBottom: `3px solid ${BRAND.teal}` }}>
        <div style={{ maxWidth: 1200, margin: "0 auto" }}>
          <div style={{ color: "rgba(255,255,255,0.5)", fontSize: 11, letterSpacing: "2px", textTransform: "uppercase", fontWeight: 600, marginBottom: 4 }}>
            The Research Lamppost · Turas Analytics
          </div>
          <h1 style={{ color: BRAND.white, fontSize: 22, fontWeight: 700, margin: 0 }}>
            SACAP Student Survey 2025 — Executive Summary
          </h1>
          <div style={{ color: "rgba(255,255,255,0.6)", fontSize: 12, marginTop: 4 }}>
            Dashboard overview · Scroll down for detailed crosstabs
          </div>
        </div>
      </div>

      <div style={{ maxWidth: 1200, margin: "0 auto", padding: "24px 32px" }}>

        {/* Top metrics strip */}
        <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 12, marginBottom: 24 }}>
          {[
            { label: "Total Respondents", value: "1,363", sub: "Online survey" },
            { label: "Fieldwork", value: "Nov–Dec '25", sub: "6 week field period" },
            { label: "Questions Analysed", value: "118", sub: "With significance testing" },
            { label: "Banner Groups", value: "5", sub: "Campus · Course · Intensity · Year · Age" },
          ].map((m, i) => (
            <div key={i} style={{ background: BRAND.white, borderRadius: 8, border: `1px solid ${BRAND.border}`, padding: "14px 18px" }}>
              <div style={{ fontSize: 10, fontWeight: 600, color: BRAND.slate, letterSpacing: "1px", textTransform: "uppercase" }}>{m.label}</div>
              <div style={{ fontSize: 24, fontWeight: 700, color: BRAND.navy, fontFamily: "'DM Mono', monospace", marginTop: 2 }}>{m.value}</div>
              <div style={{ fontSize: 11, color: BRAND.textLight, marginTop: 2 }}>{m.sub}</div>
            </div>
          ))}
        </div>

        {/* NPS + Trust row */}
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 16, marginBottom: 24 }}>
          {/* NPS card */}
          <div style={{ background: BRAND.white, borderRadius: 8, border: `1px solid ${BRAND.border}`, padding: "20px 24px" }}>
            <div style={{ fontSize: 11, fontWeight: 600, color: BRAND.slate, letterSpacing: "1px", textTransform: "uppercase", marginBottom: 4 }}>Net Promoter Score</div>
            <div style={{ fontSize: 12, color: BRAND.textLight, marginBottom: 16 }}>Q017 — Would you recommend SACAP?</div>
            
            <div style={{ display: "flex", alignItems: "center", gap: 24 }}>
              <ScoreGauge score={d.nps.score} size={120} label="NPS" />
              <div style={{ flex: 1 }}>
                <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 8 }}>
                  <span style={{ fontSize: 12, color: "#059669", fontWeight: 600 }}>Promoters {d.nps.promoters}%</span>
                  <span style={{ fontSize: 12, color: "#b45309", fontWeight: 600 }}>Passives {d.nps.passives}%</span>
                  <span style={{ fontSize: 12, color: BRAND.coral, fontWeight: 600 }}>Detractors {d.nps.detractors}%</span>
                </div>
                <StackedBar positive={d.nps.promoters} neutral={d.nps.passives} negative={d.nps.detractors} height={20} />
                <div style={{ display: "flex", gap: 8, marginTop: 12, flexWrap: "wrap" }}>
                  {d.nps.byBanner.map((b, i) => (
                    <div key={i} style={{
                      padding: "4px 10px",
                      borderRadius: 4,
                      background: b.score >= 45 ? "rgba(5,150,105,0.08)" : "rgba(232,97,77,0.08)",
                      fontSize: 11,
                      fontWeight: 600,
                      fontFamily: "'DM Mono', monospace",
                      color: b.score >= 45 ? "#059669" : BRAND.coral,
                    }}>
                      {b.label} +{b.score}
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </div>

          {/* Trust card */}
          <div style={{ background: BRAND.white, borderRadius: 8, border: `1px solid ${BRAND.border}`, padding: "20px 24px" }}>
            <div style={{ fontSize: 11, fontWeight: 600, color: BRAND.slate, letterSpacing: "1px", textTransform: "uppercase", marginBottom: 4 }}>Trust Score</div>
            <div style={{ fontSize: 12, color: BRAND.textLight, marginBottom: 16 }}>Q016 — Trust SACAP to provide good education (0-10 scale)</div>
            
            <div style={{ display: "flex", alignItems: "center", gap: 24 }}>
              <ScoreGauge score={d.trust.score} size={120} label="NET" />
              <div style={{ flex: 1 }}>
                <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 8 }}>
                  <span style={{ fontSize: 12, color: "#059669", fontWeight: 600 }}>Fully trust {d.trust.fully}%</span>
                  <span style={{ fontSize: 12, color: "#b45309", fontWeight: 600 }}>Some trust {d.trust.some}%</span>
                  <span style={{ fontSize: 12, color: BRAND.coral, fontWeight: 600 }}>Do not trust {d.trust.doNot}%</span>
                </div>
                <StackedBar positive={d.trust.fully} neutral={d.trust.some} negative={d.trust.doNot} height={20} />
                <div style={{ marginTop: 12, padding: "8px 12px", background: "rgba(5,150,105,0.04)", borderRadius: 4, borderLeft: `3px solid ${BRAND.sigUp}` }}>
                  <div style={{ fontSize: 11, color: BRAND.text, lineHeight: 1.4 }}>
                    <strong style={{ color: "#059669" }}>↑ Sig.</strong> Online, Jhb & Pretoria trust significantly higher than Cape Town
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Satisfaction ratings */}
        <div style={{ background: BRAND.white, borderRadius: 8, border: `1px solid ${BRAND.border}`, padding: "20px 24px", marginBottom: 24 }}>
          <div style={{ fontSize: 11, fontWeight: 600, color: BRAND.slate, letterSpacing: "1px", textTransform: "uppercase", marginBottom: 16 }}>Service Ratings — Positive / Neutral / Negative</div>
          <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
            {d.ratings.map((r, i) => (
              <div key={i}>
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", marginBottom: 6 }}>
                  <div>
                    <span style={{ fontSize: 11, fontWeight: 700, color: BRAND.teal, fontFamily: "'DM Mono', monospace", marginRight: 8 }}>{r.q}</span>
                    <span style={{ fontSize: 13, fontWeight: 600, color: BRAND.navy }}>{r.label}</span>
                    {r.note && <span style={{ fontSize: 10, color: BRAND.textLight, marginLeft: 8 }}>({r.note})</span>}
                  </div>
                  <div style={{ display: "flex", gap: 16, fontSize: 12, fontFamily: "'DM Mono', monospace" }}>
                    <span style={{ color: "#059669", fontWeight: 600 }}>{r.positive}%</span>
                    <span style={{ color: "#b45309" }}>{r.neutral}%</span>
                    <span style={{ color: BRAND.coral }}>{r.negative}%</span>
                  </div>
                </div>
                <StackedBar positive={r.positive} neutral={r.neutral} negative={r.negative} height={16} />
                <div style={{ fontSize: 10, color: BRAND.textLight, marginTop: 2, textAlign: "right" }}>n={r.base}</div>
              </div>
            ))}
          </div>
        </div>

        {/* NET Score heatmap grid */}
        <div style={{ background: BRAND.white, borderRadius: 8, border: `1px solid ${BRAND.border}`, padding: "20px 24px", marginBottom: 24 }}>
          <div style={{ fontSize: 11, fontWeight: 600, color: BRAND.slate, letterSpacing: "1px", textTransform: "uppercase", marginBottom: 4 }}>NET Score Heatmap</div>
          <div style={{ fontSize: 12, color: BRAND.textLight, marginBottom: 16 }}>Positive minus negative — higher is better · Green = strong · Amber = watch</div>
          
          <div style={{ overflowX: "auto" }}>
            <table style={{ width: "100%", borderCollapse: "collapse", minWidth: 800 }}>
              <thead>
                <tr style={{ borderBottom: `2px solid ${BRAND.navy}` }}>
                  <th style={{ padding: "8px 12px", textAlign: "left", fontSize: 11, fontWeight: 600, color: BRAND.navy, minWidth: 140 }}>Metric</th>
                  <th style={{ padding: "8px", textAlign: "center", fontSize: 10, fontWeight: 700, color: BRAND.gold, background: "rgba(26,39,68,0.04)", letterSpacing: "0.5px" }}>TOTAL</th>
                  <th colSpan={5} style={{ padding: "4px 8px", textAlign: "center", fontSize: 9, fontWeight: 600, color: BRAND.teal, letterSpacing: "1px", borderLeft: `2px solid ${BRAND.border}` }}>CAMPUS</th>
                  <th colSpan={4} style={{ padding: "4px 8px", textAlign: "center", fontSize: 9, fontWeight: 600, color: BRAND.teal, letterSpacing: "1px", borderLeft: `2px solid ${BRAND.border}` }}>YEAR OF STUDY</th>
                  <th colSpan={4} style={{ padding: "4px 8px", textAlign: "center", fontSize: 9, fontWeight: 600, color: BRAND.teal, letterSpacing: "1px", borderLeft: `2px solid ${BRAND.border}` }}>AGE</th>
                </tr>
                <tr style={{ borderBottom: `1px solid ${BRAND.border}` }}>
                  <th />
                  <th style={{ padding: "4px 8px", fontSize: 9, color: BRAND.slate, background: "rgba(26,39,68,0.04)" }} />
                  {campusCols.map(c => <th key={c} style={{ padding: "4px 6px", fontSize: 9, color: BRAND.slate, textAlign: "center", borderLeft: c === "Online" ? `2px solid ${BRAND.border}` : "none" }}>{c}</th>)}
                  {yearCols.map(c => <th key={c} style={{ padding: "4px 6px", fontSize: 9, color: BRAND.slate, textAlign: "center", borderLeft: c === "1st" ? `2px solid ${BRAND.border}` : "none" }}>{c}</th>)}
                  {ageCols.map(c => <th key={c} style={{ padding: "4px 6px", fontSize: 9, color: BRAND.slate, textAlign: "center", borderLeft: c === "18-20" ? `2px solid ${BRAND.border}` : "none" }}>{c}</th>)}
                </tr>
              </thead>
              <tbody>
                {d.netScoreGrid.map((row, ri) => (
                  <tr
                    key={ri}
                    onMouseEnter={() => setHoveredRow(ri)}
                    onMouseLeave={() => setHoveredRow(null)}
                    style={{ background: hoveredRow === ri ? "rgba(13,138,138,0.03)" : "transparent", transition: "background 0.1s" }}
                  >
                    <td style={{ padding: "8px 12px", fontSize: 12, fontWeight: 600, color: BRAND.navy, borderBottom: `1px solid ${BRAND.border}` }}>
                      <span style={{ fontSize: 10, color: BRAND.teal, fontFamily: "'DM Mono', monospace", marginRight: 6 }}>{row.q}</span>
                      {row.label}
                    </td>
                    <HeatCell value={row.total} isTotal={true} />
                    {campusCols.map((c, ci) => <HeatCell key={`c${ci}`} value={row.campus[c]} />)}
                    {yearCols.map((c, ci) => <HeatCell key={`y${ci}`} value={row.year[c]} />)}
                    {ageCols.map((c, ci) => <HeatCell key={`a${ci}`} value={row.age[c]} />)}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

        {/* Key findings */}
        <div style={{ background: BRAND.white, borderRadius: 8, border: `1px solid ${BRAND.border}`, padding: "20px 24px", marginBottom: 24 }}>
          <div style={{ fontSize: 11, fontWeight: 600, color: BRAND.slate, letterSpacing: "1px", textTransform: "uppercase", marginBottom: 14 }}>
            Statistically Significant Findings
          </div>
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
            {d.bannerHighlights.map((h, i) => (
              <div key={i} style={{
                padding: "10px 14px",
                borderRadius: 6,
                background: h.direction === "up" ? "rgba(5,150,105,0.04)" : h.direction === "down" ? "rgba(232,97,77,0.04)" : "rgba(251,191,36,0.04)",
                borderLeft: `3px solid ${h.direction === "up" ? "#059669" : h.direction === "down" ? BRAND.coral : "#f59e0b"}`,
              }}>
                <div style={{ display: "flex", alignItems: "center", gap: 6, marginBottom: 4 }}>
                  <span style={{
                    fontSize: 9,
                    fontWeight: 700,
                    padding: "2px 6px",
                    borderRadius: 3,
                    background: "rgba(26,39,68,0.06)",
                    color: BRAND.navy,
                    letterSpacing: "0.5px",
                  }}>{h.metric}</span>
                  {h.sig && <span style={{ fontSize: 9, color: BRAND.sigUp, fontWeight: 700, fontFamily: "'DM Mono', monospace" }}>SIG.</span>}
                </div>
                <div style={{ fontSize: 12, color: BRAND.text, lineHeight: 1.4 }}>{h.finding}</div>
              </div>
            ))}
          </div>
        </div>

        {/* Footer note */}
        <div style={{ textAlign: "center", padding: "16px", fontSize: 11, color: BRAND.textLight, borderTop: `1px solid ${BRAND.border}` }}>
          <div>↓ Scroll down for detailed crosstabs by question ↓</div>
          <div style={{ marginTop: 4, fontSize: 10 }}>
            Significance testing: Column proportions z-test with Bonferroni correction · p&lt;0.05 · Minimum base n=30 · Generated by Turas
          </div>
        </div>
      </div>
    </div>
  );
}
