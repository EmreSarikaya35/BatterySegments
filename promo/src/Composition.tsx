import React from "react";
import { Audio } from "@remotion/media";
import {
  AbsoluteFill,
  Composition,
  Easing,
  Img,
  interpolate,
  staticFile,
  useCurrentFrame,
} from "remotion";

// ---- Timeline (frames @ 30fps). Change these to retime the whole video. ----
const T = {
  zoomIn: [60, 120],
  click: 124,
  press: 295,
  dragEnd: 345,
  leavePopover: [322, 332], // the dragged slice crosses the popover edge
  release: 385,
  zoomOut: [520, 565],
  endCard: 555,
  total: 690,
} as const;

const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;
const ease = Easing.bezier(0.45, 0, 0.2, 1);
const out = Easing.bezier(0.16, 1, 0.3, 1);
const FONT = "-apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Helvetica Neue', sans-serif";
const GAIN = "#34c759";
const QUIT_RED = "#ee4b4b";
const dim = "rgba(255,255,255,0.6)";

// Screen is 1272x795; it sits at (324,110) on the 1920x1080 stage.
const SCREEN = { x: 324, y: 110, w: 1272, h: 795 };
const POPOVER = { x: 820, y: 36, w: 360, h: 323 };
const ICON_X = 1000; // menu bar battery icon centre

const SLICES = [
  { id: "chrome", w: 55, color: "#5b8de0", label: "−70m", after: "" },
  { id: "figma", w: 40, color: "#a56be1", label: "−48m", after: "−90m" },
  { id: "xcode", w: 35, color: "#4c9bdf", label: "−40m", after: "−74m" },
  { id: "slack", w: 14, color: "#cc3a6c", label: "", after: "" },
  { id: "music", w: 12, color: "#e4506b", label: "", after: "" },
];

// Figma and Slack are not installed here, so their logos sit on a macOS-style tile.
const TILES: Record<string, string> = { figma: "#1e1e1e", slack: "#ffffff" };

const AppIcon: React.FC<{ id: string; size: number }> = ({ id, size }) =>
  TILES[id] ? (
    <div
      style={{
        width: size,
        height: size,
        flexShrink: 0,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
      }}
    >
      <div
        style={{
          width: "82%",
          height: "82%",
          borderRadius: "22%",
          background: TILES[id],
          boxShadow: "0 1px 2px rgba(0,0,0,0.3)",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
        }}
      >
        <Img src={staticFile(`${id}.svg`)} style={{ width: "58%", height: "58%", objectFit: "contain" }} />
      </div>
    </div>
  ) : (
    <Img src={staticFile(`${id}.png`)} style={{ width: size, height: size, flexShrink: 0, display: "block" }} />
  );

const fmt = (m: number) => `${Math.floor(m / 60)}:${String(m % 60).padStart(2, "0")}`;

const useCursor = () => {
  const f = useCurrentFrame();
  const frames = [0, 85, 120, 150, 175, 255, 290, T.press + 5, T.dragEnd, 400, 430];
  const x = interpolate(f, frames, [600, 620, ICON_X, ICON_X, 1215, 1215, 1020, 1020, 700, 700, 770], { ...clamp, easing: ease });
  const y = interpolate(f, frames, [450, 430, 15, 15, 210, 210, 150, 150, 300, 300, 400], { ...clamp, easing: ease });
  return { x, y };
};

