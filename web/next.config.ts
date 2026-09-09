import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  async redirects() {
    // /following and /conferences were removed in the iOS-parity cleanup;
    // the 4-tab nav's Teams tab is their closest surviving home.
    // /conferences/:id moved to /conference/:id (singular, iOS parity).
    //
    // The bare-id entity routes predate the league axis. They live here
    // rather than as pages because Next refuses two different slug names at
    // one level (`game/[gameId]` and `game/[league]/[gameId]` collide), and
    // `statside.co/game/{id}` is already in the wild — it is the URL the
    // OpenGraph card shipped on, so it exists in Slack unfurls and pasted
    // threads. Unfurlers follow 3xx and read the destination's og: tags, so
    // an old link keeps its card. Every one of those ids is college
    // football's, because that was the only league the web app had, which
    // makes the mapping exact rather than a guess.
    const legacyEntity = ["game", "team", "conference"].map((entity) => ({
      source: `/${entity}/:id(\\d+)`,
      destination: `/${entity}/cfb/:id`,
      permanent: true,
    }));

    return [
      { source: "/following", destination: "/teams", permanent: false },
      { source: "/conferences", destination: "/teams", permanent: false },
      {
        source: "/conferences/:id",
        destination: "/conference/cfb/:id",
        permanent: false,
      },
      { source: "/settings", destination: "/", permanent: false },
      ...legacyEntity,
    ];
  },
  images: {
    remotePatterns: [
      {
        protocol: "https",
        hostname: "a.espncdn.com",
        pathname: "/i/teamlogos/**",
      },
      {
        protocol: "https",
        hostname: "a.espncdn.com",
        pathname: "/combiner/i/**",
      },
    ],
  },
};

export default nextConfig;
