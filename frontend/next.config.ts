import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Required for Docker standalone builds
  output: "standalone",

  // Allow images from your backend domain if using Next Image
  images: {
    remotePatterns: [
      {
        protocol: "http",
        hostname: "localhost",
        port: "8080",
      },
      {
        protocol: "http",
        hostname: "comments-service",
        port: "8080",
      },
    ],
  },
};

export default nextConfig;