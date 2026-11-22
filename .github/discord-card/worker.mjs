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
  const label = count === null ? "" : count + " ONLINE";
  const background = png ? `<image href="data:image/png;base64,${png}" width="320" height="76"/>` :
    '<rect width="320" height="76" rx="12" fill="#C94816"/><text x="63" y="32" fill="white" font-family="sans-serif" font-size="18">Bedrock Swift</text>';
  return new Response(`<svg xmlns="http://www.w3.org/2000/svg" width="320" height="76" viewBox="0 0 320 76" role="img">
  <title>Bedrock Swift on Discord</title>
  ${background}
  <text x="63" y="55" fill="#FFE7D9" font-family="Segoe UI, sans-serif" font-size="11">${label}</text>
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