// ---------- The battery bar (same geometry as Sources/Views/Theme.swift) ----------
const BatteryBar: React.FC<{
  minutes: number;
  grow: number; // 0..1 slices sliding in
  chrome: number; // 0..1 width of the Chrome slice
  chromeFaint: boolean;
}> = ({ minutes, grow, chrome, chromeFaint }) => (
  <div
    style={{
      position: "relative",
      width: 312,
      height: 96,
      boxSizing: "border-box",
      borderRadius: 28,
      border: "1.5px solid rgba(255,255,255,0.35)",
      background: "rgba(255,255,255,0.06)",
    }}
  >
    <div
      style={{
        position: "absolute",
        left: 4.5,
        top: 4.5,
        width: 300,
        height: 84,
        borderRadius: 22,
        background: "#fff",
        overflow: "hidden",
        display: "flex",
      }}
    >
      <div
        style={{
          flex: 1,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          fontSize: 21,
          fontWeight: 700,
          color: "#121212",
          fontVariantNumeric: "tabular-nums",
        }}
      >
        {fmt(minutes)}
      </div>
      {SLICES.map((s) => {
        const w = s.w * grow * (s.id === "chrome" ? chrome : 1);
        const faint = s.id === "chrome" && chromeFaint;
        const icon = Math.min(28, s.w * 0.65);
        return (
          <div
            key={s.id}
            style={{
              width: w,
              flexShrink: 0,
              overflow: "hidden",
              background: s.color,
              opacity: faint ? 0.3 : 1,
              boxShadow: "inset 1px 0 0 rgba(18,23,64,0.6)",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
            }}
          >
            {faint ? null : <AppIcon id={s.id} size={icon} />}
          </div>
        );
      })}
    </div>
    <div
      style={{
        position: "absolute",
        left: 312,
        top: 29.5,
        width: 8,
        height: 34,
        borderRadius: "0 4px 4px 0",
        background: "rgba(255,255,255,0.35)",
      }}
    />
  </div>
);

const Toggle: React.FC<{ on: boolean }> = ({ on }) => (
  <div style={{ width: 36, height: 16, borderRadius: 8, background: "rgba(255,255,255,0.16)", position: "relative" }}>
    <div style={{ position: "absolute", top: 2, left: on ? 13 : 2, width: 21, height: 12, borderRadius: 6, background: "#fff" }} />
  </div>
);

const Row: React.FC<{ top: number; left: React.ReactNode; right?: React.ReactNode; style?: React.CSSProperties }> = ({
  top,
  left,
  right,
  style,
}) => (
  <div
    style={{
      position: "absolute",
      top,
      left: 14,
      right: 14,
      height: 20,
      display: "flex",
      alignItems: "center",
      justifyContent: "space-between",
      fontSize: 13,
      ...style,
    }}
  >
    <div>{left}</div>
    <div>{right}</div>
  </div>
);

const Popover: React.FC = () => {
  const f = useCurrentFrame();
  const open = T.click + 2;
  const l1 = T.leavePopover[1];
  const preview = interpolate(f, [l1 - 4, l1 + 14], [0, 1], { ...clamp, easing: out });
  const minutes = Math.round(220 + 70 * preview);
  const swapped = preview > 0.5;
  return (
    <div
      style={{
        position: "absolute",
        left: POPOVER.x,
        top: POPOVER.y,
        width: POPOVER.w,
        height: POPOVER.h,
        borderRadius: 18,
        background: "rgba(30,38,100,0.94)",
        border: "1px solid rgba(255,255,255,0.14)",
        boxShadow: "0 24px 60px rgba(0,0,0,0.45), 0 2px 8px rgba(0,0,0,0.3)",
        boxSizing: "border-box",
        color: "#fff",
        transformOrigin: "50% 0",
        opacity: interpolate(f, [open, open + 6], [0, 1], clamp),
        scale: interpolate(f, [open, open + 12], [0.9, 1], { ...clamp, easing: out }),
      }}
    >
      <Row top={12} left={<b>Battery</b>} right={<span style={{ color: dim }}>64 %</span>} />
      <Row top={34} left={<span style={{ color: dim }}>Power Source: Battery</span>} style={{ fontSize: 12 }} />
      <div style={{ position: "absolute", left: 23, top: 66 }}>
        <BatteryBar
          minutes={minutes}
          grow={interpolate(f, [open + 6, open + 34], [0, 1], { ...clamp, easing: out })}
          chrome={1 - preview}
          chromeFaint={f >= T.press}
        />
      </div>
      <div style={{ position: "absolute", left: 29, top: 166, width: 300, height: 12, display: "flex", justifyContent: "flex-end" }}>
        {SLICES.map((s) => (
          <div
            key={s.id}
            style={{
              width: s.w * (s.id === "chrome" ? 1 - preview : 1),
              overflow: "hidden",
              textAlign: "center",
              fontSize: 11,
              color: dim,
              whiteSpace: "nowrap",
              opacity: interpolate(f, [open + 26, open + 38], [0, 1], clamp),
            }}
          >
            {swapped ? s.after : s.label}
          </div>
        ))}
      </div>
      <Row
        top={188}
        left={<span style={{ color: dim }}>Time left</span>}
        right={
          <span style={{ fontVariantNumeric: "tabular-nums" }}>
            {fmt(minutes)}
            <b style={{ color: GAIN, marginLeft: 6, opacity: preview }}>{preview > 0 ? "+1:10" : ""}</b>
          </span>
        }
      />
      <div style={{ position: "absolute", left: 14, right: 14, top: 214, height: 1, background: "rgba(255,255,255,0.16)" }} />
      <Row top={220} left={<b style={{ color: dim }}>Settings</b>} style={{ fontSize: 11 }} />
      <Row top={242} left="Low Power Mode" right={<Toggle on={false} />} />
      <Row top={266} left="Launch at Login" right={<Toggle on />} />
      <Row
        top={290}
        left="Battery Settings…"
        right={
          <svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke={dim} strokeWidth="1.4" strokeLinecap="round">
            <path d="M7 1.5v5M3.6 3.6a4.8 4.8 0 1 0 6.8 0" />
          </svg>
        }
      />
    </div>
  );
};

