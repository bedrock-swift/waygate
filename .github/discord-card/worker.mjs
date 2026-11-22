const widgetURL = "https://discordapp.com/api/guilds/1573694440877330565/widget.json?v=2";
const guildID = "1573694440877330565";
const artURL = "https://raw.githubusercontent.com/bedrock-swift/waygate/4df6bc3cce5c4ebc34bb26c894768a4e9660fd4c/assets/discord.png";

async function onlineCount() {
  try {
    const response = await fetch(widgetURL, {
      headers: { "User-Agent": "DiscordBot (https://github.com/bedrock-swift/waygate, 1.0)", "Accept": "application/json" },
      signal: AbortSignal.timeout(4500),
    });
    if (!response.ok) {
      console.warn("discord widget status", response.status);
      return null;
    }
    const widget = await response.json();
    const count = widget?.presence_count;
    return widget?.id === guildID && Number.isSafeInteger(count) && count >= 0 ? count : null;
  } catch {
    return null;
  }
}

async function artwork() {
  try {
    const response = await fetch(artURL, { signal: AbortSignal.timeout(4500) });
    if (!response.ok || response.headers.get("Content-Type") !== "image/png") return null;
    const bytes = new Uint8Array(await response.arrayBuffer());
    if (bytes.length > 32000) return null;
    return btoa(String.fromCharCode(...bytes));
  } catch {
    return null;
  }
}

function render(count, png) {
  const label = count === null ? "Online unavailable" : count + " online";
  const icon = png ? `<image href="data:image/png;base64,${png}" width="320" height="76" clip-path="url(#icon)"/>` : "";
  return new Response(`<svg xmlns="http://www.w3.org/2000/svg" width="320" height="76" viewBox="0 0 320 76" role="img">
  <title>Bedrock Swift on Discord</title>
  <defs><clipPath id="icon"><circle cx="32.25" cy="38.25" r="20"/></clipPath></defs>
  <rect width="320" height="76" rx="12" fill="#BE4219"/>
  ${icon}
  <text x="63" y="34" fill="#FFF" font-family="Segoe UI, sans-serif" font-size="16" font-weight="600">Bedrock Swift</text>
  <circle cx="66" cy="49" r="3" fill="${count === null ? "#F4BD98" : "#B6EEA0"}"/>
  <text x="74" y="53" fill="#FFE7D9" font-family="Segoe UI, sans-serif" font-size="11">${label}</text>
  <rect x="199" y="21" width="110" height="34" rx="8" fill="#8E2B10"/>
  <text x="211" y="42" fill="#FFF" font-family="Segoe UI, sans-serif" font-size="12" font-weight="600">Join Discord</text>
  <path d="m290 34 4 4-4 4" fill="none" stroke="#FFF" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
</svg>`, {
    headers: {
      "Content-Type": "image/svg+xml; charset=utf-8",
      "Cache-Control": "public, max-age=" + (count === null || png === null ? 15 : 60),
      "X-Content-Type-Options": "nosniff",
    },
  });
}

export default {
  async fetch(request, _env, context) {
    const url = new URL(request.url);
    if (url.pathname !== "/discord.svg") return new Response(null, { status: 404 });
    if (request.method !== "GET" && request.method !== "HEAD") {
      return new Response(null, { status: 405, headers: { Allow: "GET, HEAD" } });
    }

    url.search = "";
    let card = await caches.default.match(url.href);
    if (!card) {
      card = render(...await Promise.all([onlineCount(), artwork()]));
      context.waitUntil(caches.default.put(url.href, card.clone()));
    }
    if (request.method === "HEAD") return new Response(null, { headers: card.headers });
    return card;
  },
};
