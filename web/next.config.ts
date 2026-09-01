import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  async redirects() {
    // Interim: these routes were removed in the iOS-parity cleanup.
    // Non-permanent because /following and /conferences get retargeted
    // to /teams when the 4-tab nav lands.
    return [
      { source: "/following", destination: "/", permanent: false },
      { source: "/conferences", destination: "/", permanent: false },
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