// The slice while it is being dragged: a tall capsule inside the popover, a tile with a tag outside.
const Ghost: React.FC<{ x: number; y: number }> = ({ x, y }) => {
  const f = useCurrentFrame();
  if (f < T.press || f > T.release + 10) return null;
  const o = interpolate(f, [...T.leavePopover], [0, 1], { ...clamp, easing: ease });
  const w = 55 + 9 * o;
  const h = 112 - 48 * o;
  return (
    <div
      style={{
        position: "absolute",
        left: x - w / 2,
        top: y - h / 2,
        width: w,
        height: h,
        opacity: interpolate(f, [T.press, T.press + 4, T.release, T.release + 8], [0, 1, 1, 0], clamp),
        scale: interpolate(f, [T.press, T.press + 6, T.release, T.release + 8], [0.86, 1, 1, 0.4], { ...clamp, easing: out }),
      }}
    >
      <div
        style={{
          width: w,
          height: h,
          borderRadius: 29 - 13 * o,
          background: SLICES[0].color,
          boxShadow: "0 10px 24px rgba(0,0,0,0.35)",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
        }}
      >
        <AppIcon id="chrome" size={28 + 12 * o} />
      </div>
      <div
        style={{
          position: "absolute",
          top: h + 8,
          left: "50%",
          translate: "-50% 0",
          rotate: "-4deg",
          opacity: o,
          padding: "4px 9px",
          borderRadius: 8,
          background: QUIT_RED,
          color: "#fff",
          fontSize: 12,
          fontWeight: 600,
          whiteSpace: "nowrap",
          boxShadow: "0 4px 10px rgba(0,0,0,0.3)",
        }}
      >
        Quit Chrome
      </div>
    </div>
  );
};

