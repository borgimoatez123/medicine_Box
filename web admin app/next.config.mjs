/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  experimental: {
    useLightningcss: false,
  },
  async rewrites() {
    const destBase =
      (process.env.NEXT_PUBLIC_API_URL || "").replace(/\/$/, "") ||
      "http://localhost:3000/api";
    return [
      {
        source: "/api/:path*",
        destination: `${destBase}/:path*`,
      },
    ];
  },
};

export default nextConfig;
