"use client";

import { useEffect, useRef } from "react";

const adsenseClientId = process.env.NEXT_PUBLIC_ADSENSE_CLIENT_ID ?? "";

export default function AdSenseSlot({
  slot,
  className = "",
  format = "auto",
  responsive = true
}) {
  const didRequestAd = useRef(false);

  useEffect(() => {
    if (!slot || !adsenseClientId || typeof window === "undefined" || didRequestAd.current) {
      return;
    }

    try {
      didRequestAd.current = true;
      (window.adsbygoogle = window.adsbygoogle || []).push({});
    } catch (error) {
      didRequestAd.current = false;
      console.error("AdSense slot failed to load.", error);
    }
  }, [slot]);

  if (!slot || !adsenseClientId) {
    return null;
  }

  const combinedClassName = ["adsense-shell", className].filter(Boolean).join(" ");

  return (
    <aside aria-label="広告" className={combinedClassName}>
      <span className="adsense-label">スポンサーリンク</span>
      <ins
        className="adsbygoogle"
        data-ad-client={adsenseClientId}
        data-ad-format={format}
        data-ad-slot={slot}
        data-full-width-responsive={responsive ? "true" : "false"}
        style={{ display: "block" }}
      />
    </aside>
  );
}