const MenuBar: React.FC = () => {
  const f = useCurrentFrame();
  return (
    <div
      style={{
        position: "absolute",
        inset: "0 0 auto 0",
        height: 30,
        background: "rgba(20,22,48,0.45)",
        color: "#fff",
        fontSize: 13,
        display: "flex",
        alignItems: "center",
        padding: "0 16px",
        gap: 18,
      }}
    >
      <b>Finder</b>
      {["File", "Edit", "View", "Go", "Window", "Help"].map((m) => (
        <span key={m}>{m}</span>
      ))}
      {/* our menu bar icon */}
      <div
        style={{
          position: "absolute",
          left: ICON_X - 19,
          top: 4,
          width: 38,
          height: 22,
          borderRadius: 6,
          background: f >= T.click ? "rgba(255,255,255,0.22)" : "transparent",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
        }}
      >
        <svg width="27" height="13" viewBox="0 0 27 13">
          <rect x="0.5" y="0.5" width="22" height="12" rx="3.5" fill="none" stroke="rgba(255,255,255,0.5)" />
          <rect x="2" y="2" width="12.5" height="9" rx="2" fill="#fff" />
          <rect x="24" y="4" width="2" height="5" rx="1" fill="rgba(255,255,255,0.5)" />
        </svg>
      </div>
      <svg style={{ position: "absolute", left: 1064 }} width="17" height="13" viewBox="0 0 17 13" fill="none" stroke="#fff" strokeWidth="1.8" strokeLinecap="round">
        <path d="M1.5 4.5a10 10 0 0 1 14 0M4 7.3a6.4 6.4 0 0 1 9 0M6.6 10a2.7 2.7 0 0 1 3.8 0" />
      </svg>
      <span style={{ position: "absolute", right: 16 }}>Fri Nov 13&nbsp;&nbsp;9:41 AM</span>
    </div>
  );
};

// A plain app window so the desktop does not look empty.
const FakeWindow: React.FC = () => (
  <div
    style={{
      position: "absolute",
      left: 110,
      top: 120,
      width: 640,
      height: 470,
      borderRadius: 14,
      background: "#f4f4f6",
      boxShadow: "0 30px 70px rgba(0,0,0,0.4)",
      overflow: "hidden",
    }}
  >
    <div style={{ height: 40, background: "#e6e6ea", display: "flex", alignItems: "center", gap: 8, paddingLeft: 14 }}>
      {["#ff5f57", "#febc2e", "#28c840"].map((c) => (
        <div key={c} style={{ width: 12, height: 12, borderRadius: 6, background: c }} />
      ))}
    </div>
    <div style={{ padding: 28, display: "flex", flexDirection: "column", gap: 14 }}>
      {[320, 520, 470, 540, 380, 500, 260].map((w, i) => (
        <div key={i} style={{ width: w, height: i === 0 ? 22 : 12, borderRadius: 6, background: i === 0 ? "#c9cad2" : "#dcdde3" }} />
      ))}
    </div>
  </div>
);

const Dock: React.FC = () => {
  const f = useCurrentFrame();
  return (
    <div
      style={{
        position: "absolute",
        left: "50%",
        bottom: 8,
        translate: "-50% 0",
        padding: 6,
        borderRadius: 20,
        background: "rgba(255,255,255,0.18)",
        border: "1px solid rgba(255,255,255,0.2)",
        display: "flex",
        gap: 6,
      }}
    >
      {SLICES.map((s) => (
        <div key={s.id} style={{ position: "relative", paddingBottom: 5 }}>
          <AppIcon id={s.id} size={48} />
          {s.id === "chrome" && f > T.release ? null : (
            <div style={{ position: "absolute", bottom: 0, left: 22, width: 4, height: 4, borderRadius: 2, background: "rgba(255,255,255,0.8)" }} />
          )}
        </div>
      ))}
    </div>
  );
};

const Cursor: React.FC<{ x: number; y: number }> = ({ x, y }) => {
  const f = useCurrentFrame();
  const down = (f >= T.click && f < T.click + 5) || (f >= T.press && f < T.release);
  return (
    <svg
      style={{ position: "absolute", left: x - 2, top: y - 1, scale: down ? 0.88 : 1, transformOrigin: "0 0", filter: "drop-shadow(0 1px 2px rgba(0,0,0,0.4))" }}
      width="16"
      height="23"
      viewBox="0 0 16 23"
    >
      <path d="M1 1v17l4.4-4 3.1 7.2 2.6-1.1-3-7.1H14z" fill="#000" stroke="#fff" strokeWidth="1.2" strokeLinejoin="round" />
    </svg>
  );
};

