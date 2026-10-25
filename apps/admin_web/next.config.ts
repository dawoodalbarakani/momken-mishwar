import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  async rewrites() {
    return [];
  },
  allowedDevOrigins: ['127.0.0.1', '*.local-origin.dev'],
};

export default nextConfig;
