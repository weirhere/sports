import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  async redirects() {
    // /following and /conferences were removed in the iOS-parity cleanup;
    // the 4-tab nav's Teams tab is their closest surviving home.
    // /conferences/:id moved to /conference/:id (singular, iOS parity).
    return [
      { source: "/following", destination: "/teams", permanent: false },
      { source: "/conferences", destination: "/teams", permanent: false },
      {
        source: "/conferences/:id",
        destination: "/conference/:id",
        permanent: false,
      },
      { source: "/settings", destination: "/", permanent: false },
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