// Stylised desk scene behind the Mac. Children use stage coordinates; it overshoots the stage
// on every side so the wide shot never shows an edge.
const Environment: React.FC = () => (
  <div style={{ position: "absolute", left: -700, top: -500, width: 3320, height: 2200, overflow: "hidden", background: "#17131a" }}>
    <div style={{ position: "absolute", left: 700, top: 500 }}>
      {/* wall, lit warm from the left */}
      <div style={{ position: "absolute", left: -700, top: -500, width: 3320, height: 1390, background: "linear-gradient(100deg, #6a564b 0%, #43373a 45%, #211c25 100%)" }} />
      {/* window light through blinds */}
      <div
        style={{
          position: "absolute",
          left: -380,
          top: -120,
          width: 1000,
          height: 900,
          background: "repeating-linear-gradient(180deg, rgba(255,214,170,0.26) 0 52px, transparent 52px 88px)",
          transform: "skewX(-16deg) skewY(-6deg)",
          filter: "blur(16px)",
          maskImage: "radial-gradient(closest-side, #000 40%, transparent)",
        }}
      />
      {/* lamp glow on the wall */}
      <div style={{ position: "absolute", left: 1330, top: 60, width: 1000, height: 1000, background: "radial-gradient(closest-side, rgba(255,186,110,0.4), transparent)" }} />
      {/* desk */}
      <div
        style={{
          position: "absolute",
          left: -700,
          top: 890,
          width: 3320,
          height: 900,
          background:
            "repeating-linear-gradient(1deg, rgba(0,0,0,0.07) 0 2px, transparent 2px 11px), linear-gradient(#8a6244 0%, #5a3e2a 22%, #2a1c14 60%, #120c09 100%)",
          boxShadow: "inset 0 3px 0 rgba(255,220,180,0.25)",
        }}
      />
      {/* out-of-focus props */}
      <div style={{ position: "absolute", left: 0, top: 0, filter: "blur(9px)" }}>
        {[-52, -30, -12, 8, 26, 46].map((deg, i) => (
          <div
            key={deg}
            style={{
              position: "absolute",
              left: 80,
              top: 480 - (i % 2) * 60,
              width: 84,
              height: 300 + (i % 2) * 60,
              borderRadius: "50% 50% 50% 50% / 70% 70% 30% 30%",
              background: i % 2 ? "#2f5239" : "#44754d",
              transformOrigin: "50% 100%",
              rotate: `${deg}deg`,
            }}
          />
        ))}
        <div style={{ position: "absolute", left: 30, top: 760, width: 190, height: 180, borderRadius: "10px 10px 46px 46px", background: "linear-gradient(90deg, #c47a52, #8f4f33)" }} />
        {/* lamp */}
        <div style={{ position: "absolute", left: 1806, top: 500, width: 10, height: 430, background: "#1c1a1c" }} />
        <div style={{ position: "absolute", left: 1741, top: 915, width: 140, height: 26, borderRadius: "50%", background: "#1c1a1c" }} />
        <div style={{ position: "absolute", left: 1716, top: 380, width: 190, height: 150, clipPath: "polygon(22% 0, 78% 0, 100% 100%, 0 100%)", background: "linear-gradient(#ffe2b0, #ffb866)" }} />
        {/* mug */}
        <div style={{ position: "absolute", left: 1640, top: 840, width: 78, height: 96, borderRadius: "6px 6px 16px 16px", background: "linear-gradient(90deg, #e6dfd3, #a59d92)" }} />
      </div>
      {/* screen glow and laptop shadow on the desk */}
      <div style={{ position: "absolute", left: 160, top: 900, width: 1600, height: 300, borderRadius: "50%", background: "radial-gradient(closest-side, rgba(130,130,255,0.28), transparent)" }} />
      <div style={{ position: "absolute", left: 230, top: 1010, width: 1460, height: 120, borderRadius: "50%", background: "rgba(0,0,0,0.7)", filter: "blur(26px)" }} />
    </div>
  </div>
);

// Keyboard half of the laptop, tilted towards the viewer.
const Deck: React.FC = () => (
  <div
    style={{
      position: "absolute",
      left: SCREEN.x - 14,
      top: SCREEN.y + SCREEN.h + 14,
      width: SCREEN.w + 28,
      height: 440,
      transformOrigin: "50% 0",
      transform: "perspective(1500px) rotateX(68deg)",
      borderRadius: "6px 6px 34px 34px",
      background: "linear-gradient(#7f8187, #c6c8cd 10%, #b2b4b9)",
      boxShadow: "inset 0 0 0 2px rgba(255,255,255,0.3), 0 9px 0 #74767b",
    }}
  >
    <div style={{ position: "absolute", left: 130, right: 130, top: 0, height: 14, borderRadius: "0 0 8px 8px", background: "#17171a" }} />
    <div
      style={{
        position: "absolute",
        left: 110,
        right: 110,
        top: 32,
        height: 232,
        borderRadius: 12,
        background: "#101012",
        padding: 8,
        boxSizing: "border-box",
        display: "flex",
        flexDirection: "column",
        gap: 6,
      }}
    >
      {[0, 1, 2, 3, 4, 5].map((r) => (
        <div key={r} style={{ flex: r === 0 ? 0.6 : 1, display: "flex", gap: 6 }}>
          {Array.from({ length: 14 }, (_, k) => (
            <div key={k} style={{ flex: r === 5 && k === 6 ? 5 : 1, display: r === 5 && k > 6 && k < 11 ? "none" : "block", borderRadius: 5, background: "#242428" }} />
          ))}
        </div>
      ))}
    </div>
    <div style={{ position: "absolute", left: "50%", top: 282, width: 440, height: 144, translate: "-50% 0", borderRadius: 12, background: "rgba(255,255,255,0.14)", boxShadow: "inset 0 0 0 1px rgba(0,0,0,0.12)" }} />
  </div>
);

const Mac: React.FC = () => {
  const cursor = useCursor();
  return (
    <>
      <Environment />
      <Deck />
      {/* lid */}
      <div
        style={{
          position: "absolute",
          left: SCREEN.x - 14,
          top: SCREEN.y - 14,
          width: SCREEN.w + 28,
          height: SCREEN.h + 28,
          borderRadius: 26,
          background: "#08080a",
          boxShadow: "0 0 0 2px #5a5b60, 0 0 0 3px #1c1c1f, 0 0 140px rgba(120,120,255,0.28)",
        }}
      >
        <div
          style={{
            position: "absolute",
            left: 14,
            top: 14,
            width: SCREEN.w,
            height: SCREEN.h,
            borderRadius: 12,
            overflow: "hidden",
            fontFamily: FONT,
            background:
              "radial-gradient(900px 600px at 15% 100%, #f08a5d 0%, transparent 60%), radial-gradient(900px 700px at 90% 0%, #6a5acd 0%, transparent 65%), radial-gradient(700px 500px at 60% 70%, #b83b5e 0%, transparent 60%), #1b1f4b",
          }}
        >
          <FakeWindow />
          <Dock />
          <MenuBar />
          <Popover />
          <Ghost {...cursor} />
          <Cursor {...cursor} />
          {/* notch */}
          <div style={{ position: "absolute", left: SCREEN.w / 2 - 80, top: 0, width: 160, height: 26, borderRadius: "0 0 10px 10px", background: "#08080a" }}>
            <div style={{ margin: "9px auto 0", width: 7, height: 7, borderRadius: 4, background: "#1b1d2a", boxShadow: "inset 0 0 2px #3a4a7a" }} />
          </div>
          {/* glass reflection */}
          <div style={{ position: "absolute", inset: 0, background: "linear-gradient(115deg, rgba(255,255,255,0.07) 0%, transparent 35%)" }} />
        </div>
      </div>
    </>
  );
};

const Caption: React.FC<{ from: number; to: number; children: React.ReactNode }> = ({ from, to, children }) => {
  const f = useCurrentFrame();
  return (
    <div
      style={{
        position: "absolute",
        left: 0,
        right: 0,
        bottom: 84,
        textAlign: "center",
        fontSize: 62,
        fontWeight: 650,
        letterSpacing: -1,
        color: "#fff",
        textShadow: "0 2px 24px rgba(0,0,0,0.6)",
        opacity: interpolate(f, [from, from + 10, to - 10, to], [0, 1, 1, 0], clamp),
        translate: interpolate(f, [from, from + 14], ["0px 18px", "0px 0px"], { ...clamp, easing: out }),
      }}
    >
      {children}
    </div>
  );
};

const EndCard: React.FC = () => {
  const f = useCurrentFrame();
  const t = T.endCard;
  return (
    <AbsoluteFill
      style={{
        background: "rgba(9,9,18,0.9)",
        alignItems: "center",
        justifyContent: "center",
        color: "#fff",
        opacity: interpolate(f, [t, t + 22], [0, 1], clamp),
      }}
    >
      <div
        style={{
          scale: 1.7,
          marginBottom: 80,
          translate: interpolate(f, [t + 6, t + 30], ["0px 30px", "0px 0px"], { ...clamp, easing: out }),
        }}
      >
        <BatteryBar minutes={290} grow={1} chrome={0} chromeFaint={false} />
      </div>
      <div
        style={{
          fontSize: 124,
          fontWeight: 700,
          letterSpacing: -3,
          opacity: interpolate(f, [t + 14, t + 30], [0, 1], clamp),
          translate: interpolate(f, [t + 14, t + 36], ["0px 24px", "0px 0px"], { ...clamp, easing: out }),
        }}
      >
        BatterySegments
      </div>
      <div
        style={{
          marginTop: 18,
          fontSize: 46,
          color: "rgba(255,255,255,0.7)",
          opacity: interpolate(f, [t + 26, t + 42], [0, 1], clamp),
        }}
      >
        Free and open source for macOS 13 or later
      </div>
      <div
        style={{
          marginTop: 44,
          fontSize: 34,
          color: "rgba(255,255,255,0.5)",
          opacity: interpolate(f, [t + 36, t + 52], [0, 1], clamp),
        }}
      >
        github.com/EmreSarikaya35/BatterySegments
      </div>
    </AbsoluteFill>
  );
};

export const Promo: React.FC = () => {
  const f = useCurrentFrame();
  // camera: 0 = wide shot of the whole Mac, 1 = close on the popover
  const p = interpolate(f, [...T.zoomIn, ...T.zoomOut], [0, 1, 1, 0], { ...clamp, easing: ease });
  const s = 0.78 + (2 - 0.78) * p;
  const fx = 960 + (SCREEN.x + 880 - 960) * p;
  const fy = 570 + (SCREEN.y + 250 - 570) * p;
  const cy = 455 + 85 * p;
  // a little handheld drift so it does not feel like a locked-off render
  const dx = Math.sin(f / 47) * 4 + Math.sin(f / 19) * 1.5;
  const dy = Math.cos(f / 53) * 3;
  return (
    <AbsoluteFill style={{ background: "#120c09", fontFamily: FONT }}>
      <Audio src={staticFile("music.wav")} volume={0.6} />
      <div
        style={{
          position: "absolute",
          width: 1920,
          height: 1080,
          transformOrigin: "0 0",
          translate: `${960 - fx * s + dx}px ${cy - fy * s + dy}px`,
          scale: s,
          rotate: `${Math.sin(f / 61) * 0.12}deg`,
          opacity: interpolate(f, [0, 20], [0, 1], clamp),
        }}
      >
        <Mac />
      </div>
      {/* scrim so captions stay readable over the screen */}
      <div style={{ position: "absolute", inset: "auto 0 0 0", height: 330, background: "linear-gradient(transparent, rgba(8,7,10,0.92) 70%)" }} />
      {/* vignette */}
      <AbsoluteFill style={{ background: "radial-gradient(closest-side, transparent 60%, rgba(0,0,0,0.45))" }} />
      <Caption from={8} to={72}>Where does your battery time go?</Caption>
      <Caption from={136} to={246}>One bar. Every app&rsquo;s share of your battery.</Caption>
      <Caption from={256} to={380}>Drag an app out to quit it.</Caption>
      <Caption from={392} to={520}>
        <span style={{ color: GAIN }}>+1:10</span> of battery time, back.
      </Caption>
      <EndCard />
    </AbsoluteFill>
  );
};

export const MyComposition = () => (
  <Composition id="Promo" component={Promo} durationInFrames={T.total} fps={30} width={1920} height={1080} />
);
